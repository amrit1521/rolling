_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/check_dups.coffee

UPDATE_USER = false

config.resolve (
  logger
  Secure
  User
  Purchase

) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  TENANT_ID = "5684a2fc68e9aa863e7bf182"
  TENANT_ID = "53a28a303f1e0cc459000127"
  START = -1
  END = -1

  CONTACTABLE_USERS = []
  NON_CONTACTABLE_USERS = []
  IN_APP_ONLY_WITH_REMINDERS = []
  IN_APP_CO_ONLY = []
  IN_APP_NO_REMINDERS = []
  PARTIAL_INFO_USER = []
  NO_INFO_USER = []

  DUP_USERS_BY_EMAIL = []
  DUP_USERS_BY_EMAIL_AND_NAME = []
  DUP_USERS_BY_SSN = []

  APP_USER = {}
  EMAIL_INDEX = {}
  EMAIL_NAME_INDEX = {}

  processUser = (user, done) ->
    userCount++
    return done null if START > -1 and userCount < START
    return done null if END > -1 and userCount > END
    console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"

    async.waterfall [
      # Get User Data
      (next) ->
        return next null, user #already have the user, move on
        User.byId user._id, {internal: true}, (err, user) ->
          next err, user

      # Calc metadata
      (user, next) ->
        user.isAppUser = true if user.devices?.length
        user.platform = user.devices[0].platform if user.devices?.length > 0 and user.devices[0].platform
        user.hasEmail = true if user.email?.length
        user.hasPhone = true if user.phone_cell? or user.phone_home or user.phone_day
        user.reminderStates = user.reminders.states.join(",") if user.reminders?.states
        if user.physical_address and user.physical_city and user.physical_postal and user.physical_state
          user.hasMailingAddress = true
        if user.mail_address and user.mail_city and user.mail_postal and user.mail_state
          user.hasMailingAddress = true

        return next null, user

      # Assign to a bucket
      (user, next) ->
        if user.hasEmail or user.hasPhone or user.hasMailingAddress
          if user.reminders?.email or user.reminders?.text or user.reminders?.inApp or user.hasMailingAddress
            CONTACTABLE_USERS.push user
          else
            NON_CONTACTABLE_USERS.push user
        else if user.isAppUser
          if user.reminderStates and user.reminderStates.trim() != "Colorado"
            IN_APP_ONLY_WITH_REMINDERS.push user
          else if user.reminderStates and user.reminderStates.trim() is "Colorado" and !user.first_name and !user.last_name and !user.mail_postal and !user.physical_postal
            IN_APP_CO_ONLY.push user
          else
            IN_APP_NO_REMINDERS.push user
        else if user.first_name or user.last_name or user.dob or user.mail_postal or user.physical_postal
          PARTIAL_INFO_USER.push user
        else
          NO_INFO_USER.push user

        return next null, user

    ], (err, user) ->
      #console.log "done processing user."
      console.log "Error: " if err
      return done err, user


  getUsers = (cb) ->
    conditions = {
      "tenantId" : TENANT_ID
    }
    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results

  async.waterfall [

    # Get users
    (next) ->
      userId = process.argv[2]
      if userId
        User.findById userId, {internal: true}, next
      else
        getUsers (err, users) ->
          return next err, users

    # For each user, do stuff
    (users, next) ->
      users = [users] unless typeIsArray users
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, processUser, (err, users) ->
        return next err, users

    # Calc statistics
    (users, next) ->
      for user in users
        if APP_USER[user.platform]
          APP_USER[user.platform] = APP_USER[user.platform] + 1
        else
          APP_USER[user.platform] = 1
      return next null, users

    # Calc dups
    (users, next) ->
      for user in CONTACTABLE_USERS
        user.email = user.email.toLowerCase() if user.email
        if EMAIL_INDEX[user.email]
          EMAIL_INDEX[user.email] = EMAIL_INDEX[user.email] + 1
          DUP_USERS_BY_EMAIL.push user
        else
          EMAIL_INDEX[user.email] = 1

        email_name = "#{user.email}_#{user.first_name}_#{user.last_name}"
        email_name = email_name.toLowerCase() if email_name
        if EMAIL_NAME_INDEX[email_name]
          EMAIL_NAME_INDEX[email_name] = EMAIL_NAME_INDEX[email_name] + 1
          DUP_USERS_BY_EMAIL_AND_NAME.push user
        else
          EMAIL_NAME_INDEX[email_name] = 1

      return next null, users

    # Report
    (users, next) ->
      console.log "TOTAL USERS: ", userTotal
      console.log "CONTACTABLE_USERS: ", CONTACTABLE_USERS.length
      console.log "NON_CONTACTABLE_USERS: ", NON_CONTACTABLE_USERS.length
      console.log "IN_APP_ONLY_WITH_REMINDERS: ", IN_APP_ONLY_WITH_REMINDERS.length
      console.log "IN_APP_CO_ONLY: ", IN_APP_CO_ONLY.length
      console.log "IN_APP_NO_REMINDERS: ", IN_APP_NO_REMINDERS.length
      console.log "PARTIAL_INFO_USER: ", PARTIAL_INFO_USER.length
      console.log "NO_INFO_USER: ", NO_INFO_USER.length
      console.log "CONTACTABLE_USERS # DUPS BY EMAIL: ", DUP_USERS_BY_EMAIL.length
      console.log "CONTACTABLE_USERS # DUPS BY EMAIL+NAME: ", DUP_USERS_BY_EMAIL_AND_NAME.length
      #console.log "INDEX: ", EMAIL_NAME_INDEX
      console.log "App Users Totals: ", APP_USER
      return next null, users

  ], (err, users) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
