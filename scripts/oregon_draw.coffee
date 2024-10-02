_              = require 'underscore'
async          = require "async"
config         = require './../config'
moment         = require 'moment'
request        = require 'request'
uuid           = require "uuid"
winston        = require 'winston'

stateId = "52aaa4cbe4e055bf33db64a1"

config.resolve (
  DrawResult
  logger
  HuntinFoolClient
  HuntinFoolState
  Secure
  User
  UserState

  Oregon
) ->

  userCounter = 0
  userTotal = 0

  addHunterId = (user, cb) ->
    UserState.findOne({userId: user._id, stateId}).lean().exec (err, userState) ->
      return cb err if err
      return cb null, user unless userState
      user.cid = userState.cid
      cb null, user

  logOn = ->
    logger.add(winston.transports.Console, {
      colorize: true
      timestamp: true
    })

  logOff = ->
    return
    logger.remove(winston.transports.Console)

  getDrawResults =  (user, cb) ->
    year = moment().year()
    console.log "Processing user #{user.first_name} #{user.last_name} [#{user.clientId}] - #{userCounter} of #{userTotal}"
    return cb() unless user.cid?.length

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

        Oregon.drawResults opts, user, (err, results) ->
          console.log "results:", results
          next err, results

      # Delete previous results
      (results, next) ->
        DrawResult.deleteByUserStateYear user._id, stateId, moment().year(), (err) ->
          next err, results

      # Save results
      (results, next) ->
        return next() unless results instanceof Array
        saveDraw = (result, lnext) ->
          result.userId = user._id
          result.stateId = stateId
          result.year = year

          drawResult = new DrawResult result
          drawResult.save (err) -> lnext err

        async.map results, saveDraw, (err) ->
          next err

    ], (err) ->

      if err?.code is '1007'
        err = null
        console.log "Customer: #{user.first_name} #{user.last_name} not found"

      console.log "Done #{user.first_name} #{user.last_name}"
      cb()

  async.waterfall [

    # Get Users
    (next) ->

      User.find().lean().exec (err, users) ->
        return next err if err
        console.log "users count:", users.length

        return next null, users

    # Add Oregon hunter ids
    (users, next) ->
      async.map users, addHunterId, (err) ->
        next err, users

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
