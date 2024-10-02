_ = require "underscore"
async = require "async"
crypto = require "crypto"
moment = require "moment"
util = require "util"

module.exports = (email, Hunt, logger, NavTools, Point, State, Token, User, UserHunt, UserState, Zipcode, Secure) ->

  States = {

    active: (req, res) ->
      State.active (err, states) ->
        return res.json err, 500 if err
        res.json states

    adminIndex: (req, res) ->
      State.adminIndex (err, states) ->
        return res.json err, 500 if err
        res.json states

    adminRead: (req, res) ->
      State.byId req.params.id, (err, state) ->
        return res.json err, 500 if err
        res.json state

    byId: (req, res) ->

      State.byId req.param('id'), (err, state) ->
        return res.json err, 500 if err
        res.json state

    byUser: (req, res) ->
      userId = req.param('id')
      async.parallel [
        (done) -> # states
          State.index done
        (done) -> # hunts
          Hunt.index done
        (done) => # homeState
          @getByUserId userId, done
        (done) -> # userStateIds
          UserState.byUser userId, done
        (done) -> # userHunts
          UserHunt.byUser userId, done
        (done) -> # points
          Point.byUser userId, done
      ], (err, results) ->
        return res.json err, 500 if err

        [states, hunts, homeState, userStateIds, userHunts, points] = results

        indexedStates = {}

        for state in states
          indexedStates[state._id.toString()] = state

        # Set home state
        indexedStates[homeState._id.toString()].home = true if homeState?._id and indexedStates[homeState._id.toString()]

        for stateId in userStateIds
          indexedStates[stateId.stateId.toString()].cid = stateId.cid if indexedStates[stateId.stateId.toString()]

        for hunt in hunts
          stateId = hunt.stateId.toString()

          continue unless indexedStates[stateId]

          for userHunt in userHunts
            hunt.isSet = true if stateId is userHunt.stateId.toString()
            break

          removeIndex = []
          for point, i in points
            continue unless point.stateId.toString() is stateId
            continue unless point.name.trim().toLowerCase() is hunt.match.toLowerCase()
            removeIndex.push i
            hunt.point = point
            break

          removeIndex.reverse()
          for index in removeIndex
            points.splice(index, 1)

          indexedStates[stateId].hunts ?= []
          indexedStates[stateId].hunts.push hunt

        if points
          for point in points
            stateId = point.stateId.toString()
            hunt = _.pick point, 'name', 'stateId'
            hunt.point = point

            indexedStates[stateId].hunts ?= []
            indexedStates[stateId].hunts.push hunt

        res.json _.values(indexedStates)

    create: (req, res, next) ->

      State.upsert req.body, (err, state) ->
        return res.json {error: err}, 500 if err
        res.json state.toJSON()

    findUser: (req, res) ->
      console.log "States::findUser request:", req.body
      user = _.pick req.body, '_id', 'captcha', 'cid', 'dl_state', 'dob', 'drivers_license', 'first_name', 'last_name', 'mail_postal', 'state', 'ssn', 'ssnx', 'email', 'parentId', 'needsWelcomeEmail', 'stateUsername', 'statePassword'
      user.captcha = _.pick user.captcha, 'JSESSIONID', 'text' if user.captcha
      userId = user._id if user._id
      user.dob = moment(user.dob, 'MM/DD/YYYY').format('YYYY-MM-DD') if user.dob and ~user.dob.search /\//
      user.ssn = user.ssnx unless user.ssn
      delete user.parentId if user?._id?.toString() == user?.parentId?.toString() #tmp fix until app fix goes out.

      #Handle state username/passwords.  Note: Because findUser may be used to create a new user, we have to handle encrypting and saving state passwords here too not just in profile save.
      switch user.state
        when "Arizona"
          #For when saving the user:
          user.azUsername = req.body.azUsername if req?.body?.azUsername
          if req?.body?.azPassword and req?.body?.needEncryptAZPassword
            user.azPassword = Secure.encrypt req.body.azPassword
          else if req?.body?.azPassword
            user.azPassword = req.body.azPassword
          #For when looking up state points:
          user.stateUsername = user.azUsername if user.azUsername
          user.statePassword = user.azPassword if user.azPassword

        when "Colorado"
          user.coUsername = req.body.coUsername if req?.body?.coUsername
          if req?.body?.coPassword and req?.body?.needEncryptCOPassword
            user.coPassword = Secure.encrypt req.body.coPassword
          else if req?.body?.coPassword
            user.coPassword = req.body.coPassword
          user.stateUsername = user.coUsername if user.coUsername
          user.statePassword = user.coPassword if user.coPassword

        when "Idaho"
          user.idUsername = req.body.idUsername if req?.body?.idUsername
          if req?.body?.idPassword and req?.body?.needEncryptIDPassword
            user.idPassword = Secure.encrypt req.body.idPassword
          else if req?.body?.idPassword
            user.idPassword = req.body.idPassword
          user.stateUsername = user.idUsername if user.idUsername
          user.statePassword = user.idPassword if user.idPassword

        when "Montana"
          user.mtUsername = req.body.mtUsername if req?.body?.mtUsername
          if req?.body?.mtPassword and req?.body?.needEncryptMTPassword
            user.mtPassword = Secure.encrypt req.body.mtPassword
          else if req?.body?.mtPassword
            user.mtPassword = req.body.mtPassword
          user.stateUsername = user.mtUsername if user.mtUsername
          user.statePassword = user.mtPassword if user.mtPassword

        when "Nevada"
          user.nvUsername = req.body.nvUsername if req?.body?.nvUsername
          if req?.body?.nvPassword and req?.body?.needEncryptNVPassword
            user.nvPassword = Secure.encrypt req.body.nvPassword
          else if req?.body?.nvPassword
            user.nvPassword = req.body.nvPassword
          user.stateUsername = user.nvUsername if user.nvUsername
          user.statePassword = user.nvPassword if user.nvPassword

        when "New Mexico"
          user.nmUsername = req.body.nmUsername if req?.body?.nmUsername
          if req?.body?.nmPassword and req?.body?.needEncryptNMPassword
            user.nmPassword = Secure.encrypt req.body.nmPassword
          else if req?.body?.nmPassword
            user.nmPassword = req.body.nmPassword
          user.stateUsername = user.nmUsername if user.nmUsername
          user.statePassword = user.nmPassword if user.nmPassword

        when "South Dakota"
          user.sdUsername = req.body.sdUsername if req?.body?.sdUsername
          if req?.body?.sdPassword and req?.body?.needEncryptSDPassword
            user.sdPassword = Secure.encrypt req.body.sdPassword
          else if req?.body?.sdPassword
            user.sdPassword = req.body.sdPassword
          user.stateUsername = user.sdUsername if user.sdUsername
          user.statePassword = user.sdPassword if user.sdPassword

        when "Washington"
          user.waUsername = req.body.waUsername if req?.body?.waUsername
          if req?.body?.waPassword and req?.body?.needEncryptWAPassword
            user.waPassword = Secure.encrypt req.body.waPassword
          else if req?.body?.waPassword
            user.waPassword = req.body.waPassword
          user.stateUsername = user.waUsername if user.waUsername
          user.statePassword = user.waPassword if user.waPassword


      #findUser: will potentially create a new user.  I'm adding this section to make it explicit.  Really we should only have one call that creates users but to much to keep it backwards compatible.
      async.waterfall [
        (next) ->
          return next() unless req.body.createNewUser
          user.reminders = req.body.reminders
          # Create User Upsert
          logger.info "# Save User Upsert, inserting new user:", JSON.stringify(user)
          User.upsert user, {upsert: true}, (err, user) ->
            logger.error "User upsert error:", err if err
            next err if err
            #user = user.toObject() if user?.toObject
            logger.info "User upsert created user:", JSON.stringify(user)
            userId = user._id if user._id
            next err, user
      ], (err) ->
        if err
          err.code ?= 500
          return res.json err, err.code


        async.waterfall [
          (next) ->
            if user._id is req.user?._id?.toString()

              user = _.extend({}, req.user, user)
              return next {code: "continue"}

            next()

          (next) ->
            if user._id and req.user?.isAdmin
              User.byId user._id, (err, dbUser) ->
                return next err if err
                user = _.extend({}, dbUser, user)

                next {code: "continue"}
            else
              next()

          (next) ->
            #return next {code: "continue"} #For testing
            return next {error: "Permission denied", code: 401} if user._id
            next()

        ], (err) ->

          err = null if err?.code is 'continue'
          if err
            err.code ?= 500
            return res.json err, err.code


          data = {
            cid: req.body.cid
            state: req.body.state
            user
          }

          abbreviation = if data.state?.length and NavTools.stateAbbreviation(data.state) then NavTools.stateAbbreviation(data.state) else false
          console.log "abbreviation:", abbreviation

          return res.json {error: "A valid state is required", code: 400}, 400 unless abbreviation

          State.getModelByAbbreviation abbreviation, (err, model) ->
            return res.json err, 500 if err

            stateId = model.stateId

            data.stateId = stateId
            data.user.cid = data.cid if data.cid
            data.user.mail_state = data.user.state if data.user?.state?.length
            model.points data.user, data, (err, points) ->
              if err and err.code and err.code < 1000
                return res.json err, err.code
              else if err
                errorDate = moment().format('YYYY-MM-DD HH:mm:ss ZZ')
                console.log "Something bad happened at [States::findUser] #{errorDate}:", err
                mailOptions =
                  from: "GotMyTag Errors <support@gotmytag.com>"
                  to: "support@gotmytag.com"
                  subject: "An unexptected States::findUser API error occurred: #{errorDate} - GotMyTag.com"
                  text: util.inspect(err, {depth: 5})

                email.sendMail mailOptions, (err, response) ->
                  return console.log "API error email failed:", err if err
                  console.log "States error email sent:", response

                return res.json {error: "Something unexpected happened.  Please report to support@gotmytag.com"}, 500

              async.waterfall [

                # Save user
                (next) ->
                  # find existing users  note: 7/4/2017, not sure why this code was here before or what relies on it, but re-using it for app first time launch matching
                  userId = null if req.body.matchUser # The request may specify to match on an existing user instead of the passed in user.
                  async.parallel [

                    # Find by userId
                    (done) ->
                      return done() unless userId

                      User.byId userId, {internal: true}, done

                    # Find by best match: user cid, dob, ssn, tenant (use the latest and has clientId if possible)
                    (done) ->
                      return done() if userId?.length
                      console.log "Find users by best match..."
                      async.waterfall [
                        (nextMatch) ->
                          return nextMatch null, null unless data.user.dob and data.user.ssn
                          conditions = _.pick data.user, 'dob', 'ssn'
                          conditions.ssn = conditions.ssn.substr(-4) if conditions.ssn.length > 4
                          conditions.tenantId = req.tenant._id
                          console.log "Find users by dob and ssn match:", conditions
                          User.find(conditions, {_id: 1, first_name:1, last_name: 1, clientId:1}).lean().exec (err, users) ->
                            return nextMatch err, users

                        (users, nextMatch) ->
                          return nextMatch null, users unless data.cid
                          console.log "Find users by state cid:", data.cid, stateId
                          UserState.byCIDStateAll data.cid, stateId, (err, userStates) ->
                            return nextMatch err if err
                            users = [] unless users
                            getUser = (userState, doneUserState) ->
                              User.byId userState.userId, (err, tUser) ->
                                if tUser?.tenantId?.toString() is req.tenant._id.toString()
                                  userData = _.pick tUser, '_id', 'first_name', 'last_name', 'clientId'
                                  return doneUserState err, userData
                                else
                                  return doneUserState err, null

                            async.mapSeries userStates, getUser, (err, results) ->
                              return nextMatch err if err
                              for result in results
                                users.push result if result
                              return nextMatch null, users

                      ], (err, userMatches) ->
                        return done err if err

                        return done null, null unless userMatches?.length
                        bestMatch = userMatches[0]
                        #Best match on user with a client Id first
                        for userMatch in userMatches
                          bestMatch = userMatch if userMatch.clientId
                        #Now get the newest user (with clientId first,...if none then the newest without a clientId)
                        for userMatch in userMatches
                          if bestMatch?.clientId and userMatch.clientId
                            if userMatch._id.getTimestamp() > bestMatch._id.getTimestamp()
                              bestMatch = userMatch
                          else if !bestMatch?.clientId
                            if userMatch._id.getTimestamp() > bestMatch._id.getTimestamp()
                              bestMatch = userMatch
                        return done null, bestMatch


                    # Find by user details
                    (done) ->
                      return done() if userId?.length or not Object.keys(data.user).length > 3 or not data.user.dob or not data.user.last_name or not data.user.mail_postal

                      conditions = _.pick data.user, 'dob', 'mail_postal', 'last_name', 'first_name'
                      conditions.tenantId = req.tenant._id
                      User.findOne(conditions, {_id: 1, last_name: 1}).lean().exec done

                  ], (err, userResults) ->
                    logger.error "Find User err:", err if err
                    logger.info "match user by userId, best match, dob/zip/name...userResults:", JSON.stringify(userResults)
                    return next err if err

                    userId = null
                    for item in userResults
                      continue if not item

                      if item.userId?.length
                        userId = item.userId
                        break
                      else if item._id
                        userId = item._id
                        break

                    data.user = data.user.toObject() if data.user?.toObject

                    #don't know why toObject() loses these fields but it does.  So resetting them
                    data.user.stateUsername = req.body.sdUsername if req?.body?.sdUsername
                    data.user.statePassword = Secure.encrypt req.body.sdPassword if req?.body?.sdPassword
                    data.user.sdUsername = req.body.sdUsername if req?.body?.sdUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.sdPassword = Secure.encrypt req.body.sdPassword if req?.body?.sdPassword
                    data.user.azUsername = req.body.azUsername if req?.body?.azUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.azPassword = Secure.encrypt req.body.azPassword if req?.body?.azPassword
                    data.user.idUsername = req.body.idUsername if req?.body?.idUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.idPassword = Secure.encrypt req.body.idPassword if req?.body?.idPassword
                    data.user.nmUsername = req.body.nmUsername if req?.body?.nmUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.nmPassword = Secure.encrypt req.body.nmPassword if req?.body?.nmPassword
                    data.user.waUsername = req.body.waUsername if req?.body?.waUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.waPassword = Secure.encrypt req.body.waPassword if req?.body?.waPassword
                    data.user.coUsername = req.body.coUsername if req?.body?.coUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.coPassword = Secure.encrypt req.body.coPassword if req?.body?.coPassword
                    data.user.mtUsername = req.body.mtUsername if req?.body?.mtUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.mtPassword = Secure.encrypt req.body.mtPassword if req?.body?.mtPassword
                    data.user.nvUsername = req.body.nvUsername if req?.body?.nvUsername #we have to do this currently because username and password are saved on the User collection for now and need to be persistented when this user is created this way
                    data.user.nvPassword = Secure.encrypt req.body.nvPassword if req?.body?.nvPassword

                    data.user.tenantId = req.tenant._id if req.tenant?._id
                    data.user._id ?= userId if userId #Old code to maintain backwards compatibility
                    if req.body.matchUser and data.user._id isnt userId and data.user._id and userId
                      data.foundMatchUser = true
                      data.matchedUserId = userId
                      console.log "FOUND MATCH TO AN EXISTING USER, USING MATCHED USER INSTEAD OF A NEW USER.  #{data.user._id} -> #{userId}"

                    next err, data

                # SWITCH USER TO THE MATCHED USER INSTEAD if were are trying to match to an existing user.
                (data, next) ->
                  return next null, data unless req.body.matchUser and data.foundMatchUser and data.matchedUserId
                  User.byId data.matchedUserId, {internal: true}, (err, user) ->
                    return next err if err

                    #TODO: Merge devices, CIDS, Reminders, Users, other data? for now just use all the matched users data

                    #Merge Devices
                    if data.user.devices and !user.devices
                      user.devices = data.user.devices
                    else if data.user.devices and user.devices
                      for device_data in data.user.devices
                        exist = false
                        for device_user in user.devices
                          if device_data.deviceId is device_user.deviceId
                            exists = true
                        user.devices.push device_data unless exists

                    data.user = user #SWITCH USER!
                    data.user = data.user.toObject() if data.user?.toObject

                    return next err, data

                # Check preserve email, first_name, last_name, name if they existed on user already
                (data, next) ->
                  logger.info "# Check preserve email (findUser)"
                  return next null, data if not data.user._id
                  User.findOne(_id: data.user._id, {_id: 1, email:1, first_name: 1, last_name: 1, name: 1}).lean().exec (err, result) ->
                    logger.error "Find local user by state error:", err if err
                    if result and result._id
                      data.user.email = result.email if result.email
                      data.user.name = result.name if result.name
                      data.user.first_name = result.first_name if result.first_name
                      data.user.last_name = result.last_name if result.last_name
                      #logger.info "Preserving user names and email on state update.  Email:"+data.user.email
                    next err, data

                # Update state reminders if selected
                (data, next) ->
                  return next null, data unless data.user?._id?.toString().length
                  if data?.user?.reminders?.stateswpoints and points?.points?.length
                    State.byId data.stateId, (err, tState) ->
                      logger.error "Error retrieving state for points", err if err
                      logger.error "Error cound not find state for stateId: ", data.stateId unless tState
                      return next null, data unless tState
                      logger.info "Updating user reminders to include this state. ", tState.name
                      data.user.reminders.states.push(tState.name) if data?.user?.reminders?.states?.indexOf(tState.name) < 0
                      next null, data
                  else
                    next null, data

                # Save User Upsert
                (data, next) ->
                  logger.info "# Save User Upsert", data.user
                  return next null, user if not data.user
                  User.upsert data.user, {upsert: true}, (err, user) ->
                    logger.error "User upsert error:", err if err
                    user = user.toObject() if user?.toObject
                    logger.info "User upsert user:", JSON.stringify(user)
                    next err, user

                # Save cid
                (user, next) ->
                  return next null, user if not data.cid

                  userState = {
                    userId: user._id
                    stateId
                    cid: data.cid
                  }

                  UserState.upsert userState, (err) ->
                    next err, user

                # Save points
                (user, next) ->
                  return next null, user unless points?.points?.length
                  console.log "States::findUser points.points:", points.points

                  for point in points.points
                    point.userId = user._id
                    point.stateId = stateId

                  for point, i in points.points
                    point.tenantId = user.tenantId
                  Point.saveGroup points.points, (err) ->
                    return next err if err
                    next null, user

              ], (err, userInfo) ->
                return res.json err, 500 if err

                User.byId userInfo._id, (err, user) ->
                  return res.json err, 500 if err
                  user = user.toObject()

                  # Update user with new token and tokenExpires fields
                  token = new Token {
                    token: crypto.randomBytes(64).toString('hex')
                    expires: moment().add(2, 'months').toDate()
                    userId: user._id
                  }

                  token.save (err, token) ->
                    if err
                      logger.info "Failed to update local user token:", err
                      return res.json {error: err}, 500

                    return res.json {error: "Failed to update local user token"}, 500 unless token

                    result = {
                      user,
                      token: {
                        token: token.get 'token'
                        tokenExpires: token.get 'expires'
                      }
                    }

                    res.status(200).json result

    getByUserId: (userId, cb) ->

      User.findById userId, (err, user) ->
        return cb err if err

        Zipcode.findByCode user.mail_postal, (err, zipcode) ->
          return cb err if err
          return cb null, {} unless zipcode

          State.findByAbbreviation zipcode.state, (err, state) ->
            return cb err if err
            return cb null, state

    index: (req, res) ->
      State.index (err, states) ->
        return res.json err, 500 if err
        res.json states

    initByStateId: (req, res) ->
      stateId = req.param 'id'
      async.parallel [
        (done) -> # available
          State.getModelByStateId stateId, (err, model) ->
            return done err if err
            model.availableHunts done
        (done) -> # current
          Hunt.byStateId stateId, done
      ], (err, results) ->
        [available, current] = results
        return res.json err, 500 if err
        return res.json current if current?.length

        for hunt in available
          hunt.stateId = stateId

        saveHunt = (hunt, cb) ->
          hunt = new Hunt hunt
          hunt.save ->
            cb null, hunt

        async.map available, saveHunt, (err) ->
          return res.json err, 500 if err

          Hunt.byStateId stateId, (err, results) ->
            return res.json err, 500 if err
            res.json results

    montanaCaptcha: (req, res) ->
      State.initModel 'Montana', (err, montana) ->
        return res.json err, 500 if err

        montana.getCaptcha (err, data) ->
          return res.json err, 500 if err
          res.json data

    update: (req, res) ->
      return res.json {error: 'State id required'}, 400 unless req?.body?._id

      State.upsert req.body, (err, state) ->
        return res.json {error: err}, 500 if err
        res.json state.toJSON()

  }

  _.bindAll.apply _, [States].concat(_.functions(States))
  return States
