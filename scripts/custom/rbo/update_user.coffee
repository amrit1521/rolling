_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/update_user.coffee

UPDATE_USER = false

config.resolve (
  logger
  Secure
  User
) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "58d328e8fe41db1317c946e9,58d328e8fe41db1317c946e9"
  skipList = ""

  processUser = (user, done) ->
    userCount++

    if true
      #return next null  #Skip processing this user
      return done null unless userCount < 3

    User.byId user._id, {internal: true}, (err, user) ->
      console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"
      if skipList.indexOf(user._id) > -1
        console.log "SKIPPING USER from skip list!"
        return done null

      userData = {}
      userData._id = user._id

      #Setup userData with desired fields to update
      #userData.name = 'new'

      console.log "about to update user with data: ", userData
      if UPDATE_USER
        User.upsert userData, {upsert: false}, (err, userRsp) ->
          console.log "User.upsert() completed with err: ", err if err
          return done err if err
          console.log "User.upsert() completed successfully with rsp: ", userRsp
          return done null, userRsp
      else
        console.log "UPDATE_USER = false, SKIPPING UPDATING THE USER."
        return done null


  getUsers = (cb) ->
    ###
    c_and = { $and: [
      {first_name: tran.first_name}
      {last_name: tran.last_name}
    ]
    }
    c_or = []
    c_or.push {email: tran.email} if tran.email
    c_or.push {phone_cell: tran.phone} if tran.phone
    c_or.push {phone_home: tran.phone} if tran.phone
    c_or.push {physical_address: tran.address1} if tran.address1
    c_or.push {mail_address: tran.address1} if tran.address1
    c_or.push {memberId: tran.memberId} if tran.memberId
    c_or.push c_and
    conditions = {
      $and: [
        { $or: c_or },
        { tenantId: "5684a2fc68e9aa863e7bf182"},
      ]
    }
    ###
    conditions = {
      tenantId: "5684a2fc68e9aa863e7bf182"
    }
    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results

  #HuntinFoolState.find({tenantId: "5684a2fc68e9aa863e7bf182", mt_check: "True"}).lean().exec (err, results) ->
  #  users = []
  #  for result in results
  #    users.push {_id: result.userId}
  #  cb err, users


  async.waterfall [

    # Get users
    (next) ->
      userId = process.argv[2]
      if userId
        User.findById userId, {internal: true}, next
      else
        getUsers(next)

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
