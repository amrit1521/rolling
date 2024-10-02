_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/reps_commissions.coffee


USE_PROD_ENV = true
INCLUDE_COMPANY_OVERRIDES = false
REPORTING_THRESHOLD = 0 #599

if USE_PROD_ENV
  TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO
else
  TENANT_ID = "5bd75eec2ee0370c43bc3ec7" #TEST

config.resolve (
  logger
  Secure
  User
  Purchase
  huntCatalogs
) ->

  huntCatalogsCtrl = huntCatalogs
  purchaseTotal = 0
  purchaseCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "58d328e8fe41db1317c946e9,58d328e8fe41db1317c946e9"
  skipList = ""

  usersIndex = {}
  commissionsTotal = {}

  recordCommission = (purchase, commKey, repIdKey) ->
    commAmount = 0
    commAmount = purchase[commKey] if purchase[commKey]
    repId = purchase[repIdKey].toString() if purchase[repIdKey]
    if !commissionsTotal[repId]
      commissionsTotal[repId] = commAmount
    else
      commissionsTotal[repId] = commissionsTotal[repId] + commAmount
    #console.log "#{repId} Commissions Amount: ", commAmount


  processPurchase = (purchase, done) ->
    huntCatalog = purchase.huntCatalogCopy[0]
    purchaseCount++

    if false
      return done null unless purchaseCount <= 10

    console.log "*****************Processing #{purchaseCount} of #{purchaseTotal}, purchaseId: #{purchase._id}, invoice: #{purchase.invoiceNumber}, title: #{huntCatalog.title}, price: $#{purchase.basePrice}, type: #{huntCatalog.type}"
    #console.log "DEBUG: Purchase: ", purchase
    if skipList.indexOf(purchase._id) > -1
      console.log "SKIPPING purchase from skip list!"
      return done null, null

    recordCommission(purchase, "rbo_commission_rep0", "rbo_rep0")
    recordCommission(purchase, "rbo_commission_rep1", "rbo_rep1")
    recordCommission(purchase, "rbo_commission_rep2", "rbo_rep2")
    recordCommission(purchase, "rbo_commission_rep3", "rbo_rep3")
    recordCommission(purchase, "rbo_commission_rep4", "rbo_rep4")
    recordCommission(purchase, "rbo_commission_rep5", "rbo_rep5")
    recordCommission(purchase, "rbo_commission_rep6", "rbo_rep6")
    recordCommission(purchase, "rbo_commission_rep7", "rbo_rep7")
    recordCommission(purchase, "rbo_commission_repOSSP", "rbo_repOSSP")
    if INCLUDE_COMPANY_OVERRIDES
      recordCommission(purchase, "rbo_commission_rbo1", "rbo_rbo1")
      recordCommission(purchase, "rbo_commission_rbo2", "rbo_rbo2")
      recordCommission(purchase, "rbo_commission_rbo3", "rbo_rbo3")
      recordCommission(purchase, "rbo_commission_rbo4", "rbo_rbo4")

    #console.log "DEBUG ERROR MISSING COMMISSIONS PAID DATE" unless purchase.commissionsPaid
    #console.log "DEBUG: purchase.commissionsPaid: ", purchase.commissionsPaid

    return done null, purchase



  getPurchases = (cb) ->
    #All comm paid last year
    conditions = {
      $and: [
        {tenantId: TENANT_ID}
        {"createdAt" : {$gte: "2021-01-01T00:00:00.000Z"}}
        {"createdAt" : {$lte: "2021-12-31T23:59:59.000Z"}}
        {"commissionsPaid": {$gte: "2021-01-01T00:00:00.000Z"}} #comm paid is not null
      ]
    }

    #commissions leaderboard last month
    #conditions = {
    #  $and: [
    #    {tenantId: TENANT_ID}
    #    {"createdAt" : {$gte: "2021-01-01T00:00:00.000Z"}}
    #    {"createdAt" : {$lte: "2021-01-31T23:59:59.000Z"}}
    #    #{"commissionsPaid": {$gte: "2020-01-01T00:00:00.000Z"}} #comm paid is not null
    #  ]
    #}

    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    Purchase.find(conditions).lean().exec (err, results) ->
      cb err, results


  async.waterfall [
    # Create Users index
    (next) ->
      #return next null #skip for now until we need names DEBUG
      User.findByTenant TENANT_ID, {}, (err, users) ->
        return next err if err
        for user in users
          usersIndex[user._id.toString()] = {
            name: user.name
            clientId: user.clientId
          }
        return next null

    # Get purchases
    (next) ->
      purchaseId = process.argv[2]
      if purchaseId
        Purchase.byId purchaseId, TENANT_ID, next
      else
        getPurchases(next)

    # For each purchase, do stuff
    (purchases, next) ->
      purchases = [purchases] unless typeIsArray purchases
      console.log "found #{purchases.length} purchases"
      purchaseTotal = purchases.length
      async.mapSeries purchases, processPurchase, (err, results) ->
        return next err, results

  ], (err, results) ->
    console.log "Finished"
    console.log "commissionsTotal: ", commissionsTotal
    for userId in Object.keys(commissionsTotal)
      #console.log "#{userId}: ", commissionsTotal[userId].toFixed(2) if commissionsTotal[userId] > REPORTING_THRESHOLD
      console.log "#{userId}, #{usersIndex[userId].clientId}, #{usersIndex[userId].name}: ", commissionsTotal[userId].toFixed(2) if commissionsTotal[userId] > REPORTING_THRESHOLD

    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done...pause to allow async calls to finish before terminating the process"
      setTimeout ->
        console.log 'Terminating process.'
        process.exit(0)
      , 5000



