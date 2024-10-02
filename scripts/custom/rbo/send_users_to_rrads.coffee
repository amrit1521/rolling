_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/send_users_to_rrads.coffee
#         coffee /var/www/gotmytag/scripts/custom/rbo/send_users_to_rrads.coffee

config.resolve (
  logger
  Secure
  User
  api_rbo_rrads
) ->

  TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO
  #TENANT_ID = "5bd75eec2ee0370c43bc3ec7" #TEST
  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  clientIds = ["RB1"]

  processUser = (user, done) ->
    #return next null  #Skip processing this user
    userCount++
    #return done null unless userCount > 244
    console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, email: #{user.email}, userId: #{user._id}"
    req = {}
    params = {}
    params.tenantId = TENANT_ID
    params._id = user._id
    req.params = params

    api_rbo_rrads.user_upsert_rads req, (err, results) =>
      console.log "user_upsert_rads ERROR: ", err if err
      console.log "user_upsert_rads results status: ", results.status
      json = JSON.parse(results.results)
      tUser = json.user if json?.user?
      console.log "results user: email: #{tUser.email}, name: #{tUser.name}" if tUser
      return done null


  async.waterfall [

# Get users
    (next) ->
      console.log 'get all users'

      singleUserTest = false

      if singleUserTest
        userId = "525ffd406beefe5465000003"
        User.findById userId, {internal: true}, next
      else
        #PARENT_ID = "5d7146c2e5aaa85ca983e391"  #Valhalla
        PARENT_ID = "5d71421de5aaa85ca983e390"  #Bluffs
        #User.findByTenant tenantId, {internal: true}, (err, users) ->
        #  next err, users
        User.find(tenantId: TENANT_ID, parentId: PARENT_ID).lean().exec
          .then (result) ->
            next null, result
          .catch (err) ->
            next(err)


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
