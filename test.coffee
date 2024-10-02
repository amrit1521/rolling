_ = require 'underscore'
async = require "async"
config = require './config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee test.coffee

USE_PROD_ENV = false
if USE_PROD_ENV
  TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO
else
  TENANT_ID = "5bd75eec2ee0370c43bc3ec7" #TEST

console.log "USE_PROD_ENV: ", USE_PROD_ENV

config.resolve (
  logger
  Secure
  User
  Purchase
  huntCatalogs
) ->


  console.log "Calling async.waterfall..."

  async.waterfall [

# Test
    (next) ->
      console.log "Check users"
      clientIds = ["VD2","VD90"]
      next null, clientIds

    (clientIds, next) ->
      console.log "clientIds: ", clientIds
      conditions = {tenantId: TENANT_ID}
      if clientIds
        conditions['clientId'] = clientIds

      console.log "calling User.find with conditions: ", conditions
      User.find(conditions).lean().exec()
        .then (users) ->
          console.log "then() results: ", users
          for user in users
            console.log "client: #{user.clientId}, name: #{user.name}, email: #{user.email}"
          return next("Test completed", null)
        .catch (err) ->
          console.log "catch() err: ", err
          return next err

  ], (results, err) ->

    console.log "Finished with results, err: ", results, err
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
