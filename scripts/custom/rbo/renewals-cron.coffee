_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:
#   ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/renewals-cron.coffee false false false all 1/15/2019
#   ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/renewals-cron.coffee false false false all today 2>&1 | tee /Users/scottwallace/repos/GMT/gotmytag/tmp/renewals-cron.log
#   coffee /var/www/gotmytag/scripts/custom/rbo/renewals-cron.coffee false false false all today 2>&1 | tee /home/ubuntu/tmp/renewals-cron.log


USE_PROD_ENV = true
if USE_PROD_ENV
  TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO
  DEFAULT_OUTFITTER_ID = "595bb705e00d2a8ff5f09800" #Rolling Bones Outfitters SD100
else
  TENANT_ID = "5bd75eec2ee0370c43bc3ec7" #TEST
  DEFAULT_OUTFITTER_ID = "5bd9e98083fdcc04e3c0a638"


HARD_SKIP = false
HARD_SKIP_AFTER = 1


log_message_string = ""
log = (msg, capture) ->
  console.log msg
  return unless capture
  log_message_string = "#{log_message_string}\n\t...........#{msg}"

#ARG 1
RUN_AUTHORIZE_NET = false
RUN_AUTHORIZE_NET = true if process.argv?.length > 1 and process.argv[2] is "true"
log "RUN_AUTHORIZE_NET: #{RUN_AUTHORIZE_NET}", true

#ARG 2
SEND_EMAILS = false
SEND_EMAILS = true if process.argv?.length > 2 and process.argv[3] is "true"
log "SEND_EMAILS: #{SEND_EMAILS}", true

#ARG 3
UPDATE_RADS = false
UPDATE_RADS = true if process.argv?.length > 3 and process.argv[4] is "true"
log "UPDATE_RADS: #{UPDATE_RADS}", true

#ARG 4
TYPE_TO_SEND = "all"
TYPE_TO_SEND = process.argv[5] if process.argv?.length > 4
log "TYPE_TO_SEND: #{TYPE_TO_SEND}", true


