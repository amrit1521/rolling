_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/authorize_net_test.coffee

UPDATE_USER = false

config.resolve (
  authorizenetapi,
  User
) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  TENANT_ID = "5bd75eec2ee0370c43bc3ec7"
  START = -1
  END = -1

  async.waterfall [
    #
    (next) ->
      arg = process.argv[2]
      userId = "5bd7607b02c467db3f70eda2"
      User.byId userId, (err, user) ->
        return next err, user

    # Create/Update customer profile
    (user, next) ->
      skip = true
      return next null, user, null if skip
      console.log "Testing authorize.net customer api with user: ", user._id, user.clientId, user.name
      authorizenetapi.upsertCustomerProfile user, (err, results) ->
        return next err, user, results

    # Create/Update customer payment profile
    (user, results, next) ->
      skip = false
      return next null, user, null if skip
      console.log "Testing authorize.net payment profile api with user: ", user._id, user.clientId, user.name
      paymentInfo = {}
      card = {
        number: "4242424242424242"
        month: "08"
        year: "2022"
        code: "999"
        first_name: "TestF"
        last_name: "TestL"
        address: "222 S 222 W"
        city: "Spanish"
        state: "Utah"
        postal: "88888"
        country: "United States"
      }
      paymentInfo.authorize_net_data_descriptor = "COMMON.ACCEPT.INAPP.PAYMENT"
      paymentInfo.authorize_net_data_value = "eyJjb2RlIjoiNTBfMl8wNjAwMDUzNTc1NTBDQzlENEU1Q0UxNkI2ODBDQTM1RTMyQTAyQzE0NDFCMzQyMDlBMUFGRDlBRDY2RjQyQTgwQzE2ODJBM0NBQjI0NzA0NDdERTY5RjJGQzREN0MzOThFNjlDRjZGIiwidG9rZW4iOiI5NTQzNTIxNzQ1Mzg0NTgzMDA0NjAzIiwidiI6IjEuMSJ9"
      paymentInfo.code = "999"
      #paymentInfo = card
      authorizenetapi.upsertPaymentProfile user, paymentInfo, false, (err, results) ->
        return next err, user, results

    # Create recurring subscription
    (user, results, next) ->
      skip = true
      return next null, user, null if skip
      console.log "Testing authorize.net recurring subscription api with user: ", user._id, user.clientId, user.name
      intervalUnit = "months"
      totalOccurrences = 6
      huntCatalog = {
        title: "Membership"
        huntNumber: "RBM"
        _id: "111111111"
      }
      purchaseItem = {
        amountTotal: 1.00
      }
      authorizenetapi.purchase_cc_reacurring user, intervalUnit, totalOccurrences, huntCatalog, purchaseItem, (err, results) ->
        return next err, user, results

  ], (err, user, results) ->
    console.log "Finished"
    if err
      console.log "Completed with error", err
      process.exit(1)
    else
      console.log "Completed with results: ", results
      process.exit(0)
