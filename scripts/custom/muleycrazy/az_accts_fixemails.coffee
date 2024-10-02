_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

config.resolve (
  logger
  Secure
  User
  AZPortalAccount

) ->

  tenantId = "56f44d39e680961c4b86f6f7"
  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  processUser = (userAZPortal, done) ->
    #return done null, userAZPortal  #Skip processing this user
    userCount++
    #return done null, null unless userCount < 2
    console.log "****************************************Processing #{userCount} of #{userTotal}, #{userAZPortal.first_name} #{userAZPortal.last_name}, clientId: #{userAZPortal.clientId}, azUsername: #{userAZPortal.azUsername}, azPassword: #{userAZPortal.azPassword}"

    azPortalData = {_id: userAZPortal._id}
    azPortalData.azUsername = userAZPortal.azUsername + ".com"

    AZPortalAccount.upsert azPortalData, (err, userAZPortal) ->
      console.log "Error updating azPortal with username '#{azPortalData.azUsername}'. Error:", err if err
      return done err if err

      userData = {_id: userAZPortal.userId, azUsername: userAZPortal.azUsername.trim()}
      User.upsert userData, (err, user) ->
        console.log "ERROR, user azUsername update failed: ", err if err
        console.log "User updated successfully: azUsername: #{user.azUsername}"
        return done err, user


  async.waterfall [

# Get users
    (next) ->
      console.log 'get all users'

      singleUserTest = false
      if singleUserTest
        clientId = "MC2"
        AZPortalAccount.byClientId clientId, next
      else
        AZPortalAccount.findByTenant tenantId, (err, azaccts) ->
          next err, azaccts

# For each user, do stuff
    (azaccts, next) ->
      azaccts = [azaccts] unless typeIsArray azaccts

      console.log "found #{azaccts.length} users"
      userTotal = azaccts.length
      async.mapSeries azaccts, processUser, (err) ->
        next err

  ], (err) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