#ARG 5
RUN_DATE = moment()
RUN_DATE = new Date(process.argv[6]) if process.argv?.length > 5 and process.argv[6] isnt 'today'
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
  api_rbo_rrads
) ->

  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  memberships_expired = []
  memberships_retry = []
  memberships_upcoming = []
  memberships_expired_count = 0
  memberships_retry_count = 0
  memberships_upcoming_count = 0

  memberships_renewals = []
  memberships_success = []
  memberships_failed = []

  reps_renewals = []
  reps_retry = []
  reps_success = []
  reps_failed = []
  reps_renewals_count = 0
  reps_retry_count = 0

  total_email_notifications = 0

  skipList = "xxx,yyy"
  skipList = ""

  tenant = null

  sendCronEmail = (success, log_message_string, cb) ->
    if success
      log_message_string = "renewals-cron processed successfully: #{log_message_string}"
    else
      log_message_string = "renewals-cron FAILED WITH ERROR: #{log_message_string}"
    template_name = "Server Message"
    subject = "Renewals Processed"
    mandrilEmails = []
    to = {
      email: "scott@rollingbonesoutfitters.com"
      type: "to"
    }
    mandrilEmails.push to if to
    payload = {
      source: "renewals-cron.coffee"
      message: log_message_string
    }
    #return cb null, null #don't send cron finished email for now #debug
    mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, payload, null, null, null, false, cb

  log "Starting renewals script: #{moment().format('MM/DD/YYYY, h:mm:ss a')}", true
  log "Retrieving auto recurring renewal subscriptions for: #{runDate.format('MM/DD/YYYY')}", true
  #The following are variables to be set because can't seem to be able to set and pass them through mapSeries?
  users = []

  updateUserInRRads = (user) ->
    req = {
      params: {}
    }
    req.params.tenantId = user.tenantId
    req.params._id = user._id
    api_rbo_rrads.user_upsert_rads req, (err, result) ->
      console.log "Error: Failed to update user is RRADS: ", err if err
      return

  sendRenewalFailedEmail = (user, type, rsp, cb) =>
    getParentRep user, (err, parentRep) =>
      payload = {
        user_email: ""
        user_name: ""
        parent_name: ""
        parent_email: ""
        parent_phone: ""
        cc_last4: "xxxx"
        memberExpires: ""
        repExpires: ""
      }
      payload.user_email = user.email if user.email
      payload.user_name = user.name if user.name
      payload.parent_name = parentRep.name if parentRep?.name
      payload.parent_email = parentRep.email if parentRep?.email
      payload.parent_phone = parentRep.phone_cell if parentRep?.phone_cell
      payload.memberExpires = moment(user.memberExpires).format('MM/DD/YYYY') if user.memberExpires?
      payload.repExpires = moment(user.repExpires).format('MM/DD/YYYY') if user.repExpires?

      ccRepOnEmail = true

      if type is "renewal_rep"
        template_name = "Specialist Renewal Retry Notice"
        subject = "Rolling Bones Adventure Advisor Renewal Retry Notice"
        ccRepOnEmail = false #Don't cc the rep on the first failed notice
      else if type is "renewal_rep_retry"
        template_name = "Specialist Renewal Failed Notice"
        subject = "Rolling Bones Adventure Advisor Renewal Failed Notice"
      else if type is "upcoming_memberships_expire"
        template_name = "Membership Notice"
        subject = "Rolling Bones Membership Renewal Notice"
        if user.memberStatus is "auto-renew-yearly"
          payload.auto_renew = true
        else
          payload.auto_renew = false
      else if type is "membership_expired"
        template_name = "Membership Expired Notice"
        subject = "Rolling Bones Membership Expired Notice"
      else if type is "renewal_membership"
        template_name = "Membership Renewal Retry Notice"
        subject = "Rolling Bones Adventure Membership Renewal Retry Notice"
        ccRepOnEmail = false #Don't cc the rep on the first failed notice
      else if type is "renewal_membership_retry"
        template_name = "Membership Renewal Failed Notice"
        subject = "Rolling Bones Adventure Membership Renewal Failed Notice"
        if user.memberType?.toLowerCase() is "platinum"
          template_name = "Platinum Membership Notice"
        if user.memberType?.toLowerCase() is "silver"
          template_name = "Silver Membership Notice"
      else
        return cb "Invalid type encountered: ", type

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
        mailchimpapi.sendEmail null, template_name, subject, mandrilEmails, payload, null, null, null, true, cb
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

  createPurchasePayload = (type, user, cb) ->
    payload = {}
    class_name = type
    listing_title = ""
    catalog_id = ""
    amount = 0
    rep_amount = 0
    if type is "renewal_rep" or type is "renewal_rep_retry"
      listing_title = "Adventure Advisor Renewal"
      catalog_id = "FSHSR"
      amount = 25
      rep_amount = 0
      class_name = "renewal_rep"
    else if type is "renewal_membership" or type is "renewal_membership_retry"
      if user.memberType?.toLowerCase() is "platinum"
        amount = 500
        rep_amount = 100
        listing_title = "Rolling Bones Platinum Membership Renewal"
        catalog_id = "RBRBOPR"
        class_name = "renewal_membership_platinum"
      else if user.memberType?.toLowerCase() is "silver"
        amount = 50
        rep_amount = 20
        listing_title = "Rolling Bones Silver Membership Renewal"
        catalog_id = "RBRBOSR"
        class_name = "renewal_membership_silver"
      else
        amount = 150
        rep_amount = 50
        listing_title = "Rolling Bones Membership Renewal"
        catalog_id = "RBMR"
        class_name = "renewal_membership"
    else
      return cb "Error: invalid type: #{type}"

    payload.tenantId = user.tenantId
    payload.clientId = user.clientId
    payload.payment_method = "card"
    payload.fullName = user.name
    payload.nameOnAccount = "n/a"
    payload.address1 = "n/a"
    payload.zip = "n/a"
    payload.country = "n/a"
    payload.state = "n/a"
    payload.city = "n/a"

    payload.cart = {
      renewal_only: true
      'price_todays_payment': amount
      'price_total': amount
      'price_processing_fee': 0
      'price_shipping': 0
      'price_tags_licenses': 0
      'price_options': 0
      'price_sales_tax': 0
      shopping_cart_entries: []
    }
    pricing_info = {
      base_price: amount
      price_options: 0
      total_price: amount
      minimum_payment: amount
      price_todays_payment: amount
      price_shipping: 0
      price_processing_fee: 0
      price_sales_tax: 0
      sales_tax_percentage: 0
      price_tags_licenses: 0
      months_count: 0
    }
    payload.cart.pricing_info = pricing_info

    listing = {
      class_name: class_name
      type: class_name
      catalog_id: catalog_id
      title: listing_title
      status: "available"
      run_special: false
      price_total: amount
      price_non_commissionable: 0
      price_member: amount
      price_non_member: amount
      price_processing_fee: 0
      commission_rbo: amount
      commission_rep: rep_amount
      price_description: ""
      description: listing_title
      created_at: new Date()
      updated_at: new Date()
    }
    listing.outfitter = {
      mongo_id: DEFAULT_OUTFITTER_ID
    }
    payload.cart.listing = listing
    cartEntry = {
      'price_todays_payment': amount
      'price_total': amount,
      'price_processing_fee': 0
      'price_shipping': 0
      'price_tags_licenses': 0
      'price_options': 0
      'price_sales_tax': 0
      notes: ""
      shopping_cart_entry_options: []
      quantity: 1
      pricing_info_hash: pricing_info
      listing: listing
    }
    payload.cart.shopping_cart_entries.push cartEntry
    payload.user = {
      email: user.email
      phone_number: ""
      _id: user._id
      clientId: user.clientId
    }
    return cb null, payload

  processRepRenewal = (user, done) ->
    type = "renewal_rep" #for some reason can't pass in type as a param in map.series call
    err = null
    result = null
    reps_renewals_count++
    log "****************************************Processing #{reps_renewals_count} of #{reps_renewals.length} rep renewal for #{user.first_name}, #{user.last_name}, #{user.clientId}, #{user._id}", true
    createPurchasePayload "renewal_rep", user, (err, payload) =>
      if user.repStatus isnt "auto-renew-monthly"
        #TODO: TEST THIS, incase the rep has next payment but cancelled status
        console.log "SKIPPING processing this user.  Invalid user rep status encountered: ", user.repStatus
        return done null, payload
      if HARD_SKIP and reps_renewals_count > HARD_SKIP_AFTER
        console.log "SKIPPING processing after user count: ", HARD_SKIP_AFTER
        return done null, payload
      return done err if err
      if RUN_AUTHORIZE_NET
        api_rbo.purchase_create3_direct payload, (err, results) =>
          if err
            console.log "Error Occurred: ", err
            console.log "Updating rep status to 'auto-renew-retry' to try once more next month."
            userData = {
              _id: user._id
              repStatus: "auto-renew-retry"
            }
            User.upsert userData, {}, (err2, user) =>
              updateUserInRRads(user) unless err2
              console.log "Error updating user rep status: ", err2 if err2
              sendRenewalFailedEmail user, type, err, (err3, result) ->
                console.log "Error sending email: ", err3 if err3
                return done err3, null
          else
            console.log "Successfully ran rep renewal. Payload: $", payload.cart.price_total, payload.cart.listing.type, payload.cart.listing.title
            return done null, results unless UPDATE_RADS
            rep_next_payment = moment(user.rep_next_payment).add(1, 'months')
            console.log "Updating rep_next_payment to next month. ", rep_next_payment.format('MM/DD/YYYY')
            userData = {
              _id: user._id
              rep_next_payment: rep_next_payment
            }
            User.upsert userData, {}, (err2, user) =>
              updateUserInRRads(user) unless err2
              console.log "Error updating user rep next payment date: ", err2 if err2
              return done err2, results
      else
        console.log "RUN_AUTHORIZE_NET = false, skipping running credit card processing.  Payload: ", payload.cart.price_total, payload.cart.listing.type, payload.cart.listing.title
        return done null, payload

  processRepRenewalRetry = (user, done) ->
    type = "renewal_rep_retry" #for some reason can't pass in type as a param in map.series call
    err = null
    result = null
    reps_retry_count++
    log "****************************************Processing #{reps_retry_count} of #{reps_retry.length} rep renewal retry for #{user.first_name}, #{user.last_name}, #{user.clientId}, #{user._id}", true
    createPurchasePayload "renewal_rep", user, (err, payload) =>
      if user.repStatus isnt "auto-renew-retry"
        #TODO: TEST THIS, incase the rep has next payment but cancelled status
        console.log "SKIPPING processing this user.  Invalid user rep status encountered: ", user.repStatus
        return done null, payload
      if HARD_SKIP and reps_retry_count > HARD_SKIP_AFTER
        console.log "SKIPPING processing after user count: ", HARD_SKIP_AFTER
        return done null, payload
      return done err if err
      if RUN_AUTHORIZE_NET
        api_rbo.purchase_create3_direct payload, (err, results) =>
          if err
            console.log "Error Occurred: ", err
            console.log "Updating rep status to 'cc_failed', and marking rep as expired."
            userData = {
              _id: user._id
              repStatus: "cc_failed"
              repExpires: new Date()
              isRep: false
            }
            User.upsert userData, {}, (err2, user) =>
              updateUserInRRads(user) unless err2
              console.log "Error updating user rep status: ", err2 if err2
              sendRenewalFailedEmail user, type, err, (err3, result) ->
                console.log "Error sending email: ", err3 if err3
                return done err3, null
          else
            return done null, results unless UPDATE_RADS
            rep_next_payment = moment(user.rep_next_payment).add(2, 'months')
            console.log "Successfully ran rep renewal retry, updating rep_next_payment to next month. ", rep_next_payment.format('MM/DD/YYYY')
            userData = {
              _id: user._id
              rep_next_payment: rep_next_payment
              repStatus: "auto-renew-monthly"
              repExpires: ""
            }
            User.upsert userData, {}, (err2, user) =>
              updateUserInRRads(user) unless err2
              console.log "Error updating user rep next payment date: ", err2 if err2
              return done err2, results
      else
        console.log "RUN_AUTHORIZE_NET = false, skipping running credit card processing.  Payload: $", payload.cart.price_total, payload.cart.listing.type, payload.cart.listing.title
        return done null, payload


  processMemberExpiring = (user, done) ->
    type = "renewal_membership" #for some reason can't pass in type as a param in map.series call
    err = null
    result = null
    memberships_expired_count++
    log "****************************************Processing #{memberships_expired_count} of #{memberships_expired.length} member expired for #{user.first_name}, #{user.last_name}, #{user.clientId}, #{user._id}", true
    if user.memberStatus is "auto-renew-yearly"
      createPurchasePayload type, user, (err, payload) =>
        return done err if err
        if HARD_SKIP and memberships_expired_count > HARD_SKIP_AFTER
          console.log "SKIPPING processing after user count: ", HARD_SKIP_AFTER
          return done null, payload
        if RUN_AUTHORIZE_NET
          api_rbo.purchase_create3_direct payload, (err, results) =>
            if err
              console.log "Error Occurred: ", err
              console.log "Updating member status to 'auto-renew-retry' to try once more next month."
              userData = {
                _id: user._id
                memberStatus: "auto-renew-retry"
              }
              User.upsert userData, {}, (err2, user) =>
                updateUserInRRads(user) unless err2
                console.log "Error updating user member status: ", err2 if err2
                sendRenewalFailedEmail user, type, err, (err3, result) ->
                  console.log "Error sending email: ", err3 if err3
                  return done err3, null
            else
              return done null, results unless UPDATE_RADS
              membership_next_expires = moment(user.memberExpires).add(1, 'years')
              console.log "Successfully ran membership renewal, updating expiration to next year. ", membership_next_expires.format('MM/DD/YYYY')
              userData = {
                _id: user._id
                memberExpires: membership_next_expires
              }
              User.upsert userData, {}, (err2, user) =>
                updateUserInRRads(user) unless err2
                console.log "Error updating user membership expires date: ", err2 if err2
                return done err2, results
        else
          console.log "RUN_AUTHORIZE_NET = false, skipping running credit card processing.  Payload: $", payload.cart.price_total, payload.cart.listing.type, payload.cart.listing.title
          return done null, payload
    else if user.memberStatus is "auto-renew-retry"
      #Skip processing this membership and let the processMemberRenewalRetry process it.
      return done null, null
    else
      #Expire their membership and send an email inviting them to sign up again.
      if HARD_SKIP and memberships_expired_count > HARD_SKIP_AFTER
        console.log "SKIPPING processing after user count: ", HARD_SKIP_AFTER
        return done null, null
      console.log "This membership is not on auto-renew and has expired. Updating membership expired date and isMember: false."
      userData = {
        _id: user._id
        memberStatus: "expired"
        isMember: false
      }
      User.upsert userData, {}, (err2, user) =>
        updateUserInRRads(user) unless err2
        console.log "Error updating user member status: ", err2 if err2
        sendRenewalFailedEmail user, "membership_expired", err, (err3, result) ->
          console.log "Error sending email: ", err3 if err3
          return done err3, null

  processMemberRenewalRetry = (user, done) ->
    type = "renewal_membership_retry" #for some reason can't pass in type as a param in map.series call
    err = null
    result = null
    memberships_retry_count++
    log "****************************************Processing #{memberships_retry_count} of #{memberships_retry.length} member auto renew retry for #{user.first_name}, #{user.last_name}, #{user.clientId}, #{user._id}", true
    createPurchasePayload type, user, (err, payload) =>
      return done err if err
      if HARD_SKIP and memberships_retry_count > HARD_SKIP_AFTER
        console.log "SKIPPING processing after user count: ", HARD_SKIP_AFTER
        return done null, payload
      if RUN_AUTHORIZE_NET
        api_rbo.purchase_create3_direct payload, (err, results) =>
          if err
            console.log "Error Occurred: ", err
            console.log "Updating member status to 'cc_failed', and marking membership as expired."
            userData = {
              _id: user._id
              memberStatus: "cc_failed"
              memberExpires: new Date()
              isMember: false
            }
            User.upsert userData, {}, (err2, user) =>
              updateUserInRRads(user) unless err2
              console.log "Error updating user member status: ", err2 if err2
              sendRenewalFailedEmail user, type, err, (err3, result) ->
                console.log "Error sending email: ", err3 if err3
                return done err3, null
          else
            return done null, results unless UPDATE_RADS
            membership_next_expires = moment(user.memberExpires).add(1, 'years')
            console.log "Successfully ran membership renewal retry, updating expiration to next year. ", membership_next_expires.format('MM/DD/YYYY')
            userData = {
              _id: user._id
              memberExpires: membership_next_expires
              memberStatus: "auto-renew-yearly"
            }
            User.upsert userData, {}, (err2, user) =>
              updateUserInRRads(user) unless err2
              console.log "Error updating user membership expires date: ", err2 if err2
              return done err2, results
      else
        console.log "RUN_AUTHORIZE_NET = false, skipping running credit card processing.  Payload: $", payload.cart.price_total, payload.cart.listing.type, payload.cart.listing.title
        return done null, payload

  processMembershipUpcomingExpire = (user, done) ->
    type = "upcoming_memberships_expire" #for some reason can't pass in type as a param in map.series call
    err = null
    result = null
    memberships_upcoming_count++
    log "****************************************Processing #{memberships_upcoming_count} of #{memberships_upcoming.length} upcoming expiring membership for #{user.first_name}, #{user.last_name}, #{user.clientId}, #{user._id}", true
    if HARD_SKIP and memberships_upcoming_count > HARD_SKIP_AFTER
      console.log "SKIPPING processing after user count: ", HARD_SKIP_AFTER
      return done null, null
    sendRenewalFailedEmail user, type, null, (err, result) ->
      return done err, result

  async.waterfall [

    #Retrieve the tenant
    (next) ->
      Tenant.findById TENANT_ID, (err, t_tenant) ->
        tenant = t_tenant if t_tenant?
        return next err

    # Get rep renewals
    (next) ->
      type = "renewal_rep"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      User.repRenewalsByDate runDate, TENANT_ID, (err, tReps_renewals) ->
        return next err if err
        reps_renewals = tReps_renewals
        log "Found #{reps_renewals.length} rep renewals on #{runDate.format('MM/DD/YYYY')}", true
        async.mapSeries reps_renewals, processRepRenewal, (err, results) ->
          log ""
          return next err


    # Get rep renewals retry
    (next) ->
      type = "renewal_rep_retry"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      User.repRenewalsByDate retryDate, TENANT_ID, (err, tReps_retry) ->
        return next err if err
        for user in tReps_retry
          if user.repStatus is "auto-renew-retry"
            reps_retry.push user
          #else, this rep doesn't get a retry, they are just expired.
        log "Found #{reps_retry.length} rep renewals retries for #{retryDate.format('MM/DD/YYYY')}", true
        async.mapSeries reps_retry, processRepRenewalRetry, (err, results) ->
          log ""
          return next err

    # Get expired memberships
    (next) ->
      type = "renewal_membership"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      User.membershipExpiredByDate runDate, TENANT_ID, (err, tMemberships_expired) ->
        return next err if err
        for user in tMemberships_expired
          if user.memberStatus isnt "auto-renew-retry"
            memberships_expired.push user
        log "Found #{memberships_expired.length} membership expire on #{runDate.format('MM/DD/YYYY')}", true
        async.mapSeries memberships_expired, processMemberExpiring, (err, results) ->
          log ""
          return next err

    # Get membership renewals retry
    (next) ->
      type = "renewal_membership_retry"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      User.membershipExpiredByDate retryDate, TENANT_ID, (err, tMemberships_retry) ->
        return next err if err
        for user in tMemberships_retry
          if user.memberStatus is "auto-renew-retry"
            memberships_retry.push user
        #else, this member doesn't get a retry, they are just expired.
        log "Found #{memberships_retry.length} membership renewals retries for #{retryDate.format('MM/DD/YYYY')}", true
        async.mapSeries memberships_retry, processMemberRenewalRetry, (err, results) ->
          log ""
          return next err

    # Get upcoming expiring memberships
    (next) ->
      type = "upcoming_memberships_expire"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      upcomingDate = moment(RUN_DATE).add(1, 'months')
      User.membershipExpiredByDate upcomingDate, TENANT_ID, (err, tMemberships_upcoming) ->
        return next err if err
        memberships_upcoming = tMemberships_upcoming
        log "Found #{memberships_upcoming.length} upcoming expiring memberships on #{upcomingDate.format('MM/DD/YYYY')}", true
        async.mapSeries memberships_upcoming, processMembershipUpcomingExpire, (err, results) ->
          log ""
          return next err

  ], (err) ->
    success = true
    log ""
    log ""
    log "Finished running renewal-cron script.", true
    log "#{moment().format('MM/DD/YYYY, h:mm:ss a')}", true
    if err
      console.error "Found an error, existing.", err
      log "Found an error, existing. #{err}", true
      success = false

    if success
      log "Successfully renewed...etc.", true

      sendCronEmail success, log_message_string, (err, results) ->
        process.exit(0)
    else
      sendCronEmail success, log_message_string, (err, results) ->
        process.exit(1)
