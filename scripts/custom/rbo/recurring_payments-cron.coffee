_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:
#   ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/recurring_payments-cron.coffee false false 1/15/2019
#   ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/recurring_payments-cron.coffee false false today 2>&1 | tee /Users/scottwallace/repos/GMT/gotmytag/tmp/recurring_payments-cron.log
#   coffee /var/www/gotmytag/scripts/custom/rbo/recurring_payments-cron.coffee false false today 2>&1 | tee /home/ubuntu/tmp/recurring_payments-cron.log


USE_PROD_ENV = true #debug
if USE_PROD_ENV
  BASE_TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO
else
  BASE_TENANT_ID = "5bd75eec2ee0370c43bc3ec7" #TEST


HARD_SKIP = false
HARD_SKIP_AFTER = 1

SEND_CRON_EMAIL = true

log_message_string = ""
log = (msg, capture) ->
  console.log msg
  return unless capture
  log_message_string = "#{log_message_string}\n\t...........#{msg}"

#ARG 1
RUN_AUTHORIZE_NET = false
RUN_AUTHORIZE_NET = true if process.argv?.length > 2 and process.argv[2] is "true"
log "RUN_AUTHORIZE_NET: #{RUN_AUTHORIZE_NET}", true

#ARG 2
SEND_EMAILS = false
SEND_EMAILS = true if process.argv?.length > 3 and process.argv[3] is "true"
log "SEND_EMAILS: #{SEND_EMAILS}", true

#ARG 3
RUN_DATE = moment()
RUN_DATE = new Date(process.argv[4]) if process.argv?.length > 4 and process.argv[4] isnt 'today'
runDate = moment(RUN_DATE)
log "runDate: #{runDate.format('MM/DD/YYYY')}", true
retryDate = moment(RUN_DATE).subtract(1, 'months')
log "retryDate: #{retryDate.format('MM/DD/YYYY')}", true

