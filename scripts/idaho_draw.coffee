_              = require 'underscore'
async          = require "async"
config         = require './../config'
moment         = require 'moment'
request        = require 'request'
uuid           = require "uuid"
winston        = require 'winston'

stateId = "52aaa4cbe4e055bf33db649b" # Idaho state ID

config.resolve (
  DrawResult
  logger
  HuntinFoolClient
  HuntinFoolState
  Secure
  User
  UserState

  Idaho
) ->

  userCounter = 0
  userTotal = 0

  logOn = ->
    logger.add(winston.transports.Console, {
      colorize: true
      timestamp: true
    })

  logOff = ->
    logger.remove(winston.transports.Console)

  getDrawResults =  (user, cb) ->
    year = moment().year()
    console.log "Processing user #{user.first_name} #{user.last_name} [#{user.clientId}] - #{userCounter} of #{userTotal}"

    user.results = {}
    userCounter++
    logOff()

    parts = [user.field1, user.field2]

    decrypted = Secure.desocial parts
    user.ssn = decrypted.social if decrypted.social
    user.dob = decrypted.dob if decrypted.dob

    # user.results[state.name] = {}
    # console.log "Starting #{state.name} - #{user.first_name} #{user.last_name}"
    opts = {
      jar: request.jar()
    }

    async.waterfall [

      # Get draw results
      (next) ->

        Idaho.drawResults opts, user, (err, results) ->
          logOn()
          next err, results

      # Delete previous results
      (results, next) ->
        DrawResult.deleteByUserState user._id, stateId, (err) ->
          next err, results

      # Save results
      (results, next) ->
        return next() unless results instanceof Array
        saveDraw = (result) ->
          result.userId = user._id
          result.stateId = stateId
          result.year = year

          drawResult = new DrawResult result
          drawResult.save (err) ->
            next err

        async.map results, saveDraw, (err) ->
          next err

    ], (err) ->
      err = null if err is 'SKIP'

      if err?.code is '1007'
        err = null
        console.log "Customer: #{user.first_name} #{user.last_name} not found"

      console.log "Done #{user.first_name} #{user.last_name}"
      cb()

  async.waterfall [

    # Get Idaho hunters
    (next) ->
      console.log 'get users'
      HuntinFoolState.find({id_check: 'True'}, {client_id: 1}).lean().exec (err, users) ->
        return next err if err
        console.log "idaho Hunters count:", users.length
        return next null, users

    # Get Huntinfool Clients
    (hunters, next) ->

      clientIds = _.pluck hunters, 'client_id'
      HuntinFoolClient.find({client_id: {$in: clientIds}}, {userId: 1}).lean().exec (err, clients) ->
        return next err if err

        console.log "clients count:", clients.length
        return next null, clients

    # Get Users
    (clients, next) ->

      userIds = _.pluck clients, 'userId'
      User.find({_id: {$in: userIds}}).lean().exec (err, users) ->
        return next err if err
        console.log "users count:", users.length

        return next null, users

    # Get user's receipts
    (users, next) ->
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, getDrawResults, next

  ], (err, users) ->
    console.log "Finished:", users.length
    if err
      logger.error "Found an error:", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
