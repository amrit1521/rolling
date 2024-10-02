_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/rrads_check_users.coffee 0 3

UPDATE_RRADS = true

config.resolve (
  User
  logger
  api_rbo_rrads
  userReps
) ->

  TENANTID = "5684a2fc68e9aa863e7bf182" #RBO LIVE
  #TENANTID = "5bd75eec2ee0370c43bc3ec7" #RBO TEST

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "5bd7607b02c467db3f70eda2,570419ee2ef94ac9688392b0" #TEST ENV clientId: 'VD2', LIVE clientID: RB1'
  userRepsCtrl = userReps

  console.log "Alert: process.argv: ", process.argv

  startAt = -1
  endAt = 10000000000000000
  startAt = process.argv[2] if process.argv.length >= 3
  endAt = process.argv[3] if process.argv.length >= 4

  mismatched_users = []
  mismatched_users_ids = ""

  processUser = (user, done) ->
    userCount++

    if true
      #return next null  #Skip processing this user
      return done null unless userCount >= startAt and userCount <= endAt

    console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"
    if skipList.indexOf(user._id) > -1
      console.log "SKIPPING USER from skip list!"
      return done null

    async.waterfall [
      (next) ->
        req = {
          params: {
            _id: user._id
            tenantId: user.tenantId
            parentId: user.parentId
            clientId: user.clientId
            user_check_only: true
          }
        }
        return next null, req

      (req, next) ->
        console.log "DEBUG: About to send req to RRADS: ", req
        api_rbo_rrads.user_update_rrads_partial req, (err, results) ->
          if err
            console.log "ERROR getting user from RRADS: ", err
            return next err
          if results?.results?.status is "success" and results?.results?.user
            rrads_user = JSON.parse(results.results.user)
          else
            console.log "ERROR getting user from RRADS: ", results
            err = results
            return next err
          return next err, rrads_user

      (rrads_user, next) ->
        console.log "Alert: User data from RRADS: ", rrads_user
        user.isMember = false unless user.isMember
        user.memberType = "gold" if user.memberType is "member" or user.memberType is "Member"
        user.memberType = "" unless user.memberType
        user.isRep = false unless user.isRep
        user.repType = null unless user.repType
        user.repStatus = null unless user.repStatus
        user.memberStarted = new Date(user.memberStarted) if user.memberStarted
        user.memberStarted_m = moment(user.memberStarted) if user.memberStarted
        user.memberExpires = new Date(user.memberExpires) if user.memberExpires
        user.memberExpires_m = moment(user.memberExpires) if user.memberExpires
        user.memberStatus = null unless user.memberStatus
        user.memberStatus = null if user.memberStatus is 'Affiliate'
        user.repStarted = new Date(user.repStarted) if user.repStarted
        user.repStarted_m = moment(user.repStarted) if user.repStarted
        user.repExpires = new Date(user.repExpires) if user.repExpires
        user.repExpires_m = moment(user.repExpires) if user.repExpires

        rrads_user.repType = null unless rrads_user.repType
        rrads_user.repStatus = null unless rrads_user.repStatus
        rrads_user.repStatus = rrads_user.repStatus.replace(/ /g, '-').toLowerCase() if rrads_user.repStatus
        rrads_user.rep_at = moment(rrads_user.rep_at) if rrads_user.rep_at
        rrads_user.rep_expires_at = moment(rrads_user.rep_expires_at) if rrads_user.rep_expires_at
        rrads_user.memberStatus = null unless rrads_user.memberStatus
        rrads_user.memberStatus = rrads_user.memberStatus.replace(/ /g, '-').toLowerCase() if rrads_user.memberStatus
        rrads_user.member_at = moment(rrads_user.member_at) if rrads_user.member_at
        rrads_user.member_expires_at = moment(rrads_user.member_expires_at) if rrads_user.member_expires_at
        rrads_user.membership_type = "" unless rrads_user.membership_type

        #Go ahead and ignore it if nrads has memberType but they aren't a member.  RRADS will have it in the purchase history.  It's stored differently in RRADS
        if !user.isMember and user.memberType?.length and !rrads_user.membership_type?.length
          user.memberType = ""
        if !user.isMember and user.memberStatus?.length and !rrads_user.memberStatus?.length
          user.memberStatus = null
        #TODO: These cases do need to be handled sometime when RRADS allows the update when isRep is false
        if !user.isRep and user.repStatus?.length and !rrads_user.repStatus?.length
          user.repStatus = null

        mismatched = {}
        #mismatched.name = {nrads: user.name, rrads: rrads_user.name} unless user.name is rrads_user.name
        mismatched.clientId = {nrads: user.clientId, rrads: rrads_user.client_id} unless user.clientId is rrads_user.client_id
        mismatched.parentId = {nrads: user.parentId.toString(), rrads: rrads_user.parent_mongo_id.toString()} unless user.parentId.toString() is rrads_user.parent_mongo_id.toString()
        mismatched.isMember = {nrads: user.isMember, rrads: rrads_user.isMember} unless user.isMember is rrads_user.isMember
        mismatched.memberType = {nrads: user.memberType.toLowerCase(), rrads: rrads_user.membership_type.toLowerCase()} unless user.memberType?.toLowerCase() is rrads_user.membership_type?.toLowerCase()
        if user.memberStarted and rrads_user.member_at
          if user.memberStarted_m.diff(rrads_user.member_at,'days') > 1 || user.memberStarted_m.diff(rrads_user.member_at,'days') < -1
            mismatched.memberStarted = {nrads: user.memberStarted_m.format(), rrads: rrads_user.member_at.format()}
        if user.memberExpires and rrads_user.member_expires_at
          if user.memberExpires_m.diff(rrads_user.member_expires_at,'days') > 1 || user.memberExpires_m.diff(rrads_user.member_expires_at,'days') < -1
            mismatched.memberStarted = {nrads: user.memberExpires_m.format(), rrads: rrads_user.member_expires_at.format()}
        mismatched.memberStatus = {nrads: user.memberStatus, rrads: rrads_user.memberStatus} unless user.memberStatus is rrads_user.memberStatus
        mismatched.isRep = {nrads: user.isRep, rrads: rrads_user.isRep} unless user.isRep is rrads_user.isRep
        mismatched.repType = {nrads: user.repType, rrads: rrads_user.repType} unless user.repType is rrads_user.repType
        mismatched.repStatus = {nrads: user.repStatus, rrads: rrads_user.repStatus} unless user.repStatus is rrads_user.repStatus
        if user.repStarted and rrads_user.rep_at
          if user.repStarted_m.diff(rrads_user.rep_at,'days') > 1 || user.repStarted_m.diff(rrads_user.rep_at,'days') < -1
            mismatched.repStarted = {nrads: user.repStarted_m.format(), rrads: rrads_user.rep_at.format()}
        if user.repExpires and rrads_user.rep_expires_at
          if user.repExpires_m.diff(rrads_user.rep_expires_at,'days') > 1 || user.repExpires_m.diff(rrads_user.rep_expires_at,'days') < -1
            mismatched.repExpires = {nrads: user.repExpires_m.format(), rrads: rrads_user.rep_expires_at.format()}

        return next null, rrads_user, mismatched

      (rrads_user, mismatched, next) ->
        #Now get the current rep
        repField = "rbo_rep0"
        repTypeEnumArray = ["Associate Adventure Advisor","Adventure Advisor","Senior Adventure Advisor","Regional Adventure Advisor","Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
        if user.isRep
          repTypeEnum = repTypeEnumArray.indexOf(user.repType)
          if repTypeEnum is -1
            repTypeMatch = "Associate Adventure Advisor,Adventure Advisor,Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
          else
            count = 0
            for i in [repTypeEnum+1..repTypeEnumArray.length-1]
              if count is 0
                repTypeMatch = repTypeEnumArray[i]
              else
                repTypeMatch = "#{repTypeMatch},#{repTypeEnumArray[i]}"
              count = count+1
        else
          repTypeMatch = "Associate Adventure Advisor,Adventure Advisor,Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
        #console.log "Alert: repType: #{user.repType}, repTypeMatch: #{repTypeMatch} "
        safteyCheck = 0
        async.waterfall [
          (next) ->
            userRepsCtrl.getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) ->
              return next err if err
              return next "Rep not found for user: #{user._id}, #{user.name}" unless rep
              return next err, rep

          (rep, next) ->
            #If the user is a rep,...then move up one parent in the chain
            if rep._id.toString() is user._id.toString()
              User.findById user.parentId, {internal: true}, (err, parent) ->
                return next err if err
                return next "parent not found for userId: #{user._id}" unless parent
                userRepsCtrl.getParentRep parent, repField, repTypeMatch, safteyCheck, (err, rep) ->
                  return next err if err
                  return next "Rep not found for user: #{user._id}, #{user.name}" unless rep
                  return next err, rep
            else
              return next null, rep

        ], (err, rep) ->
          return next err, rrads_user, mismatched, rep


      (rrads_user, mismatched, rep, next) ->
          mismatched.rep = {nrads: rep._id, rrads: rrads_user.rep_mongo_id} unless rep._id.toString() is rrads_user.rep_mongo_id

          if Object.keys(mismatched).length
            mismatched.userInfo = {
              userId: user._id
              clientId: user.clientId
              name: user.name
            }
            console.log "DEBUG: FOUND MISMATCH: ", mismatched
            mismatched_users.push mismatched
            mismatched_users_ids = "#{mismatched_users_ids},#{user._id.toString()}"

          console.log "Number of MisMatched Users: ", mismatched_users.length
          #console.log "mismatched_users_ids: ", mismatched_users_ids
          return next null, mismatched

      (mismatched, next) ->
        return next null, mismatched unless Object.keys(mismatched).length
        req = {
          params: {
            _id: user._id
            tenantId: user.tenantId
            parentId: user.parentId
            clientId: user.clientId
            user_check_only: false
          }
        }
        req.params.isMember = false
        req.params.isMember = true if user.isMember
        req.params.memberType = user.memberType
        req.params.memberStarted = user.memberStarted
        req.params.memberExpires = user.memberExpires
        req.params.memberStatus = user.memberStatus
        req.params.isRep = false
        req.params.isRep = true if user.isRep
        req.params.repType = user.repType
        req.params.repStarted = user.repStarted
        req.params.rep_next_payment = user.rep_next_payment
        req.params.repExpires = user.repExpires
        req.params.repStatus = user.repStatus
        req.params.isOutfitter = false
        req.params.isOutfitter = true if user.isOutfitter
        req.params.isVendor = false
        req.params.isVendor = true if user.isVendor
        req.params.reassign_rep_downline_all = true
        console.log "DEBUG: About to send req to UPDATE RRADS USER: ", req
        return next null, mismatched unless UPDATE_RRADS
        #Updates RRADS with only the user's genelogy, rep, member, and rolls info.  calls Rads.update_user_partial() instead of find_or_create_nrads!() full update.
        api_rbo_rrads.user_update_rrads_partial req, (err, results) ->
          return next err if err
          console.log "Alert: successfully updated user in RRADS results: ", results
          return next err, results

    ], (err, results) ->
      console.log "Error: ", err if err
      return done err

  getUsers = (tenantId, cb) ->
    conditions = {
      tenantId: tenantId
      #isRep: true
      #isMember: true
    }
    console.log "Alert: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results


  async.waterfall [
    # Get users
    (next) ->
      #userId = process.argv[4]
      #userId = "5a970e97ec134bc1ceee2ac0"
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
    console.log "Alert: mismatched_users: ", mismatched_users
    console.log "Alert: mismatched_users: ", mismatched_users.length
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
