_ = require 'underscore'
async = require "async"
config = require '../config'
winston     = require 'winston'
moment    = require 'moment'
PUBNUB = require "pubnub"


#example:  ./node_modules/coffeescript/bin/coffee scripts/batch_points.coffee Colorado 5684a2fc68e9aa863e7bf182 570419ee2ef94ac9688392b0 -1 -1    John Single User Test
#example:  ./node_modules/coffeescript/bin/coffee scripts/batch_points.coffee Utah 53a28a303f1e0cc459000127 false -1 -1
#example:  ./node_modules/coffeescript/bin/coffee scripts/batch_points.coffee Utah 53a28a303f1e0cc459000127 false 2375 -1

#example:  coffee scripts/batch_points.coffee <State> <tenantid> <singleusertest> <skipTo> <skipAfter>

if process.argv.length > 7
  stateName = process.argv[process.argv.length-5]
  tenantId = process.argv[process.argv.length-4]
  testSingleUserId = process.argv[process.argv.length-3]
  SKIP_TO = process.argv[process.argv.length-2]
  SKIP_AFTER = process.argv[process.argv.length-1]
else if  process.argv.length is 7
  stateName = process.argv[2]
  tenantId = process.argv[3]
  testSingleUserId = process.argv[4]
  SKIP_TO = process.argv[5]
  SKIP_AFTER = process.argv[6]
else if process.argv.length != 7
  console.log "batch_points.coffee must be run with 5 args: 'coffee scripts/batch_points.coffee <state> <tenantid> <singleusertest> <skipTo> <skipAfter>'  was run with: #{process.argv}"
  process.exit(1)

if process.argv[2]
else
  console.error "Found an error", err
  process.exit(1)

#tenantId = "5684a2fc68e9aa863e7bf182" #Rolling Bones
#tenantId = "5734f80007200edf236054e6" #ZeroGuideFees
#tenantId = "56f44d39e680961c4b86f6f7" #MuleyCrazy
#tenantId = "52c5fa9d1a80b40fd43f2fdd" #HuntinFool
#tenantId = "53a28a303f1e0cc459000127" #GotMyTag
#tenantId = "54a8389952bf6b5852000007" #DEV ENVIROMENT
console.log "Running drawresults and points for state: '#{stateName}',  tenantId '#{tenantId}', Single User Test = '#{testSingleUserId}', Skip To: '#{SKIP_TO}', Skip After: '#{SKIP_AFTER}'"

