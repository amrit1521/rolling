_ = require 'underscore'
async = require "async"
config = require '../config'
winston     = require 'winston'
moment    = require 'moment'
request = require 'request'

#example:  coffee scripts/yearly_email.coffee <tenantid> <singleusertest> <skipTo> <RefreshPointsOnly> <skipRefreshToUser>
#example:  coffee scripts/yearly_email.coffee 53a28a303f1e0cc459000127 5279571d47b97d8778000001 -1 true -1
#example:  coffee scripts/yearly_email.coffee 53a28a303f1e0cc459000127 false -1 true 9  2>&1 | tee /home/ubuntu/tmp/gmt_batchOuput.log
#example:  coffee scripts/yearly_email.coffee 53a28a303f1e0cc459000127 56d79f2988dd0cd7091c9805 -1 false -1



exports.runScript = ->
  config.resolve (
    logger
    Secure
    User
    Tenant
    UserState
    State
    Point
    points
    APITOKEN_GMT

  ) ->

    PointsCtrl = points
    #tenantId = "54a8389952bf6b5852000007" #dev
    #tenantId = "53a28a303f1e0cc459000127" #GMT
    #tenantId = "5684a2fc68e9aa863e7bf182" #RB
    #tenantId = "52c5fa9d1a80b40fd43f2fdd" #HF
    #tenantId = "5734f80007200edf236054e6" #ZGF

    tenantId = process.argv[2]
    runSingleUserId = process.argv[3]
    upToUser = process.argv[4]
    RefreshPointsOnly = process.argv[5]
    skipRefreshToUser = process.argv[6]
    runSingleUserId = null if runSingleUserId is 'false'
    if RefreshPointsOnly is 'true'
      RefreshPointsOnly = true
    else
      RefreshPointsOnly = false

    #RefreshPointsOnly = false
    #runSingleUserId = null
    #runSingleUserId = "5279571d47b97d8778000001"
    #upToUser = -1

    APITOKEN = APITOKEN_GMT
    #APIDOMAIN = "https://www.gotmytag.com:5001/api/v1/";
    APIDOMAIN = "https://test.gotmytag.com/api/v1/";
    APIURL = APIDOMAIN + "refreshPoints"


    userTotal = 0
    userCount = 0
    typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

    users_email_cid_keys = {}

    users_all = []
    users_have_email = []
    users_no_names = []
    users_empty = []
    users_badData = []
    users_dup = []

    dump = (users) ->
      if typeIsArray users
        for user in users
          console.log ""
          console.log "****************************************"
          console.log user
          console.log ""
          console.log ""
      else
        for key, value of users
          console.log ""
          console.log "****************************************"
          console.log "#{key}: ", value
          console.log ""
          console.log ""

    dumpDupsOnly = (users_email_cid_keys) ->
      for key, value of users_email_cid_keys
        if value.length > 1
          console.log ""
          console.log "****************************************"
          console.log "#{key}: ", value
          console.log ""
          console.log ""

    getUser = (userId, users) ->
      theUser = null
      for user in users
        theUser = user if user._id is userId
      return theUser

    testBadData = (user) ->
      badFields = []
      for key in Object.keys(user)
        #console.log "#{key}: #{user[key]}, #{typeof user[key]}", typeof user[key] is "string" and user[key].toLowerCase().indexOf("select") > -1
        if typeof user[key] is "string" and user[key].toLowerCase().indexOf("select") > -1
          badFields[key] = user[key]
      return badFields

    processUser = (user, done) ->
      userCount++
      console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, userId: #{user._id}"
      #return next null  #Skip processing this user
      if upToUser > -1
        return done null, user unless userCount < upToUser

      async.parallel [
        #Test if user has email
        (done) ->
          err = null
          hasEmail = false
          hasEmail = true if user.email?.length
          return done err, hasEmail

        #Test is empty (doesn't have email, inapp device, or phone)
        (done) ->
          err = null
          isEmpty = false
          isEmpty = true unless user.email or user.phone_cell or user.phone_day or user.phone_home
          if isEmpty and typeof user.devices is "object"
            isEmpty = false if JSON.stringify(user.devices) != "[]"

          users_no_names.push user if !user.last_name and !isEmpty
          return done err, isEmpty

        # Test if contains "select" as bad data
        (done) ->
          err = null
          badFields = testBadData(user)
          hasBadData = false
          hasBadData = true if Object.keys(badFields).length > 0
          #console.log "BadFields[]:", badFields if hasBadData
          return done err, hasBadData

        # Test if dup user by email/cid
        (done) ->
          return done null, false if RefreshPointsOnly
          UserState.byUser user._id, (err, userstates) ->
            return done err, false unless userstates

            checkDups = (userstate, done) ->
              isDup = false
              State.byId userstate.stateId, (err, state) ->
                return done err if err
                console.log "Can't find state for stateId: #{userstate.stateId}" unless state
                return done err, isDup unless state
                key = "#{user.email}|#{state.name}|#{userstate.cid}"
                if users_email_cid_keys[key]
                  users_email_cid_keys[key].push(user._id)
                  isDup = true
                else
                  users_email_cid_keys[key] = [user._id]
                return done err, isDup

            async.mapSeries userstates, checkDups, (err, isDups) ->
              userHasDup = false
              for isDup in isDups
                userHasDup = true if isDup
              return done err, userHasDup

      ], (err, results) ->
        console.log "Error: ", err if err
        return done err if err
        users_have_email.push user if results[0]
        users_empty.push user if results[1]
        users_badData.push user if results[2]
        users_dup.push user if results[3]

        return done err, user


    async.waterfall [
      # Get Tenant
      (next) ->
        Tenant.findById tenantId, next

      # Get users
      (tenant, next) ->
        if runSingleUserId
          User.findById runSingleUserId, {internal: true}, next
        else
          console.log "Getting all users for tenant: #{tenant.name}"
          User.findByTenant tenantId, {internal: true}, (err, users) ->
            next err, users

      # For each user...
      (users, next) ->
        users = [users] unless typeIsArray users
        users_all = users
        console.log "Found #{users_all.length} users to process"
        userTotal = users_all.length
        async.mapSeries users_all, processUser, (err, users) ->
          next err, users

    ], (err, results) ->
      console.log "Finished"

      #console.log "users_email_cid_keys:"
      #dumpDupsOnly(users_email_cid_keys)

      #console.log "users_badData", dump(users_badData)
      #console.log "users_dup", dump(users_dup)
      #console.log "users_no_names", dump(users_no_names)

      console.log "Total Users for tenant", users_all.length
      console.log "users_have_email", users_have_email.length
      console.log "users_empty", users_empty.length
      console.log "users_badData", users_badData.length
      console.log "users_no_names", users_no_names.length
      console.log "users_dup", users_dup.length


      refreshUserCount = 0
      if RefreshPointsOnly
        refreshPoints = (user, done) ->
          console.log "Getting points for user", user._id
          refreshUserCount++
          console.log "****************************************Processing #{refreshUserCount} of #{users_have_email.length}, userId: #{user._id}   ****************************************"
          return done null, user unless refreshUserCount >= skipRefreshToUser
          async.waterfall [
            (next) ->
              reqData = _.pick user, ['_id','clientId','memberId','tenantId','email','first_name','middle_name','last_name']
              reqData.userId = user._id
              reqData.token = APITOKEN

              request.post(
                APIURL,
                { json: reqData },
                (err, rsp, body) ->
                  return next err if err
                  console.log "return from https request: rsp.statusCode, body:", rsp.statusCode, body
                  err = body.error if body?.error
                  return next err, body
              )
          ], (err, results) ->
            console.log "#{user._id} POINTS NOT REFRESHED BECAUSE OF ERROR: ", err if err
            return done null, user #keep letting other users go

        console.log "Refreshing points for all tenant user's with email addresses...total: ", users_have_email.length
        async.mapSeries users_have_email, refreshPoints, (err, users) ->
          console.log "Finished refreshing points."
          if err
            logger.error "Finished with error:", err
            process.exit(1)
          else
            process.exit(0)

      else
        #NOW PROCESS ALL THE USERS WITH AN EMAIL AND FLAG THEM TO RECIEVE THE YEARLY EMAIL, including logic for duplicate users
        console.log "Duplicate User Report"
        #HANDLE DUP USERS
        dupUsersList = {}
        dupUsersTouchedList = []
        dupUsersToUserList = []
        for user in users_have_email
          continue if dupUsersTouchedList.indexOf(user._id) > -1
          myDupUsers = []
          #Does the user have duplicate points?
          for key, value of users_email_cid_keys
            if key.indexOf(user.email) > -1 and value.length > 1
              #we have a duplicate, get the other users too
              myDupUsers.push({_id: user._id, email: user.email}) unless getUser(user._id, myDupUsers)
              for userId in value
                tUser = getUser(userId, users_all)
                myDupUsers.push({_id: tUser._id, email: tUser.email}) unless getUser(tUser._id, myDupUsers)
          if myDupUsers.length > 0
            #console.log "myDupUsers", myDupUsers
            dupUsersList[user.email] = myDupUsers
            for tUser in myDupUsers
              dupUsersTouchedList.push tUser._id

        #console.log "dupUsersList", dupUsersList

        processDupUser = (dupUserArray, done) ->
          #console.log "dupUserArray", dupUserArray
          console.log ""
          console.log "email: ", dupUserArray[0].email
          getCidsAndStates = (user, done) ->
            console.log "user._id", user._id
            UserState.byUser user._id, (err, userstates) ->
              return done err if err
              user.userstates = userstates
              Point.byUser user._id, (err, points) ->
                return done err if err
                user.points = points
                return done err, user
          async.mapSeries dupUserArray, getCidsAndStates, (err, users) ->
            dupUserToUse = null
            hasMostCIDs = users[0]
            hasMostPoints = users[0]
            for user in users
              console.log "USER: userId, points, cids", user._id, user.points?.length, user.userstates?.length
              hasMostCIDs = user if user.userstates?.length > hasMostCIDs.userstates?.length
              hasMostPoints = user if user.points?.length > hasMostPoints.points?.length
            if hasMostCIDs._id == hasMostPoints._id
              dupUserToUse = hasMostPoints
            else
              #console.log "UserId with most POINTS:", hasMostPoints._id
              #console.log "UserId with most CIDS:", hasMostCIDs._id
              if hasMostCIDs.userstates?.length == hasMostPoints.userstates?.length and hasMostCIDs.points?.length >= hasMostPoints.points?.length
                hasMostPoints = hasMostCIDs
              if hasMostCIDs.userstates?.length == hasMostPoints.userstates?.length and hasMostCIDs.points?.length < hasMostPoints.points?.length
                hasMostCIDs = hasMostPoints
              if hasMostCIDs.points?.length == hasMostPoints.points?.length and hasMostCIDs.userstates?.length >= hasMostPoints.userstates?.length
                hasMostPoints = hasMostCIDs
              if hasMostCIDs.points?.length == hasMostPoints.points?.length and hasMostCIDs.points?.length < hasMostPoints.points?.length
                hasMostCIDs = hasMostPoints
              #Now check again
              if hasMostCIDs._id == hasMostPoints._id
                dupUserToUse = hasMostPoints
              else
                console.log "WINNERS ARE DIFFERENT points vs cids, picking the higher based on points"
                #console.log "UserId with most POINTS:", hasMostPoints._id
                #console.log "UserId with most CIDS:", hasMostCIDs._id
                if hasMostPoints.points?.length > hasMostCIDs.points?.length
                  dupUserToUse = hasMostPoints
                else
                  dupUserToUse = hasMostCIDs

            console.log "dupUserToUse", dupUserToUse._id
            #console.log ""
            #console.log ""
            dupUsersToUserList.push dupUserToUse

            return done err, dupUserArray

        async.mapSeries dupUsersList, processDupUser, (err, users) ->
          if err
            logger.error "Finished with error:", err
            process.exit(1)
          else
            DONTFLAG = false
            console.log ""
            console.log ""
            console.log "NOW FLAGGING USERS WITH NEEDS YEARLY EMAIL true"
            async.waterfall [
              (next) ->
                console.log ""
                console.log "---first flag users that do not have dups---"
                flagUserWithoutDups = (user, done) ->
                  #console.log "skipping dup user", user._id, user.email if dupUsersTouchedList.indexOf(user._id) > -1
                  return done null, user if dupUsersTouchedList.indexOf(user._id) > -1
                  userData = {
                    _id: user._id,
                    needsPointsEmail: true
                  }
                  console.log "User.upsert(userData):", userData, user.email
                  return done null, user if DONTFLAG
                  User.upsert userData, {upsert: false}, (err, user) ->
                    #console.log "Updated User successfully.", userData if user and not err
                    return done err, user
                async.mapSeries users_have_email, flagUserWithoutDups, (err, users) ->
                  return next null, users

              (users, next) ->
                console.log ""
                console.log "---now flag only the desired user for the users with dups---"
                flagUserWithDups = (user, done) ->
                  userData = {
                    _id: user._id,
                    needsPointsEmail: true
                  }
                  console.log "User.upsert(userData):", userData, user.email
                  return done null, user if DONTFLAG
                  User.upsert userData, {upsert: false}, (err, user) ->
                    #console.log "Updated User successfully.", userData if user and not err
                    return done err, user
                async.mapSeries dupUsersToUserList, flagUserWithDups, (err, users) ->
                  return next null, users


            ], (err, results) ->
              console.log "Finished flagging users to receive yearly email"
              process.exit(0)

app = exports.runScript()