_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/quick_test.coffee


config.resolve (
  logger
  Secure
  User
  Purchase
  huntCatalogs
) ->


  clientIds = ["xxx","yyy"]

  getValidStamp = (params, cb) ->
    Secure.encrypt_rads_stamp params, (err, eStamp) ->
      return cb err, eStamp




  async.waterfall [

# Test eStamp
    (next) ->
      return next null
      console.log 'Testing encrypt stamp for API'

      params = {p1: "p1", p2: "p2", timestamp: 1560447205822}
      getValidStamp params, (err, eStamp) ->
        console.log "eStamp results: ", err, eStamp
        return next err if err

        stamp = Secure.validate_rads_stamp eStamp
        console.log "decrypted eStamp: ", stamp

        return next err

    (next) ->
      #return next null
      console.log 'Testing mail chimp email receipts'
      huntCatalogsCtrl = huntCatalogs
      #local test enviroment
      purchaseId = "5d9f848c7ef41dea973cf46a"
      tenantId = "5cbdfc4ce3c94508ef674358"
      #production enviroment
      #purchaseId = "5da7475d8c768cabed75d6a2"
      #tenantId = "5684a2fc68e9aa863e7bf182"
      purchase = ""
      user = ""
      outfitter = ""
      huntCatalog = ""

      Purchase.byId purchaseId, tenantId, (err, purchase) ->
        return next err if err
        return next "Purchase not found for tenantId: #{tenantId}, purchaseId: #{purchaseId}" unless purchase
        tenantId = purchase.tenantId
        huntCatalog = purchase.huntCatalogCopy[0]
        User.findById purchase.userId, (err, user) ->
          return next err if err
          User.findById huntCatalog.outfitter_userId, (err, outfitter) ->
            return next err if err
            huntCatalogsCtrl.sendEmailPurchaseNotifications_PerCartEntry user, outfitter, huntCatalog, purchaseId, tenantId
            finish = () ->
              console.log "wait for async call over, finishing test."
              return next null
            setTimeout finish, 6000

  ], (err) ->

    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
