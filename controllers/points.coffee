_ = require "underscore"
async = require "async"
PUBNUB = require "pubnub"
moment = require "moment"
util = require "util"
uuid = require "uuid"

module.exports = (
  Hunt
  email
  logger
  Point
  PUBNUB_PUBLISH_KEY
  PUBNUB_SUBSCRIBE_KEY
  State
  User
  UserState
) ->

  userId = uuid.v4()

  pubnub = new PUBNUB
    subscribe_key: PUBNUB_SUBSCRIBE_KEY
    publish_key: PUBNUB_PUBLISH_KEY
    userId: userId

  Points = {

    all: (req, res) ->

      userId = req.param 'userId'

      async.waterfall [
        (next) ->
          State.hasPoints (err, states) ->
            next err, states

        (states, next) ->
          User.findById userId, {internal: true}, (err, user) ->
            next err, states, user

        (states, user, next) =>
          async.mapSeries states, @getState(user), (err, results) ->
            next err, results
      ], (err) ->
        return res.json {error: err}, 500 if err
        res.json {status: "OK"}

    getMontanaPoints: (req, res) ->

      User.findById userId, {internal: true}, (err, user) =>
        user.captcha = req.param('captcha')

        State.findByAbbreviation 'MT', (err, state) =>
          options = _.extend {}, {userId: user._id, stateId: state._id, refresh: true}, {user}
          console.log "options:", options

          @getStatePoints options, (err, result) ->
            return res.json(err, 500) if err
            res.json result

    getPoints: (userId, stateId, cb) ->

      async.waterfall [

        (next) ->
          State.byId stateId, next

        (state, next) ->
          UserState.byStateAndUser userId, stateId, (err, userState) ->
            return next err if err
            state.cid = userState.cid if userState

            next null, state

        (state, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            return next err if err
            state.hunts = hunts
            next null, state

        (state, next) ->
          Point.byUserAndState userId, stateId, (err, points) ->
            return next err if err

            for hunt in state.hunts
              removeIndex = []

              for point, i in points
                continue unless point.name.trim().toLowerCase() is hunt.match.toLowerCase()
                removeIndex.push i
                hunt.point = point
                break

              removeIndex.reverse()
              for index in removeIndex
                points.splice(index, 1)

            for point in points
              hunt = _.pick point, 'name', 'stateId'
              hunt.point = point
              state.hunts.push hunt

            next null, state

        (state, next) ->
          UserState.byStateAndUser userId, stateId, (err, userState) ->
            state.cid = userState.cid if userState?.cid
            next null, state

      ], cb

    getState: (user) ->
      userId = user._id

      (state, cb) =>
        return cb() unless state.hasPoints
        logger.info "Load #{state.name} points"

        async.waterfall [
          #Pull state points and save them to DB
          (next) =>
            options = _.extend {}, {userId, stateId: state._id, refresh: true}, {user: _.clone(user)}
            @getStatePoints options, (err, result) ->
              logger.error "#{state.name} getStatePoints err:", err if err

              if err and (not err.code or err.code > 999)
                errorDate = moment().format('YYYY-MM-DD HH:mm:ss ZZ')
                console.log "Something bad happened at [Points::getState] #{errorDate}:", err
                mailOptions =
                  from: "GotMyTag Errors <support@gotmytag.com>"
                  to: "support@gotmytag.com"
                  subject: "An unexptected Points::all API error occurred: #{errorDate} - GotMyTag.com"
                  text: util.inspect(err, {depth: 5})

                email.sendMail mailOptions, (err, response) ->
                  return console.log "API error email failed:", err if err
                  console.log "Points error email sent:", response

              if err
                message = {
                  type: 'state-update'
                  data: state
                  error: err
                  userId
                }

                pubnub.publish {
                  channel: userId
                  message
                  callback: (e) ->
                    console.log "SUCCESS!", e
                    return

                  error: (e) ->
                    console.log "FAILED! RETRY PUBLISH!", e
                    return
                }

                return next err

              next()

          (next) =>
            #Retrieve state points from the DB, and publish pubnub state-update event with them
            @getPoints userId, state._id, (err, state) ->
              message = {
                type: 'state-update'
                data: state
                userId
              }

              console.log "\n\n\n\n\n\n\n\n\n\n\n\n"
              console.log "publish channel:", userId
              console.log "publish:", util.inspect(message, {depth: 5})
              console.log "\n\n\n\n\n\n\n\n\n\n\n\n"

              pubnub.publish {
                channel: userId
                message
                callback: (e) ->
                  console.log "SUCCESS!", e
                  return

                error: (e) ->
                  console.log "FAILED! RETRY PUBLISH!", e
                  return
              }

              next err, state

        ], (err, state) ->
          cb null, state

    getStatePoints: (options, cb) ->
      conditions = _.extend({}, _.pick(options, 'cid', 'stateId', 'refresh', 'captcha'), {userId: options.user._id})

      State.byId conditions.stateId, (err, state) ->
        console.log "points::getStatePoints err:", err if err
        return err if err
        message = {
          type: 'state-get-points'
          data: state
          userId: conditions.userId
        }
        pubnub.publish {
          channel: conditions.userId
          message
          callback: (e) ->
            console.log "pubnub.publish", e
            return
          error: (e) ->
            console.log "FAILED! pubnub.publish", e
            return
        }

      async.waterfall [
        (next) ->

          return next() if conditions.cid

          UserState.byStateAndUser conditions.userId, conditions.stateId, (err, userState) ->
            return next err if err
            conditions.cid = userState.cid if userState?.cid
            return next()

        #If not refreshing, get points and skip to end of waterfall returning the found points for this state.
        (next) ->
          return next() if conditions.refresh

          Point.byUserAndState conditions.userId, conditions.stateId, (err, points) ->
            return next err if err
            next {points: points}

        (next) ->

          State.getModelByStateId conditions.stateId, (err, model) ->
            return next {error: "Unable to find state model", code: 'NoModelForState'} if err?.code is 404 or not model
            return next err if err
            next null, model

        #Get Points from the state
        (model, next) ->

          options.user.cid = conditions.cid if conditions.cid
          model.points options.user, conditions, (err, points) ->
            return next err if err
            return next null, {points: []} unless points
            return next null, points unless points?.points
            for point in points.points
              point.userId = conditions.userId
              point.stateId = conditions.stateId

            return next null, points

        # Check preserve email, first_name, last_name, name, and dob if they existed on user already
        (points, next) ->
          logger.info "points: # Check preserve email (getStatePoints), and DOB check.", points
          return next null, points unless options.user?._id?.toString?()?.length
          logger.info "FOUND INVALID DOB", options.user if options.user.dob == 'Invalid date'
          User.findOne(_id: options.user._id, {_id: 1, email:1, first_name: 1, last_name: 1, name: 1, dob: 1}).lean().exec (err, result) ->
            logger.error "Find local user by state points error:", err if err
            if result and result._id
              options.user.email = result.email if result.email
              options.user.name = result.name if result.name
              options.user.first_name = result.first_name if result.first_name
              options.user.last_name = result.last_name if result.last_name
              options.user.dob = result.dob if result.dob
            next err, points

        # Update state reminders if selected
        (points, next) ->
          return next null, points unless options.user?._id?.toString().length
          if options?.user?.reminders?.stateswpoints and points?.points?.length
            State.byId points.points[0].stateId, (err, tState) ->
              logger.error "Error retrieving state for points", err if err
              logger.error "Error cound not find state for stateId: ", points.points[0].stateId unless tState
              return next null, points unless tState
              logger.info "Updating user reminders to include this state. ", tState.name
              options.user.reminders.states.push(tState.name) if options?.user?.reminders?.states?.indexOf(tState.name) < 0
              next null, points
          else
            next null, points

        # Save user
        (points, next) ->
          return next null, points unless options.user?._id?.toString?()?.length

          User.upsert options.user, {upsert: true}, (err, user) ->
            console.log "User upsert error:", err if err
            user = user.toObject() if user?.toObject
            console.log "User upsert user (getStatePoints):", JSON.stringify(user)

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
            next err, points

        # Save UserState update
        (points, next) ->
          return next null, points unless conditions.cid?.length

          userState = _.pick conditions, 'stateId', 'userId', 'cid'
          UserState.upsert userState, (err) ->
            next err, points

      ], (err, points) ->
        return cb null, err.points if err?.points
        return cb err if err

        conditions = {
          stateId: {$in: [options.stateId]}
          userId: options.user._id
        }

        #Clear all points for this state and resave them.
        Point.remove conditions, (err) ->
          return cb err if err

          for point, i in points.points
            point.tenantId = options.user.tenantId
          cb null, points.points unless points?.points?.length
          Point.saveGroup points.points, (err) ->
            return cb err if err
            cb null, points.points

    byState: (req, res) ->
      console.log "req.params:", req.params
      {userId, stateId, cid, refresh} = req.params

      if cid is 'true'
        refresh = true
        cid = null

      User.findById req.param('userId'), {internal: true}, (err, user) =>
        console.log "byState req.params:", req.params
        options = _.extend {}, {userId, stateId, cid, refresh}, {user}
        console.log "options:", options
        @getStatePoints options, (err, result) ->
          return res.json(err, 500) if err
          res.json(result)

  }

  _.bindAll.apply _, [Points].concat(_.functions(Points))
  return Points
