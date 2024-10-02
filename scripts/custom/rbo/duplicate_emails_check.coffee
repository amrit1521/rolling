_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/loop_all_users.coffee


config.resolve (
  logger
  Secure
  User
  api_rbo
  APITOKEN_RB
) ->

  tenantId = "53a28a303f1e0cc459000127"
  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  emailsIndex = {}
  stateReminders = {}
  members = []
  reps = []
  missingClientIds = []
  duplicateEmails = []


  clientIds = ["xxx","yyy"]

  processUser = (user, done) ->
    #return next null  #Skip processing this user
    userCount++
    return done null unless userCount > 1400
    console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, userId: #{user._id}"

    #Update stateReminders
    if user.reminders?.email is true and user.reminders?.states?.length > -1
      stateReminders[user._id.toString()] = {
        emailFlag: user.reminders.email
        states: user.reminders.states
      }

    #Update member count
    if user.isMember
      members.push {userId: user._id.toString(), name: user.name, clientId: user.clientId, email: user.email}

    #Update rep count
    if user.isRep
      reps.push {userId: user._id.toString(), name: user.name, clientId: user.clientId, email: user.email}

    #Update missing ClientIds count
    if !user.clientId
      missingClientIds.push {userId: user._id.toString(), name: user.name, clientId: user.clientId, email: user.email}

    #Duplicate users
    emailsIndex[user.email] = [] unless emailsIndex[user.email]
    emailsIndex[user.email].push {userId: user._id.toString(), name: user.name, clientId: user.clientId, email: user.email}

    #Update Mailchimp preferences
    if user.email
    #if user._id.toString() is "56e1ddcd88dd0cd7091ccd57"
      body = {}
      json = (content, errCode) ->
        if errCode
          console.log "response returned with: ", content
          console.log "response returned with errCode: ", errCode
        return done null
      res = {
        json: json
      }

      params = {
        direct: true
        token: APITOKEN_RB
        hunts: "false"
        rifles: "false"
        products: "false"
        newsletters: "false"
        state_reminders_text: "false"
        state_reminders_email: "false"
      }

      params.state_reminders_email = "true" if user.reminders?.email and (user.reminders?.types?.indexOf("app-start") > -1 or user.reminders?.types?.indexOf("app-end") > -1)
      params.state_reminders_text = "true" if user.reminders?.text and (user.reminders?.types?.indexOf("app-start") > -1 or user.reminders?.types?.indexOf("app-end") > -1)

      params.hunts = "true" if user.isMember or user.isRep
      params.rifles = "true" if user.isMember or user.isRep
      params.products = "true" if user.isMember or user.isRep
      params.newsletters = "true" if user.isMember or user.isRep

      params.hunts = "true" if user.subscriptions?.hunts is true
      params.rifles = "true" if user.subscriptions?.rifles is true
      params.products = "true" if user.subscriptions?.products is true
      params.newsletters = "true" if user.subscriptions?.newsletters is true

      req = {
        params: params
        body: body
        user: user
      }
      if true
        api_rbo.user_notifications req, res
      else
        console.log "updating user notificatios for req: ", req
        return done null

    else
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
        User.findByTenant tenantId, {internal: true}, (err, users) ->
        #User.index next
        #User.find().lean().exec
          next err, users

# For each user, do stuff
    (users, next) ->
      users = [users] unless typeIsArray users
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, processUser, (err) ->

        for email in Object.keys(emailsIndex)
          duplicateEmails.push emailsIndex[email] if emailsIndex[email]?.length > 1

        next err

  ], (err) ->

    console.log "Finished"
    console.log "stateReminders: ", Object.keys(stateReminders).length
    console.log "members: ", members.length
    console.log "reps: ", reps.length
    console.log "missing client ids: ", missingClientIds.length
    console.log "emailsIndex: ", Object.keys(emailsIndex).length
    console.log "duplicateEmails: ", duplicateEmails.length

    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
