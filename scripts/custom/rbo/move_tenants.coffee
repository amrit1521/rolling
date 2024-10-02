_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/move_tenants.coffee

UPDATE_USER = true


config.resolve (
  logger
  Secure
  Tenant
  User
  Point
  Application
  DrawResult
  HuntinFoolState
  HuntinFoolClient
  mailchimpapi


) ->

  oldTenantId = "53a28a303f1e0cc459000127"
  newTenantId = "5684a2fc68e9aa863e7bf182"

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "xxxxxxxxxx,xxxxxxxxxxxxxxx"
  skipList = ""

  usersModifiedCount = 0

  processUser = (user, done) ->
    userCount++

    #if true
      #return done null unless usersModifiedCount < 1

    User.byId user._id, {internal: true}, (err, user) ->
      console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, email: #{user.email}, userId: #{user._id}"
      if skipList.indexOf(user._id.toString()) > -1 or user.isAdmin
        console.log "SKIPPING SKIP LIST USER!"
        return done null
      else if user.email?.indexOf("gohunt") > -1 or user.email?.indexOf("huntinfool") > -1 or user.email?.indexOf("eastm") > -1
        console.log "SKIPPING SPECIFIC EMAIL USER!", user.email, user.name
        return done null
      else if !user?.email?
        console.log "SKIPPING USER, EMAIL DOES NOT EXIST"
        return done null
      else if user.reminders.email or user.reminders.text
          User.findByEmail user.email, newTenantId, {}, (err, existing_user) ->
            return done err if err
            if existing_user?.email
              console.log "SKIPPING USER, ALREADY EXISTS IN NEW TENANT!"
              return done null
            else if user.reminders.states?.length > 0

              console.log "Updating user's tenant!"
              return done null, user unless UPDATE_USER

              async.waterfall [
                #set defaults
                (next) ->
                  userData = {}
                  userData._id = user._id
                  userData.tenantId = newTenantId
                  userData.parentId = "5c3fc283e4410818d306c658" #"Point Hunter" https://rollnbones.gotmytag.com/#!/admin/masquerade/5c3fc283e4410818d306c658
                  userData.imported = "GMT"
                  return next null, userData

                #get new clientId
                (userData, next) ->
                  Tenant.getNextClientId userData.tenantId, (err, newClientId) ->
                    return next err if err
                    return next "Error: new ClientId not found for tenant id: #{userData.tenantId}" unless newClientId
                    userData.clientId = "RB" + newClientId
                    return next null, userData

                #update the User Model
                (userData, next) ->
                  console.log "User.upsert() userData", userData
                  User.upsert userData, {upsert: false}, (err, updatedUser) ->
                    return next err if err
                    console.log "Successfully updated user: ", updatedUser._id, updatedUser.name
                    usersModifiedCount++
                    return next err, updatedUser

                #update the Point Model
                (updatedUser, next) ->
                  Point.updateTenant updatedUser._id, newTenantId, (err, rsp) ->
                    return next err if err
                    console.log "Successfully updated point model ", rsp
                    return next null, updatedUser

                #update the Application Model
                (updatedUser, next) ->
                  Application.updateTenant updatedUser._id, updatedUser.clientId, newTenantId, (err, rsp) ->
                    return next err if err
                    console.log "Successfully updated Application model ", rsp
                    return next null, updatedUser

                #update the DrawResult Model
                (updatedUser, next) ->
                  DrawResult.updateTenant updatedUser._id, newTenantId, (err, rsp) ->
                    return next err if err
                    console.log "Successfully updated DrawResult model ", rsp
                    return next null, updatedUser

                #update the HuntinFoolClient Model
                (updatedUser, next) ->
                  HuntinFoolClient.updateTenant updatedUser._id, updatedUser.clientId, newTenantId, (err, rsp) ->
                    return next err if err
                    console.log "Successfully updated HuntinFoolClient model ", rsp
                    return next null, updatedUser

                #update the HuntinFoolState Model
                (updatedUser, next) ->
                  HuntinFoolState.updateTenant updatedUser._id, updatedUser.clientId, newTenantId, (err, rsp) ->
                    return next err if err
                    console.log "Successfully updated HuntinFoolState model ", rsp
                    return next null, updatedUser

                #update MailChimp subscription list
                (updatedUser, next) ->
                  return next null, updatedUser unless user?.reminders?.email
                  tUser = {
                    clientId: updatedUser.clientId
                    email: updatedUser.email
                    first_name: updatedUser.first_name
                    last_name: updatedUser.last_name
                    subscriptions: {}
                  }
                  tUser.subscriptions.statereminders_email = true
                  tUser.subscriptions.hunts = true
                  tUser.subscriptions.products = true
                  tUser.subscriptions.rifles = true
                  tUser.subscriptions.newsletters = true
                  mailchimpapi.upsertUser "MASTER", tUser, (err, results) ->
                    return next err if err
                    console.log "Successfully updated Mail Chimp"
                    return next null, updatedUser


              ], (err, updatedUser) ->
                console.log "Error: ", err if err
                return done null, updatedUser

            else
              #console.log "User is active but has removed all notifications states."
              return done null
      else
        #console.log "User is not active"
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
      tenantId: oldTenantId
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
        getUsers(next)

    # For each user, do stuff
    (users, next) ->
      users = [users] unless typeIsArray users
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, processUser, (err, users) ->
        return next err, users

  ], (err, users) ->
    console.log "Finished"
    console.log "usersModifiedCount: ", usersModifiedCount
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)