config.resolve (
  DrawResult
  logger
  Point
  Secure
  State
  User
  UserState
  HuntinFoolState
  PUBNUB_PUBLISH_KEY
  PUBNUB_SUBSCRIBE_KEY
  ParseTools

  Arizona
  California
  Colorado
  Florida
  Idaho
  Kansas
  Montana
  Nevada
  Oregon
  Pennsylvania
  Utah
  Washington
  Wyoming
  NewMexico
  NorthDakota
) ->

  pubnub = PUBNUB.init {
    subscribe_key: PUBNUB_SUBSCRIBE_KEY
    publish_key: PUBNUB_PUBLISH_KEY
  }


  StateModels = [
    #{ name: "Arizona",      model: Arizona      }
    #{ name: "California",   model: California   }
    #{ name: "Colorado",     model: Colorado     }
    #{ name: "Florida",      model: Florida      }
    #{ name: "Idaho",        model: Idaho        }
    #{ name: "Kansas",        model: Kansas        }
    #{ name: "Montana",      model: Montana      }
    #{ name: "Nevada",       model: Nevada       }
    #{ name: "New Mexico",     model: NewMexico    }
    # different drawresults {name: "Oregon",       model: Oregon       }
    # no drawresults { name: "Pennsylvania", model: Pennsylvania }
    #{ name: "Utah",         model: Utah         }
    #{ name: "Washington",   model: Washington   }
    #{ name: "Wyoming",      model: Wyoming      }
    #{ name: "North Dakota",     model: NorthDakota    }
  ]

  StateModels = []
  StateModels.push({ name: "Arizona", model: Arizona}) if stateName is "ArizonaPortal"
  StateModels.push({ name: stateName, model: Arizona}) if stateName is "Arizona"
  StateModels.push({ name: stateName, model: California}) if stateName is "California"
  StateModels.push({ name: stateName, model: Colorado}) if stateName is "Colorado"
  StateModels.push({ name: stateName, model: Florida}) if stateName is "Florida"
  StateModels.push({ name: stateName, model: Idaho}) if stateName is "Idaho"
  StateModels.push({ name: stateName, model: Kansas}) if stateName is "Kansas"
  StateModels.push({ name: stateName, model: Montana}) if stateName is "Montana"
  StateModels.push({ name: stateName, model: Nevada}) if stateName is "Nevada"
  StateModels.push({ name: "New Mexico", model: NewMexico}) if stateName is "NewMexico"
  StateModels.push({ name: "North Dakota", model: NorthDakota}) if stateName is "NorthDakota"
  StateModels.push({ name: stateName, model: Utah}) if stateName is "Utah"
  StateModels.push({ name: stateName, model: Washington}) if stateName is "Washington"
  StateModels.push({ name: stateName, model: Wyoming}) if stateName is "Wyoming"
  StateModels.push({ name: stateName, model: Oregon}) if stateName is "Oregon"
  #No DrawResults                 StateModels.push({ name: stateName, model: Pennsylvania}) if stateName is "Pennsylvania"

  SAVE_POINTS = true
  SAVE_DRAWRESULTS = true
  SAVE_CID = false
  SAVE_USER = false

  #DRAW RESULT FLAGS
  RUN_ALL_USERS = false
  PRIORITIZE_BY_POINTS = true
  INCLUDE_NO_POINTS_USERS = false
  INCLUDE_NO_POINTS_USERS_WITH_INTEREST = true
  DELAY = 10000

  StateIds = {}
  userCounter = 0
  userTotal = 0

  customGetUsers = (option, cb) ->
    users = []
    if option is "Arizona Portal"
      query = {tenantId: tenantId, $and: [{azUsername: {$exists: true}}, {azUsername: {$ne: null}}, {azPassword: {$exists: true}}, {azPassword: {$ne: null}}]}
      User.find(query).lean().exec (err, users) ->
        cb err, users
    else if option is "NewMexico"
      query = {tenantId: tenantId, $and: [{nmUsername: {$exists: true}}, {nmUsername: {$ne: null}}, {nmPassword: {$exists: true}}, {nmPassword: {$ne: null}}]}
      User.find(query).lean().exec (err, users) ->
        cb err, users
    else if option is "Utah success re-run"
      DrawResult.byStateResults StateIds[stateName], tenantId, moment().year().toString(), "successful", (err, drawresults) ->
        cb err, drawresults
    else if option is "Colorado"
      query = {tenantId: tenantId, $and: [{nmPassword: {$exists: true}}, {nmPassword: {$ne: null}}]}
      User.find(query).lean().exec (err, users) ->
        cb err, users
    else if option is "WA HF run"
      HuntinFoolState.stateApplicants 'wa', tenantId, (err, hfStates) ->
        return cb err if err
        users = []
        getUser = (hfState, done) ->
          User.byClientId hfState.client_id, {internal: true}, (err, user) ->
            #console.log "user:", user
            return done err, user
        async.mapSeries hfStates, getUser, (err, users) ->
          return cb err, users
    else
      return cb "CustomGetUsers option not specified"


  logOn = ->
    logger.add(winston.transports.Console, {
      colorize: true
      timestamp: true
    })

  logOff = ->
    logger.remove(winston.transports.Console)

  getStatePoints = (user) ->
    parts = [user.field1, user.field2]

    decrypted = Secure.desocial parts
    user.ssn = decrypted.social if decrypted.social
    user.dob = decrypted.dob if decrypted.dob

    (state, cb) ->
      user.results[state.name] = {}
      console.log "Starting #{state.name} - #{user.first_name} #{user.last_name}"

      async.waterfall [

        # Find CID
        (next) ->
          UserState.byStateAndUser user._id, StateIds[state.name], (err, result) ->
            console.log "UserState err: #{state.name}", err if err
            return next err if err
            user.cid = result.cid if result?.cid?.length
            next()

        (next) ->
          conditions = {stateId: StateIds[state.name]}
          conditions.cid = user.cid if user?.cid?.length
          conditions.GET_DRAWRESULTS = true
          #RETRIEVE DATA FROM STATE SITE.  Note: user and conditions are passed by reference and will be modified.
          state.model.points user, conditions, (err, results) ->
            return next err if err
            # console.log "State #{state.name} points callback err:", err if err
            # console.log "State #{state.name} points callback results:", results
            # console.log "Point err #{state.name}:", err
            # console.log "Point results #{state.name}:", results unless err
            #console.log "conditions.cid:", conditions.cid
            next err, conditions.cid, results

        # Save CID
        (cid, points, next) ->
          return next null, points unless SAVE_CID
          cid = user.cid if !cid and user.cid
          cid = user.cid if user.cid_is_new
          return next null, points unless cid
          if cid.substr(0,4) == "0000"
            #This is probably a bad cid from an SSN.  Don't save
            console.log "Bad CID encountered #{state.name} #{cid}"
            return next null, points

          user.results[state.name].cid = cid

          userState = {userId: user._id, stateId: StateIds[points.state], cid}

          console.log "Saving CID, UserState.upsert:", userState
          UserState.upsert userState, (err) ->
            console.log "State #{state.name} upsert called:", userState
            next err, points

        # Save draw results
        (points, next) ->
          return next null, points unless SAVE_DRAWRESULTS
          return next null, points unless points.drawResults?.length

          drawResults = points.drawResults

          saveDraw = (result, lnext) ->
            result.tenantId = tenantId
            if result.year == moment().year() || result.year == moment().year().toString()
              console.log "**********************Saving #{moment().year()} draw result, #{result.name}, #{result.status} }"
              drawResult = new DrawResult result
              #console.log "Saving DrawResult, DrawResult.upsert:", drawResult
              drawResult.upsert (err) -> lnext err
            else
              console.log "Hunt found not in current year"
              lnext null

          async.mapSeries drawResults, saveDraw, (err) ->
            next err, points

        # Save points
        (points, next) ->
          return next null, points unless SAVE_POINTS
          return next null, points unless points?.points?.length

          {points} = points

          user.results[state.name].huntsFound = points.length

          for point in points
            _.extend point, {stateId: StateIds[state.name], userId: user._id, tenantId: user.tenantId}

          console.log "**********************Updating Points, num updated: ", points.length if points.length
          Point.saveGroup points, (err) ->
            next err, points


        # Check preserve email, first_name, last_name, name if they existed on user already
        (points, next) ->
          return next null, points unless SAVE_USER
          console.log "# Check preserve email (batch points)"
          return next null, points unless user?._id?.toString?()?.length
          User.findOne(_id: user._id, {_id: 1, email:1, first_name: 1, last_name: 1, name: 1}).lean().exec (err, result) ->
            console.error "Find local user by state points error:", err if err
            if result and result._id
              user.email = result.email if result.email
              user.name = result.name if result.name
              user.first_name = result.first_name if result.first_name
              user.last_name = result.last_name if result.last_name
            next err, points

        # Save user
        (points, next) ->
          return next null, points unless SAVE_USER
          return next null, points unless user?._id?.toString?()?.length

          console.log "user.changed, user.__changed", user.changed, user.__changed
          console.log "user.__changed: ", user.__changed if user.__changed
          console.log "SAVE USER is true, but skipping because the user has not changed" unless (user.__changed or user.changed)
          return next null, points unless user.__changed or user.changed

          console.log "Saving User, User.upsert:", user
          User.upsert user, {upsert: true}, (err, user) ->
            console.log "User upsert error:", err if err
            user = user.toObject() if user?.toObject
            console.log "User upsert user (getStatePoints):", JSON.stringify(user)

            ###
            message = {
              type: 'user-update'
              data: user
              error: err
              userId: user._id
            }

            pubnub.publish {
              channel: user._id.toString()
              message
              callback: (e) ->
                console.log "SUCCESS!", e
                return

              error: (e) ->
                console.log "FAILED! RETRY PUBLISH!", e
                return
            }
            ###
            next err, points


      ], (err) ->
        console.log "Finished #{state.name} - #{user.first_name} #{user.last_name}"
        console.log "Get Points Error: #{state.name} ERROR:", err if err
        cb()

  getUserPoints = (user, cb) ->
    user._id = user.userId if user.userId #incase we got drawresult or point objects passed in, this will then retrieve the right user
    userId =  user._id
    #console.log 'User:', user
    user.counter = userCounter++
    console.log " ----------------- Processing user userId: #{user._id}, first name: #{user.first_name}, last name: #{user.last_name} - #{userCounter} of #{userTotal} -----------------"
    if SKIP_TO > 0
      return cb() if user.counter <= SKIP_TO
    if SKIP_AFTER > 0
      return cb() if user.counter >= SKIP_AFTER
    User.byId user._id, {internal: true}, (err, user) ->
      return cb err if err
      console.log "SKIPPING User not found for id:", userId unless user?._id
      return cb null, user unless user?._id
      user.results = {}

      #HARD CODED TMP FOR WA HF
      ###
      year = user.dob.split("-")[0]
      username = "#{user.last_name.toLowerCase()}#{user.first_name.toLowerCase().substr(0,1)}"
      password = "#{user.last_name.toLowerCase()}#{year}*"
      console.log "waUsername: #{username}, waPassword: #{password}"
      user.waUsername = username
      user.waPassword = Secure.encrypt password
      ###

      async.mapSeries StateModels, getStatePoints(user), (err) ->
        # console.log "User:", _.pick user, 'first_name', 'last_name', 'dob', 'ssn', 'dl_state', 'drivers_license'
        # console.log "Results for #{user.first_name} #{user.last_name}:", _.pick user.results, 'California', 'Oregon', 'Washington'
        console.log "Results for #{user.first_name} #{user.last_name}:", user.results
        if DELAY > 0
          console.log "Pausing #{DELAY/1000} seconds."
          setTimeout ->
            console.log "Pause completed."
            return cb err
          , DELAY
        else
          return cb err


  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  async.waterfall [

    # Get State IDs
    (next) ->
      console.log "Get state ids"
      return next "Error, for now please only run one state at a time" unless StateModels.length == 1
      State.index (err, states) ->
        return next err if err
        for state in states
          StateIds[state.name] = state._id

        next()

    # Get All tenant's users
    (next) ->
      console.log 'get users'

      if testSingleUserId != "false"
        userId = "" #Morlin Id  https://test.gotmytag.com/#!/admin/masquerade/5862942c6982708ccf3be286
        userId = testSingleUserId
        User.findById userId, {internal: true}, next
      else if stateName is "ArizonaPortal"
        stateName = 'Arizona'
        customGetUsers("Arizona Portal", next)
      else if stateName is "NewMexico"
        stateName = 'NewMexico'
        customGetUsers("NewMexico", next)
      else if stateName is "Colorado"
        customGetUsers("Colorado", next)
      #else if stateName is "Utah"
      #  customGetUsers("Utah success re-run", next)
      #else if stateName is "Washington"
      #  customGetUsers("WA HF run", next)
      else
        User.findByTenant tenantId, {internal: true}, next

    # Get all tenant uses that already have points in the state
    (allUsers, next) ->
      allUsers = [allUsers] unless typeIsArray allUsers
      Point.byTenantAndState tenantId, StateIds[stateName], (err, pointsUsers) ->
        next err, allUsers, pointsUsers

    # Get all users that we applied for
    (allUsers, pointsUsers, next) ->
      console.log "DEBUG: stateName: ", stateName
      stateAbr = ParseTools.stateAbbreviation(stateName).toLowerCase()
      #stateAbr = "NM"
      HuntinFoolState.stateApplicants stateAbr, tenantId, (err, applicationUsers) ->
        next err, allUsers, pointsUsers, applicationUsers

    # Get user's drawresults and points
    (allUsers, pointsUsers, applicationUsers, next) ->
      orderedUsers = []

      if RUN_ALL_USERS or testSingleUserId != "false"
        console.log "RUNNING DRAW RESULTS FOR ALL USERS"
        orderedUsers = allUsers
        console.log "found #{orderedUsers.length} users"

      else if PRIORITIZE_BY_POINTS
        console.log "RUNNING DRAW RESULTS PRIORITIZE BY THOSE WITH POINTS FIRST"
        orderedUsers = []
        console.log "found #{allUsers.length} users"
        pUsersUnique = []
        for pUser in pointsUsers
          pUser._id = pUser.userId #setup _id as userId for downstream to get the user
          if !pUsersUnique[pUser._id.toString()]
            orderedUsers.push pUser
            pUsersUnique[pUser._id.toString()] = pUser
        console.log "found #{Object.keys(pUsersUnique).length} users already have points for this state"
        console.log "orderedUsers after adding pointsUsers: #{orderedUsers.length}"

        noPointsUsers = []
        for user in allUsers
          dupUser = false
          for pUser in pointsUsers
            if user._id.toString() is pUser._id.toString()
              dupUser = true
              break
          noPointsUsers.push user unless dupUser
        console.log "found #{noPointsUsers.length} noPointsUsers"

        if INCLUDE_NO_POINTS_USERS
          console.log "NOW INCLUDING USERS THAT DO NOT HAVE POINTS TO THE END OF THE LOOKUP LIST"
          for user in noPointsUsers
            orderedUsers.push user
          console.log "orderedUsers after adding no points users: #{orderedUsers.length}"

        if INCLUDE_NO_POINTS_USERS_WITH_INTEREST
          console.log "NOW INCLUDING USERS THAT DO NOT HAVE POINTS BUT HAVE REMINDERS OR APPLICATIONS TO THE END OF THE LOOKUP LIST"
          total_reminders = 0
          for user in noPointsUsers
            #CHECK IF THEY HAVE STATE REMINDERS
            if user?.reminders?.states?.indexOf(stateName) > -1
              orderedUsers.push user
              total_reminders++
          console.log "total no points users with interest in state reminders: #{total_reminders}"

          total_apps = 0
          console.log "found #{applicationUsers.length} users have requested to do application with us."
          user_index = []
          for tUser in orderedUsers
            user_index[tUser._id.toString()] = tUser
          for app in applicationUsers
            app._id = app.userId
            if !user_index[app._id.toString()]
              orderedUsers.push app
              total_apps++
          console.log "total no points users doing apps with us: #{total_apps}"
          console.log "orderedUsers after adding no points users with interest: #{orderedUsers.length}"


        console.log "found #{orderedUsers.length} users after prioritizing by points"

      # Done filtering, now run for each user
      userTotal = orderedUsers.length
      async.mapSeries orderedUsers, getUserPoints, (err) ->
        next err

  ], (err) ->
    if err
      console.error "Stopping run, encountered error", err
      process.exit(1)
    else
      console.log "Finished"
      process.exit(0)
