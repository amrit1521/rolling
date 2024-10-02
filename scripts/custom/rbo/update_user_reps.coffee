_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/update_user_reps.coffee 0 3000 5c3d00cd3a386a39277dc2ee

config.resolve (
  logger
  Secure
  User
  UserRep
  userReps
) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "58d328e8fe41db1317c946e9,58d328e8fe41db1317c946e9"
  skipList = ""

  userRepsCtrl = userReps

  console.log "DEBUG: process.argv: ", process.argv

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
    if skipList.indexOf(user._id) > -1
      console.log "SKIPPING USER from skip list!"
      return done null

    userRepsCtrl.update_user_reps user._id, (err, userRepEntry) ->
      if err or !userRepEntry
        console.log "Error: Failed to update UserRep entry.  Error: ", err
        problemUsers[user._id] = {user: user, err: err}
      else if !userRepEntry
        console.log "Error: Failed to update UserRep entry.  Error empty update: ", userRepEntry
        problemUsers[user._id] = {user: user, err: err}
      else
        console.log "Successfully updated userRepEntry: ", userRepEntry if userRepEntry
      return done err, userRepEntry

  getUsers = (tenantId, cb) ->
    conditions = {
      tenantId: tenantId
    }
    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results

  async.waterfall [
    # Get users
    (next) ->
      userId = process.argv[4]
      if userId
        User.findById userId, {internal: true}, next
      else
        getUsers("5bd75eec2ee0370c43bc3ec7", next)
        #getUsers("5684a2fc68e9aa863e7bf182", next) #LIVE PRODUCTION RBO TENANT

    # For each user, do stuff
    (users, next) ->
      users = [users] unless typeIsArray users
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, processUser, (err) ->
        next err

  ], (err) ->
    console.log "Finished"
    console.log "DEBUG: problemUsers: ", problemUsers
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
