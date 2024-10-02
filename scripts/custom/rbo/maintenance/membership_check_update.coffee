_ = require 'underscore'
async = require "async"
config = require '../../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/maintenance/membership_check_update.coffee

# This script checks for all membership or renewal purchases in the last year
# and updates NRADS and RRADS user.isMember, and user.memberExpires to match membership purchases if needed

UPDATE_USER = false
TENANTID = "5684a2fc68e9aa863e7bf182" #RBO LIVE
#TENANTID = "5bd75eec2ee0370c43bc3ec7" #RBO TEST

config.resolve (
  logger
  Secure
  User
  Purchase
  api_rbo_rrads

) ->

  purchaseTotal = 0
  purchaseCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = ""

  processPurchase = (purchase, done) ->
    #return next null  #Skip processing this user
    purchaseCount++
    #return done null unless purchaseCount < 3

    if skipList.indexOf(purchase._id) > -1
      console.log "SKIPPING ITEM!"
      return done null

    purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]
    purchased = moment(purchase.createdAt.getTime())
    pIgnoreDate = purchased.clone().add(-1,'years')
    pExpireDate = purchased.clone().add(1,'years')
    userData = {}

    async.waterfall [
      (next) ->
        User.byId purchase.userId, {internal: true}, (err, user) ->
          userData._id = user._id
          return next err, user

      (user, next) ->
        console.log "****************************************Processing #{purchaseCount} of #{purchaseTotal}, purchase.huntCatalogCopy.type: #{purchase.huntCatalogCopy.type}, purchase._id: #{purchase._id}, User: #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}, User.isMember: #{user.isMember}, User.memberType: #{user.memberType}, User.memberStatus: #{user.memberStatus}"
        console.log "Purchased: #{purchased.format("YYYY-MM-DD")}, pExpires: #{pExpireDate.format("YYYY-MM-DD")}"
        return next null, user

      #Does the actual user membership expire date match the latest membership purchase or renewal?
      (user, next) ->
        userNeedsUpdated = false
        mStarted = moment(user.memberStarted.getTime())
        mExpires = moment(user.memberExpires.getTime())
        expiresDiff = pExpireDate.diff(mExpires, "days") #a.diff(b) is a - b for positive or negative value
        console.log "pExpires: #{pExpireDate.format("YYYY-MM-DD")} - mExpires: #{mExpires.format("YYYY-MM-DD")} = #{expiresDiff}"
        if (user.isMember is false and user.memberStatus != 'cancelled')
          console.log "!!!User is not a member but purchased a valid membership"
          userNeedsUpdated = true
          userData.isMember = true
        if (expiresDiff < 2 or user.memberStatus == 'cancelled')
          console.log "Memberships expire dates look good"
        else
          console.log "!!!Memberships user fields and membership purchase DO NOT MATCH"
          newExpireDate = pExpireDate.format('YYYY-MM-DD')
          userNeedsUpdated = true
          userData.memberExpires = newExpireDate

        return next null, user, userNeedsUpdated

      #Update user
      (user, userNeedsUpdated, next) ->
        userUpdated = false
        if userNeedsUpdated
          console.log "About to update user with data: ", userData
          if UPDATE_USER and user._id
            User.upsert userData, (err, updatedUser) ->
              return next err if err
              console.log("User updated successfully! ", updatedUser) if updatedUser
              userUpdated = true
              return next err, updatedUser, userUpdated
          else
            console.log "Skipping user update.  UPDATE_USER is false"
            return next null, user, userUpdated
        else
          return next null, user, userUpdated

      #Check update RRADS
      (user, userUpdated, next) ->
        if userUpdated
          req = {}
          params = {}
          params.tenantId = TENANTID
          params._id = user._id
          req.params = params
          if UPDATE_USER
            api_rbo_rrads.user_upsert_rads req, (err, results) =>
              console.log "user_upsert_rads ERROR: ", err if err
              console.log "user_upsert_rads results status: ", results.status
              json = JSON.parse(results.results)
              tUser = json.user if json?.user?
              console.log "results user: email: #{tUser.email}, name: #{tUser.name}" if tUser
              return next null, user
          else
            console.log "Skipping API call to update RRADS"
            return next null, user
        else
          return next null, user

    ], (err, results) ->
      return done err, results


  getPurchases = (cb) ->
    oneYearAgo = moment().add(-1,'years')
    c_or = []
    c_or.push "huntCatalogCopy.type": "membership"
    c_or.push "huntCatalogCopy.type": "renewal_membership"
    c_or.push "huntCatalogCopy.type": "renewal_membership_platinum"
    c_or.push "huntCatalogCopy.type": "renewal_membership_silver"
    conditions = {
      $and: [
        {$or: c_or},
        {createdAt: {$gte: oneYearAgo}}
        {tenantId: TENANTID},
      ]
    }
    console.log "query conditions", JSON.stringify(conditions)
    Purchase.find(conditions).lean().exec (err, results) ->
      cb err, results

  async.waterfall [

    # Get purchases
    (next) ->
      purchaseId = process.argv[2]
      if purchaseId
        Purchase.findById purchaseId, next
      else
        getPurchases(next)

    # For each purchase, do stuff
    (purchases, next) ->
      purchases = [purchases] unless typeIsArray purchases
      console.log "found #{purchases.length} purchases"
      purchaseTotal = purchases.length
      async.mapSeries purchases, processPurchase, (err) ->
        next err

  ], (err) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
