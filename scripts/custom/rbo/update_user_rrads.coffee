_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/update_user_rrads.coffee 0 3000
#example:  coffee scripts/custom/rbo/update_user_rrads.coffee 1 1 5c3d00cd3a386a39277dc2ee


config.resolve (
  logger
  Secure
  User
  Tenant
  api_rbo_rrads
  TENANT_IDS
) ->

  #TENANTID = "5684a2fc68e9aa863e7bf182" #RBO LIVE
  TENANTID = "5bd75eec2ee0370c43bc3ec7" #RBO TEST

  UPDATE_NRADS_DB = false
  UPDATE_RRADS = false
  ONLY_UPDATE_MISSING_PARENTIDS = false

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "5bd7607b02c467db3f70eda2,570419ee2ef94ac9688392b0" #TEST ENV clientId: 'VD2', LIVE clientID: RB1'

  missing_parent = []
  missing_clientId = []
  rrads_updated = []

  console.log "Alert: process.argv: ", process.argv

  startAt = -1
  endAt = 10000000000000000
  startAt = process.argv[2] if process.argv.length >= 3
  endAt = process.argv[3] if process.argv.length >= 4

  problemUsers = {}

  processUser = (user, done) ->
    userCount++
    if true
      #return next null  #Skip processing this user
      return done null unless userCount >= startAt and userCount <= endAt

    console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"
    if skipList.indexOf(user._id.toString()) > -1
      console.log "SKIPPING USER from skip list!"
      return done null

    if ONLY_UPDATE_MISSING_PARENTIDS and user.parentId
      console.log "SKIPPING USER, ONLY_UPDATE_MISSING_PARENTIDS is true and this user already has a parent."
      return done null

    tHasReminders = false
    tReminderStates = user.reminders.states.join(",") if user.reminders?.states
    tHasReminders = true if tReminderStates and tReminderStates.trim() != "Colorado"
    if !tHasReminders and !user.first_name and !user.last_name and !user.name and !user.email
      console.log "SKIPPING USER, INVALID USER encountered, probably app user with no info."
      return done null

    async.waterfall [
      #Now check if this user has a parent.  If it does not, assign it to the default parent account
      (next) ->
        if user.parentId
          return next null, user.parentId
        else
          missing_parent.push user._id.toString()
          console.log "NOTICE: User encountered without assigned PARENT. Assigning to default parent id now."
          console.log "User: ", user._id, user.clientId, user.name
          if user.tenantId.toString() is TENANT_IDS.RollingBones
            defaultParentId = "570419ee2ef94ac9688392b0" #Hard coded to Brian and Lynley Mehmen for now.
          else if user.tenantId.toString() is TENANT_IDS.RollingBonesTest
            defaultParentId = "5bd7607b02c467db3f70eda2" #Hard coded to top admin user
          else
            return next "update_user_rrads() attempted to run on a non RBO tenant which is not allowed."
          userData = {
            _id: user._id
            parentId: defaultParentId
          }
          console.log "Alert: Updating User model, User.upsert userData: ", userData
          return next null, null unless UPDATE_NRADS_DB
          User.upsert userData, {upsert: false, multi: false}, (err, user) ->
            return next err, user.parentId

      #Check if this user is missing a clientId.  If it is, assign a new one and save it
      (parentId, next) ->
        if user.clientId
          return next null, user.parentId, user.clientId
        else
          missing_clientId.push user._id.toString()
          console.log "NOTICE: User encountered without assigned CLIENT ID. Assigning client id now."
          console.log "User: ", user._id, user.clientId, user.name
          Tenant.findById user.tenantId, (err, theTenantObj) ->
            return next err if err
            Tenant.getNextClientId theTenantObj._id, (err, newClientId) =>
              return next err if err
              return next {error: "Error getting new client id for tenant: #{user.tenantId}"} unless newClientId
              clientId = "#{theTenantObj.clientPrefix}#{newClientId}"
              userData = {
                _id: user._id
                clientId: clientId
              }
              console.log "Alert: Updating User model, User.upsert userData: ", userData
              return next null, null unless UPDATE_NRADS_DB
              User.upsert userData, {upsert: false, multi: false}, (err, user) ->
                return next err, user.parentId, user.clientId

      #Now Update RRADS
      (parentId, clientId, next) ->
        return next "Error: missing parent id." unless parentId
        #Required fields
        req = {
          params: {
            _id: user._id
            tenantId: user.tenantId
            parentId: parentId
            clientId: clientId
          }
        }
        #TODO: Add the most recent authcode for the user

        #Optionally set member, rep, outfitter, and vendor
        UPDATE_MEMBER_INFO = true
        UPDATE_REP_INFO = true
        UPDATE_OUTFITTER_INFO = true
        UPDATE_VENDOR_INFO = true
        UPDATE_FORCE_RECALC_REP_CHAIN = false
        if UPDATE_MEMBER_INFO
          req.params.isMember = false
          req.params.isMember = true if user.isMember
          req.params.memberType = user.memberType
          req.params.memberStarted = user.memberStarted
          req.params.memberExpires = user.memberExpires
          req.params.memberStatus = user.memberStatus
        if UPDATE_REP_INFO
          req.params.isRep = false
          req.params.isRep = true if user.isRep
          req.params.repType = user.repType
          req.params.repStarted = user.repStarted
          req.params.rep_next_payment = user.rep_next_payment
          req.params.repExpires = user.repExpires
          req.params.repStatus = user.repStatus
        if UPDATE_OUTFITTER_INFO
          req.params.isOutfitter = false
          req.params.isOutfitter = true if user.isOutfitter
        if UPDATE_VENDOR_INFO
          req.params.isVendor = false
          req.params.isVendor = true if user.isVendor
        if UPDATE_FORCE_RECALC_REP_CHAIN
          req.params.reassign_rep_downline_all = true

        #console.log "Alert: REQ.PARAMS AFTER SETTING ALL FIELDS: ", req.params
        rrads_updated.push user._id.toString()
        return next null, user unless UPDATE_RRADS
        #Updates RRADS with only the user's genelogy, rep, member, and rolls info.  calls Rads.update_user_partial() instead of find_or_create_nrads!() full update.
        api_rbo_rrads.user_update_rrads_partial req, (err, results) ->
          return next err if err
          return next err, results unless user.needs_sync_nrads_rrads is true
          userData = {
            _id: user._id
            needs_sync_nrads_rrads: false
          }
          console.log "Alert: Updating User model, User.upsert userData: ", userData
          return next null, null unless UPDATE_NRADS_DB
          User.upsert userData, {upsert: false, multi: false}, (err, user) ->
            return next err, results

    ], (err, results) ->
      if err or !results
        console.log "Error: Failed to update RRADS.  Error: ", err
        problemUsers[user._id] = {user: user, err: err}
      else if !results
        console.log "Error: Failed to update RRADS.  Error empty update results: ", results
        problemUsers[user._id] = {user: user, err: err}
      else
        console.log "Successfully updated RRADS with NRADS user: ", results
      #return done null, results #Notice: Ignore failed users for now.  Report at the end
      return done err, results



  getUsers = (tenantId, cb) ->
    conditions = {
      tenantId: tenantId
      #clientId: {$exists: false} #tmp condition
      needs_sync_nrads_rrads: true
    }
    console.log "Alert: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results

  async.waterfall [
    # Get users
    (next) ->
      #userId = process.argv[4]
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
      async.mapSeries users, processUser, (err, results) ->
        return next err, results

  ], (err, results) ->
    console.log "Finished"
    console.log "Alert: problemUsers: ", problemUsers
    console.log "Alert: problemUsers: ", Object.keys(problemUsers).length
    console.log "Alert: number users missing parent: ", missing_parent.length
    console.log "Alert: number users missing clientIds: ", missing_clientId.length
    console.log "Alert: number user updates sent to RRADS: ", rrads_updated.length
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