config.resolve (
  api_rbo
  User
  Reminder
  Message
  mailchimpapi
  Tenant
  Purchase
  purchases
  OSSTenantId
  OSSTestTenantId
) ->

  #Set main scope
  purchase_ctrl = purchases
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
  auto_pay_purchases = []
  auto_pay_retry_purchases = []
  auto_pay_purchases_count = 0
  auto_pay_retry_purchases_count = 0

  sendCronEmail = (success, log_message_string, cb) ->
    return cb null, null if !SEND_CRON_EMAIL
    if success
      log_message_string = "recurring_payments-cron processed successfully: #{log_message_string}"
    else
      log_message_string = "recurring_payments-cron FAILED WITH ERROR: #{log_message_string}"
    template_name = "Server Message"
    subject = "Recurring Payments Processed"
    mandrilEmails = []
    to = {
      email: "scott@rollingbonesoutfitters.com"
      type: "to"
    }
    mandrilEmails.push to if to
    payload = {
      source: "recurring_payments-cron.coffee"
      message: log_message_string
    }
    Tenant.findById BASE_TENANT_ID, (err, b_tenant) ->
      console.log "ERROR getting base tenenat to send cron summary email: ", err if err or !b_tenant
      mailchimpapi.sendEmail b_tenant, template_name, subject, mandrilEmails, payload, null, null, null, false, cb



  sendAutoPaymentFailedEmail = (purchase, user, err, cb) =>
    getParentRep user, (err, parentRep) =>
      payload = {
        user_email: ""
        user_name: ""
        parent_name: ""
        parent_email: ""
        parent_phone: ""
        cc_last4: "xxxx"
        purchase_title: ""
      }
      payload.user_email = user.email if user.email
      payload.user_name = user.name if user.name
      payload.parent_name = parentRep.name if parentRep?.name
      payload.parent_email = parentRep.email if parentRep?.email
      payload.parent_phone = parentRep.phone_cell if parentRep?.phone_cell
      payload.next_payment_date = moment(purchase.next_payment_date).format('MM/DD/YYYY') if user.next_payment_date?

      huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?.length
      payload.purchase_title = huntCatalogCopy.title if huntCatalogCopy

      ccRepOnEmail = false  #Not sure if we want to cc the rep on failed payments yet or not.

      Tenant.findById purchase.tenantId, (err, t_tenant) =>
        if purchase.status is "auto-pay-monthly" or purchase.status is 'auto-pay-yearly'
          template_name = "Auto Payment Failed Notice"
          subject = "#{t_tenant.name} Auto Payment Failed Notice"
        else if purchase.status is "auto-pay-monthly-retry" or purchase.status is 'auto-pay-yearly-retry'
          template_name = "Auto Payment Failed Notice"
          subject = "#{t_tenant.name} Auto Payment Failed 2nd Notice"
        else
          return cb "Invalid status encountered: ", purchase.status

        #Special case, override with OSS templates
        if huntCatalogCopy.type is "renewal_oss" or huntCatalogCopy.type is "oss"
          template_name = "OSS Auto Payment Failed Notice"
          if purchase.status is "auto-pay-monthly-retry" or purchase.status is 'auto-pay-yearly-retry'
            subject = "OSS Auto Payment Failed 2nd Notice"
          else
            subject = "OSS Auto Payment Failed Notice"

        mandrilEmails = []
        if user?.email
          to_user = {
            email: user.email
            type: "to"
          }
          to_user.name = user.name if user.name
          mandrilEmails.push to_user if to_user

        if parentRep?.email
          cc_user = {
            email: parentRep.email
            type: "cc"
          }
          cc_user.name = parentRep.name if parentRep.name
          mandrilEmails.push cc_user if cc_user and ccRepOnEmail

        if SEND_EMAILS
          mailchimpapi.sendEmail t_tenant, template_name, subject, mandrilEmails, payload, null, null, null, true, cb
          #return cb err, result  #Let sendEmail call cb().
        else
          console.log "Skipping email send.  SEND_EMAILS param is: ", SEND_EMAILS
          return cb err, null

  getParentRep = (tUser, cb) ->
    return cb null, tUser unless tUser?.parentId
    User.byId tUser.parentId, {}, (err, parent) ->
      return cb err if err
      return cb null, tUser unless parent
      if parent.isRep
        return cb null, parent
      else
        getParentRep(parent, cb)

  createPurchasePayload = (purchase, user, cb) ->
    payload = {}
    payload.body = {}
    payload.tenant = {}
    payload.tenant._id = purchase.tenantId
    payload.body.send_email_sync = true
    payload.body.user = user
    payload.body.originalPurchase = purchase
    huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?.length
    if huntCatalogCopy
      payload.body.originalPurchase.huntCatalog_title = huntCatalogCopy.title
      payload.body.originalPurchase.huntCatalog_outfitter_id = huntCatalogCopy.outfitter_userId
      payload.body.originalPurchase.huntCatalog_number = huntCatalogCopy.huntNumber
      payload.body.originalPurchase.huntCatalog_type = huntCatalogCopy.type

    payload.body.payment = {}
    now = new Date()
    payment = {}
    payment.auto_payment = true
    payment.specific_type = "auto-pay-card"
    payment.name = user.name
    payment.createdAt = now
    payment.paidOn = now
    payment.amount = purchase.next_payment_amount
    payload.body.payment = payment

    return cb null, payload

  processAutoPayment = (purchase, done) ->
    err = null
    result = null
    User.findById purchase.userId, (err, user) =>
      return err if err
      return "User not found for auto pay purchase id: #{purchase._id}, userId: #{purchase.userId}" unless user
      if purchase.status.indexOf("retry") is -1
        auto_pay_purchases_count++
        log "****************************************Processing #{auto_pay_purchases_count} of #{auto_pay_purchases.length} auto payment for purchaseId: #{purchase._id}, item: #{purchase.huntCatalogCopy[0].title}", true
        log "User: #{user.first_name} #{user.last_name}, #{user.clientId}, userId: #{user._id}", true
      else
        auto_pay_retry_purchases_count++
        log "****************************************Processing #{auto_pay_retry_purchases_count} of #{auto_pay_retry_purchases.length} RETRY auto payment for #{purchase._id}, #{purchase.huntCatalogCopy[0].title}, #{user.first_name}, #{user.last_name}, #{user.clientId}, #{user._id}", true
      createPurchasePayload purchase, user, (err, payload) =>
        if HARD_SKIP and auto_pay_purchases_count > HARD_SKIP_AFTER
          console.log "SKIPPING processing after count: ", HARD_SKIP_AFTER
          return done null, payload
        return done err if err
        if RUN_AUTHORIZE_NET
          purchase_ctrl.recordPayment payload, (err, results) =>
            #recordPayment actually runs the payment through authorize.net
            if err
              pData = {
                _id: purchase._id
              }
              if purchase.status.indexOf('retry') > -1
                pData.status = "cc_failed"
              else
                pData.status = purchase.status + "-retry"
              console.log "Error Occurred: ", err
              console.log "Updating purchase auto pay status to '#{pData.status}'"
              Purchase.upsert pData, {}, (err2, result) =>
                return done err2 if err2
                console.log "Error updating purchase status: ", err2 if err2
                sendAutoPaymentFailedEmail purchase, user, err, (err3, result) ->
                  console.log "Error sending email: ", err3 if err3
                  return done err3, null
            else
              console.log "Successfully ran and recorded auto payment. Payload: $#{payload.body.payment.amount}, #{payload.body.originalPurchase.huntCatalog_title}"
              return done null, results
        else
          console.log "RUN_AUTHORIZE_NET = false, skipping running credit card processing.  Payload: $#{payload.body.payment.amount}, #{payload.body.originalPurchase.huntCatalog_title}"
          return done null, payload


  isRepOrMembershipSubscription = (tPurchase) ->
    if tPurchase.huntCatalogCopy[0].type is "rep" or tPurchase.huntCatalogCopy[0].type is "membership"
      console.log "Skipping rep and membership subscription.  Those are handled in a different cron task."
      return true
    else
      return false

  processTenant = (tenant, done) ->
    log ""
    log ""
    log "*****Retrieving auto recurring payments for tenant: #{tenant.name}: #{runDate.format('MM/DD/YYYY')}", true
    #CHECK SKIP OSS TENANT
    if tenant._id?.toString() is OSSTenantId or tenant._id?.toString() is OSSTestTenantId
      log "SKIPPING THE OSS TENANT, because recurring payments for OSS sales are handled in RBO's tenant for now, and don't want to double charge them", true
      return done null, {tenant: tenant} #allow other tenants to run

    #Reset counts
    auto_pay_purchases = []
    auto_pay_retry_purchases = []
    auto_pay_purchases_count = 0
    auto_pay_retry_purchases_count = 0

    async.waterfall [

      # Get monthly auto payments
      (next) ->
        Purchase.byStatusNextPaymentDate 'auto-pay-monthly', runDate, tenant._id, (err, tauto_pay_purchases) ->
          return next err if err
          for p in tauto_pay_purchases
            continue if isRepOrMembershipSubscription(p)
            auto_pay_purchases.push p
          log "Found #{tauto_pay_purchases.length} monthly auto payments next payment date set for #{runDate.format('MM/DD/YYYY')}", true
          return next err

      # Get yearly auto payments
      (next) ->
        Purchase.byStatusNextPaymentDate 'auto-pay-yearly', runDate, tenant._id, (err, tauto_pay_yearly_purchases) ->
          return next err if err
          for p in tauto_pay_yearly_purchases
            continue if isRepOrMembershipSubscription(p)
            auto_pay_purchases.push p
          log "Found #{tauto_pay_yearly_purchases.length} yearly auto payments next payment date set for #{runDate.format('MM/DD/YYYY')}", true
          return next err

      # Get monthly auto payments retry
      (next) ->
        Purchase.byStatusNextPaymentDate 'auto-pay-monthly-retry', retryDate, tenant._id, (err, tauto_pay_purchases_retry) ->
          return next err if err
          for p in tauto_pay_purchases_retry
            continue if isRepOrMembershipSubscription(p)
            auto_pay_retry_purchases.push p
          log "Found #{tauto_pay_purchases_retry.length} retry monthly auto payments next payment date set for #{retryDate.format('MM/DD/YYYY')}", true
          return next err

      # Get yearly auto payments retry
      (next) ->
        Purchase.byStatusNextPaymentDate 'auto-pay-yearly-retry', retryDate, tenant._id, (err, tauto_pay_yearly_purchases_retry) ->
          return next err if err
          for p in tauto_pay_yearly_purchases_retry
            continue if isRepOrMembershipSubscription(p)
            auto_pay_retry_purchases.push p
          log "Found #{tauto_pay_yearly_purchases_retry.length} retry yearly auto payments next payment date set for #{retryDate.format('MM/DD/YYYY')}", true
          return next err

      # Process auto payments
      (next) ->
        async.mapSeries auto_pay_purchases, processAutoPayment, (err, results) ->
          log ""
          return next err

      # Process retry auto payments
      (next) ->
        async.mapSeries auto_pay_retry_purchases, processAutoPayment, (err, results) ->
          log ""
          return next err

    ], (err) ->
      success = true
      result = {
        err: null,
        tenant: tenant
      }
      if err
        console.error "Found an error while processing tenant: #{tenant.name}, existing.", err
        log "Found an error while processing tenant: #{tenant.name}, existing. #{err}", true
        success = false
      if success
        log "#{tenant.name} Successfully processed #{auto_pay_purchases_count} auto payments.", true
        log "#{tenant.name} Successfully processed #{auto_pay_retry_purchases_count} retry failed auto payments.", true

      #Always return a successful result to allow the other tenants to run.  Then check for errors afterward.
      log "#{moment().format('MM/DD/YYYY, h:mm:ss a')}", true
      log "*****Finished running recurring payments for tenant : #{tenant.name}.", true
      return done null, result

  #MAIN LOGIC
  log "Starting recurring_payments script: #{moment().format('MM/DD/YYYY, h:mm:ss a')}", true
  Tenant.all "active", (err, tenants) ->
    console.log "ERROR getting tenants: ", err if err or !tenants
    Tenant.findById BASE_TENANT_ID, (err, b_tenant) ->
      console.log "ERROR getting base tenant: ", err if err or !b_tenant
      hardCode1Tenant = false
      tenants = [b_tenant] if hardCode1Tenant

      async.mapSeries tenants, processTenant, (err, results) ->
        success = true
        log ""
        log ""
        log "Finished running recurring_payments-cron script.", true
        log "#{moment().format('MM/DD/YYYY, h:mm:ss a')}", true

        if err
          console.error "processTenant() failed with error: ", err
          log "processTenant() failed with error: #{err}", true
          success = false
        else
          for result in results
            if result.err
              console.error "Processing tenant #{result.tenant.name} failed with error: ", result.err
              log "Processing tenant #{result.tenant.name} failed with error: #{err}", true
              success = false

        if success
          log "Successfully ran recurring payments script without errors.", true
          sendCronEmail success, log_message_string, (err, results) ->
            console.log "Error sending cron email: ", err if err
            process.exit(0)
        else
          sendCronEmail success, log_message_string, (err, results) ->
            console.log "Error sending cron email: ", err if err
            process.exit(1)
