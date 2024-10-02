_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/update_purchase.coffee


USE_PROD_ENV = true
UPDATE_PURCHASE = false
RECALC_COMMISSIONS = false

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

  processPurchase = (purchase, done) ->
    huntCatalog = purchase.huntCatalogCopy[0]
    purchaseCount++

    if true
      return done null unless purchaseCount <= 1

    #Purchase.byId purchase._id, TENANT_ID, (err, purchase) ->
      #return done err if err
      #return done "Purchase not found for id: #{purchase._id}" unless purchase
    console.log "*****************Processing #{purchaseCount} of #{purchaseTotal}, purchaseId: #{purchase._id}, invoice: #{purchase.invoiceNumber}, title: #{huntCatalog.title}, price: $#{purchase.basePrice}, type: #{huntCatalog.type}"
    #console.log "DEBUG: Purchase: ", purchase
    if skipList.indexOf(purchase._id) > -1
      console.log "SKIPPING purchase from skip list!"
      return done null, null

    purchase_modified = false
    async.waterfall [
      #Initialize the purchase data to update
      (next) ->
        purchaseData = {}
        purchaseData._id = purchase._id
        return next null, purchaseData, purchase

      #Check and update purchase commission amounts
      (purchaseData, purchase, next) ->
        update_commissions = true
        return next null, purchaseData, purchase unless update_commissions
        return next null, purchaseData, purchase unless huntCatalog.type is "renewal_oss"
        total_rep_comp = 0
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep0 if purchase.rbo_commission_rep0
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep1 if purchase.rbo_commission_rep1
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep2 if purchase.rbo_commission_rep2
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep3 if purchase.rbo_commission_rep3
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep4 if purchase.rbo_commission_rep4
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep5 if purchase.rbo_commission_rep5
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep6 if purchase.rbo_commission_rep6
        total_rep_comp = total_rep_comp + purchase.rbo_commission_rep7 if purchase.rbo_commission_rep7
        total_rep_comp = total_rep_comp + purchase.rbo_commission_repOSSP if purchase.rbo_commission_repOSSP
        if total_rep_comp == 0
          OSS_RENEWAL_PER = 0.138866666666667
          purchaseData.commission = purchase.basePrice
          purchaseData.rbo_reps_commission = (purchase.basePrice * OSS_RENEWAL_PER).toFixed(2)
          purchase_modified = true
        else
          console.log "purchase.commission: #{purchase.commission}, purchase.rbo_reps_commission: #{purchase.rbo_reps_commission}"
          console.log "purchase total actual rep commissions assigned: #{total_rep_comp}"
          console.log "Alert: This purchase already has commissions specified.  skipping."
        return next null, purchaseData, purchase

      #Update qb_invoice_recorded
      (purchaseData, purchase, next) ->
        update_custom = false
        return next null, purchaseData, purchase unless update_custom
        if purchase.quickbooksInvoiced
          #console.log "DEBUG: purchase.quickbooksInvoiced: ", purchase.quickbooksInvoiced
          if purchase.qb_invoice_recorded isnt true
            purchaseData.qb_invoice_recorded = true
            purchase_modified = true
            #console.log "DEBUG: update qb_invoice_recorded to true"
        if purchase.quickbooksReconciled
          console.log "DEBUG: purchase.quickbooksReconciled: #{purchase.quickbooksReconciled}, purchase.qb_invoice_payment_reconciled: #{purchase.qb_invoice_payment_reconciled}, #{purchase.qb_invoice_payment_reconciled isnt purchase.quickbooksReconciled}"
          if purchase.qb_invoice_payment_reconciled isnt purchase.quickbooksReconciled
            purchaseData.qb_invoice_payment_reconciled = purchase.quickbooksReconciled
            purchase_modified = true
            #console.log "DEBUG: update qb_invoice_payment_reconciled to same date as quickbooksReconciled"

        return next null, purchaseData, purchase

      #Update the purchase
      (purchaseData, purchase, next) ->
        if purchase_modified
          console.log "Alert: about to update purchase with data: ", purchaseData
          if UPDATE_PURCHASE
            Purchase.upsert purchaseData, {upsert: false}, (err, purchase) ->
              console.log "Purchase.upsert() completed with err: ", err if err
              return next err if err
              #console.log "Purchase.upsert() completed successfully with rsp: ", purchase
              console.log "Purchase.upsert() completed successfully."
              return next null, purchase
          else
            console.log "UPDATE_PURCHASE = false, SKIPPING UPDATING THE PURCHASE."
            return next null, purchase
        else
          console.log "The purchase data was not modified.  Skipping Purchase.upsert()"
          return next null, purchase

      # Retrieve the user info
      (purchase, next) ->
        retrieve_user = true
        return next null, purchase, null unless retrieve_user
        return next "Missing userId" unless purchase.userId
        User.findById purchase.userId, internal: false, (err, user) ->
          return next err if err
          return next {error: "User not found"}, code: 500 unless user
          return next null, purchase, user

      # Retrieve the Outfitter info
      (purchase, user, next) ->
        retrieve_outfitter = true
        return next null, purchase, user, null unless retrieve_outfitter
        return next "Missing outfitter_userId" unless huntCatalog.outfitter_userId
        User.findById huntCatalog.outfitter_userId, internal: false, (err, outfitter) ->
          return next err if err
          return next {error: "Outfitter not found"}, code: 500 unless outfitter
          return next null, purchase, user, outfitter

      # Force Re-Calculate and Save Commissions
      (purchase, user, outfitter, next) ->
        return next null, purchase unless RECALC_COMMISSIONS
        console.log "Alert: about to recalc commissions on purchase..."
        if !UPDATE_PURCHASE
          console.log "UPDATE_PURCHASE = false, SKIPPING recalculating THE PURCHASE commissions"
          return next null, null
        else
          huntCatalogsCtrl.calculateCommissions user, outfitter, purchase, purchase.basePrice, (err, commResults) ->
            console.log "Error processing commissions for this purchase: ", err if err
            console.log "re-calculate commissions async called successfully: ", commResults
            return next err, purchase

    ], (err, results) ->
      console.log "ERROR: processPurchase failed with error: ", err if err
      return done err, results



  getPurchases = (cb) ->
    c_or = []
    c_or.push {commissionsPaid: null}
    c_or.push {commissionsPaid: {$exists: false}}
    conditions = {
      $and: [
        {tenantId: TENANT_ID}
        {"huntCatalogCopy.type": "renewal_oss"}
        {$or: c_or}
        #"commissionsPaid" : "2020-09-10T06:00:00.000Z"
      ]
    }
    #conditions = {
    #  $and: [
    #    {tenantId: TENANT_ID}
    #    {"createdAt" : {$gte: "2020-01-01T00:00:00.000Z"}}
    #    #{_id: "5fb5c6afcbd0d42ed44dcf26"} #test purchase in production
    #  ]
    #}

    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    Purchase.find(conditions).lean().exec (err, results) ->
      cb err, results


  async.waterfall [
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
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done...pause to allow re-calc commissions async calls to finish before terminating the process"
      setTimeout ->
        console.log 'Terminating process.'
        process.exit(0)
      , 5000



