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
    azPortalData.azPassword = "AZMC-#{userAZPortal.clientId}-#{userAZPortal.last_name.toLowerCase()}"  #ex: AZMC-ClientId-lastname

    AZPortalAccount.upsert azPortalData, (err, userAZPortal) ->
      console.log "Error updating azPortal with password '#{azPortalData.azPassword}'. Error:", err if err
      return done err if err

      userData = {_id: userAZPortal.userId, azUsername: userAZPortal.azUsername.trim()}
      User.upsert userData, (err, user) ->
        console.log "ERROR, user azUsername update failed: ", err if err
        return done err if err
        User.updateStatePassword user._id, 'azPassword', userAZPortal.azPassword, (err, user) ->
          console.log "ERROR, user azPassword update failed: ", err if err
          azPasswordDecrypted = Secure.decrypt user.azPassword if user.azPassword
          console.log "User updated successfully: azUsername: #{user.azUsername}, azPassword: #{azPasswordDecrypted}"
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
      setPasswords = []
      for azacct in azaccts
        setPasswords.push azacct if azacct.azUsername?.length and not azacct.azPassword?.length

      console.log "found #{setPasswords.length} users"
      userTotal = setPasswords.length
      async.mapSeries setPasswords, processUser, (err) ->
        next err

  ], (err) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
