_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/update_user_memberships.coffee 0 3
#example:  coffee scripts/custom/rbo/update_user_memberships.coffee 0 3


config.resolve (
  logger
  Secure
  User
  Purchase
) ->

  UPDATE_USER = false
  #TENANTID = "5684a2fc68e9aa863e7bf182" #RBO LIVE
  TENANTID = "5bd75eec2ee0370c43bc3ec7" #RBO TEST

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "582f621aaea350ac565ce123"

  console.log "process.argv: ", process.argv

  startAt = -1
  endAt = 10000000000000000
  startAt = process.argv[2] if process.argv.length >= 3
  endAt = process.argv[3] if process.argv.length >= 4


  processUser = (user, done) ->
    userCount++
    if true
      #return next null  #Skip processing this user
      return done null unless userCount >= startAt and userCount <= endAt
    console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"

    if skipList.indexOf(user._id.toString()) > -1
      console.log "SKIPPING USER from skip list!"
      return done null

    async.waterfall [
      #Retrieve user from the DB (if needed)
      (next) ->
        PULL_USER_FROM_DB = false
        if PULL_USER_FROM_DB
          User.byId user._id, {internal: true}, (err, user) ->
            #Note: User overwrites the "user" variable passed into the processUser() method
            return next err, user
        else
          return next null, user

      #Get all of the user's purchases
      (results, next) ->
        Purchase.byUserId user._id, user.tenantId, (err, purchases) ->
          return next err, purchases

      #Check purchases for membership purchases, and compare against current user membership data
      (purchases, next) ->
        latestMembershipPurchase = null
        latestMembershipPurchase_type = null
        user_is_member = false

        if user.memberStatus is "cancelled"
          return next null, false, {}

        #Purcases are already ordered newest to latest
        for purchase in purchases
          huntCatalogCopy = purchase.huntCatalogCopy[0]
          #Handle case if type is correctly set to "membership"
          if huntCatalogCopy.type is "membership" or huntCatalogCopy.type is "renewal_membership"
            if !latestMembershipPurchase
              latestMembershipPurchase = purchase
              if huntCatalogCopy.title.toLowerCase().indexOf("silver") > -1
                latestMembershipPurchase_type = 'silver'
              else if huntCatalogCopy.title.toLowerCase().indexOf("platinum") > -1
                latestMembershipPurchase_type = 'platinum'
              else
                latestMembershipPurchase_type = 'gold'
            #console.log "ALERT: Found 'membership' purchase: #{purchase.createdAt}, - #{huntCatalogCopy.title}, - #{latestMembershipPurchase_type}"
          #Handle case if it was a product purchase
          else if huntCatalogCopy.type is "product" and huntCatalogCopy.title.toLowerCase().indexOf("platinum") > -1
            if !latestMembershipPurchase
              latestMembershipPurchase = purchase
              latestMembershipPurchase_type = 'platinum'
            console.log "ALERT: Found PLATINUM PRODUCT membership purchase: ", purchase.createdAt, huntCatalogCopy.title
          #Handle case if it was a product purchase
          else if huntCatalogCopy.type is "product" and huntCatalogCopy.title.toLowerCase().indexOf("silver") > -1
            if !latestMembershipPurchase
              latestMembershipPurchase = purchase
              latestMembershipPurchase_type = 'silver'
            console.log "ALERT: Found SILVER PRODUCT membership purchase: ", purchase.createdAt, huntCatalogCopy.title

        console.log "Latest Membership Purchase: purchaseDate: #{latestMembershipPurchase.createdAt}, type: #{latestMembershipPurchase.huntCatalogCopy[0].type}, title: #{latestMembershipPurchase.huntCatalogCopy[0].title}" if latestMembershipPurchase
        one_year_ago = moment().subtract(1, 'years')
        if latestMembershipPurchase
          if latestMembershipPurchase?.createdAt > one_year_ago
            user_is_member = true
          else
            console.log "ALERT: Last Membership Purchase was OVER a year ago."

        need_to_update_user = false
        userData = {}
        userData._id = user._id

        if user_is_member or user.isMember
          #Make this user a member, and update the membership type, started, expired date

          if user.isMember and !user_is_member
            memberStarted = null
            memberExpires = null
            memberStarted = moment(user.memberStarted).format("YYYY-MM-DD") if user.memberStarted
            memberExpires = moment(user.memberExpires).format("YYYY-MM-DD") if user.memberExpires
            console.log "ALERT: User granted MANUAL membership encountered! type: #{user.memberType}, started: #{memberStarted}, expires: #{memberExpires}, status: #{user.memberStatus}, next payment amount: #{user.membership_next_payment_amount}"

          if !user.isMember
            need_to_update_user = true
            userData.isMember = true
            console.log "ALERT: User was NOT a member, but HAS a membership purchase. Updating user.isMember to #{userData.isMember}."

          if latestMembershipPurchase_type
            if user.memberType != latestMembershipPurchase_type
              if user.memberType != "platinum"
                need_to_update_user = true
                userData.memberType = latestMembershipPurchase_type
                console.log "ALERT: User current member type DOES NOT MATCH LATEST membership purchase type.  Updating user.memberType to #{userData.memberType}."
          else if user.isMember or userData.isMember is true
            validTypes = ['silver', 'gold', 'platinum']
            if validTypes.indexOf(user.memberType) == -1 and validTypes.indexOf(userData.memberType) == -1
              need_to_update_user = true
              userData.memberType = 'gold'
              console.log "ALERT: User member type INVALID, defaulting to 'gold'.  Updating user.memberType to #{userData.memberType}."

          if !user.memberStarted
            console.log "ALERT: User is a member but MISSING memberStarted date!!!"

          if !user.memberExpires
            console.log "ALERT: User is a member but MISSING memberExpires date!!!"
          else if moment(user.memberExpires) < moment() and user.memberStatus isnt "cancelled"
            console.log "ALERT: User is a member but is EXPIRED. memberExpires date is before today!!!"


          if user.memberStatus?.indexOf("auto") > -1
            if !user.memberExpires
              need_to_update_user = true
              if latestMembershipPurchase
                plus1Year = new moment(latestMembershipPurchase.createdAt)
              else
                plus1Year = new moment()
              plus1Year = plus1Year.add(1, 'years')
              userData.memberExpires = plus1Year.format("YYYY-MM-DD")
              console.log "ALERT: User is on auto-renew, but missing memberExpires.  Updating user.memberExpires to #{userData.memberExpires}."

            if !user.membership_next_payment_amount
              need_to_update_user = true
              if userData.memberType
                userData.membership_next_payment_amount = 50 if userData.memberType is "silver"
                userData.membership_next_payment_amount = 149 if userData.memberType is "gold"
                userData.membership_next_payment_amount = 500 if userData.memberType is "platinum"
              else if user.memberType
                userData.membership_next_payment_amount = 50 if user.memberType is "silver"
                userData.membership_next_payment_amount = 149 if user.memberType is "gold"
                userData.membership_next_payment_amount = 500 if user.memberType is "platinum"
              console.log "ALERT: User is on auto-renew, but missing next payment amount.  Updating user.membership_next_payment_amount to #{userData.membership_next_payment_amount}."


        return next null, need_to_update_user, userData

      #Update user with userData
      (need_to_update_user, userData, next) ->
        memberStarted = null
        memberExpires = null
        memberStarted = moment(user.memberStarted).format("YYYY-MM-DD") if user.memberStarted
        memberExpires = moment(user.memberExpires).format("YYYY-MM-DD") if user.memberExpires
        if need_to_update_user
          console.log "User NEEDS to be updated. isMember: #{user.isMember}, type: #{user.memberType}, started: #{memberStarted}, expires: #{memberExpires}, status: #{user.memberStatus}, next payment amount: #{user.membership_next_payment_amount}"
          console.log "!!! About to update user with data: ", userData
          if UPDATE_USER
            User.upsert userData, {upsert: false}, (err, userRsp) ->
              console.log "User.upsert() completed with err: ", err if err
              return next err if err
              console.log "User.upsert() completed successfully with rsp: ", userRsp._id
              return next null, userRsp
          else
            console.log "UPDATE_USER = false, SKIPPING UPDATING THE USER."
            return next null, null
        else
          if user.isMember
            console.log "User IS a MEMBER but does NOT NEED to be updated. isMember: #{user.isMember}, type: #{user.memberType}, started: #{memberStarted}, expires: #{memberExpires}, status: #{user.memberStatus}, next payment amount: #{user.membership_next_payment_amount}"
          else
            console.log "User is NOT a member and does NOT NEED to be update."
          return next null, null

    ], (err, results) ->
      return done err, results


  getUsers = (tenantId, cb) ->
    conditions = {
      tenantId: tenantId
      isMember: true
      #isMember: false
      #isMember: {$exists: false}
    }
    console.log "query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results


  async.waterfall [
    # Get all users by tenant
    (next) ->
      #userId = process.argv[2]
      #userId = "58a6fa6bfe41db1317c4ec25"
      userId = null
      if userId
        User.findById userId, {internal: true}, next
      else
        getUsers(TENANTID, next)

    # For each user, do stuff
    (users, next) ->
      users = [users] unless typeIsArray users
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, processUser, (err) ->
        next err

  ], (err) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
