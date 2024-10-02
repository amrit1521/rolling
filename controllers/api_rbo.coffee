_ = require "underscore"
async = require "async"
moment = require "moment"
request = require "request"
http = require 'http'
crypto = require "crypto"

module.exports = (APITOKEN_RB, APITOKEN_VDTEST, RollingBonesTenantId, VerdadTestTenantId, NavTools,
  salt, Secure, Token, users, HuntinFoolState, authorizenetapi, mailchimpapi, MailChimpMasterListId,
  Tenant, User, HuntCatalog, Purchase, ServiceRequest, huntCatalogs, api_rbo_rrads, RRADS_API_BASEURL, RRADS_API_BASEURL_STAGING
  APITOKEN_MAILCHIMP, APITOKEN_MAILCHIMP_VDTEST, APITOKEN_RADS_APP, GotMyTagTenantId, Reminder, reports, hunts, TENANT_IDS) ->

  API = {

    log: (reqData, resData) ->
      logIt = false
      tenantId = null

      logapi = (logIt) ->
        if logIt and reqData
          reqBody = _.clone(reqData.body) if reqData?.body?
          delete reqBody.password if reqBody?.password
          delete reqBody.password_confirmation if reqBody?.password_confirmation
          console.log "API Req params: ", reqData.params
          console.log "API Req query: ", reqData.query
          console.log "API Req body: ", reqBody
        else if logIt and resData
          console.log "API response: ", resData
        else
          return

      try
        if reqData?.tenant?.logAPI?
          logIt = reqData.tenant.logAPI
        else if reqData.param? and reqData.param('tenantId')
          tenantId = reqData.param('tenantId')
      catch ex
        console.log "Error: Logging failed tenantId check: ", ex

      #NOTE: LOGGING BASED ON TENANTID LOOKUP FROM TOKEN
      if tenantId
        Tenant.findById tenantId, (err, tenant_tmp) ->
          console.log "Error: Logging failed tenantId find check: ", err if err
          logIt = tenant_tmp.logAPI if tenant_tmp
          if logIt is true
            logapi(logIt)
          else
            logapi(false)
      else
        logapi(logIt)

    captureError: (source, errData, reqData) ->
      try
        errDataStr = ""
        reqDataParams = ""
        reqDataQuery = ""
        reqDataBody = ""
        messageStr = ""

        errDataStr = JSON.stringify(errData) if errData
        reqDataParams = JSON.stringify(reqData.params) if reqData?.params
        reqDataQuery = JSON.stringify(reqData.query) if reqData?.query
        reqDataBody = JSON.stringify(reqData.body) if reqData?.body
        messageStr = "#{messageStr}Error: #{errDataStr}\n"
        console.log "API Req query: ", reqData.query if reqData?.query
        console.log "API Req params: ", reqData.params if reqData?.params
        console.log "API Req body: ", reqData.body if reqData?.body
        console.log "Capture Error: ", errData if errData

        now = moment().format()
        template_name = "Capture Error"
        subject = "Server Error"
        mandrilEmails = []
        to = {
          email: "scott@rollingbonesoutfitters.com"
          type: "to"
        }
        mandrilEmails.push to if to
        payload = {
          timestamp: now
          source: "api_rbo.coffee"
          message: messageStr
          reqDataQuery: reqDataQuery
          reqDataParams: reqDataParams
          reqDataBody: reqDataBody

        }
        mailchimpapi.sendEmail null, template_name, subject, mandrilEmails, payload, null, null, null, false, null

      catch ex
        console.log "captureError exception: ", ex if ex
        return "ignore"

      return

    sendServerEmail: (subject, source, message) ->
      template_name = "Server Message"
      mandrilEmails = []
      to = {
        email: "scott@rollingbonesoutfitters.com"
        type: "to"
      }
      mandrilEmails.push to if to
      payload = {
        source: source
        message: message
      }
      mailchimpapi.sendEmail null, template_name, subject, mandrilEmails, payload, null, null, null, false, null
      return

    #Authenticate login credentials from the client side browser js.  Return authcode for server api to user.  Don't want to expose apitoken to client side.
    login: (req, res) ->
      @log(req)
      #apitoken = req.param('token')
      #return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      username = req.param('username')
      password = req.param('password')
      encryptedTimestamp = req.param('stamp')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      return res.json {error: "Bad Request missing username"}, 400 unless username
      return res.json {error: "Bad Request missing password"}, 400 unless password
      return res.json {error: "Bad Request missing stamp"}, 400 unless encryptedTimestamp

      body = req.body
      result_success = {
        authcode: ""
        status: "authenticated"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      stamp = Secure.validate_rads_stamp encryptedTimestamp
      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid

      encryptedPassword = @hashPassword(password)
      @loginUser username, encryptedPassword, tenantId, (err, result) ->
        if err
          result_failed.error = err
          console.log "Login Error: ", err
          return res.json result_failed, 400
        else if result?.token?.code
          result_success.authcode = result.token.code
          console.log "Login Success: ", result_success
          return res.json result_success
        else
          console.log "Login Error, no message."
          return res.json result_failed, 400

    #Called when already authenticated from an external system like brownells. Encrypted Stamp validation ensures security
    login_sso: (req, res) ->
      @log(req)
      tenantId = req.param('tenantId')
      encryptedTimestamp = req.param('stamp')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      return res.json {error: "Bad Request missing stamp"}, 400 unless encryptedTimestamp

      body = req.body
      result_success = {
        authcode: ""
        status: "authenticated"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      stamp = Secure.validate_rads_stamp encryptedTimestamp
      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid
      email = stamp?.params?.email
      email = email.replace("%40","@")
      source = stamp?.params?.source
      if !source is 'brownells' or !email
        result_failed.error = "Unauthorized: Invalid SSO stamp"
        return res.json result_failed, 400

      ssoLogin = (email, tenantId, cb) =>
        User.findByEmail email, tenantId, {internal: false}, (err, user) =>
          if err
            console.error "Unexpected error on login: ", err
            return cb err if err
          return cb "Unauthorized" if not user

          token = new Token {
            token: crypto.randomBytes(64).toString('hex')
            expires: moment().add(1, 'day').toDate()
            userId: user._id
          }

          token.save (err, token) ->
            if err
              console.error "Failed to update local user token:", err
              console.error "Failed to update local user token:" unless token
              return cb err if err
              return cb "Failed to update local user token" unless token

            result = {
              user: _.pick(user, '_id', 'name', 'clientId')
              token: {
                code: token.get 'token'
                expires: token.get 'expires'
              }
            }
            return cb null, result

      ssoLogin email, tenantId, (err, result) ->
        if err
          result_failed.error = err
          return res.json result_failed, 400
        else if result?.token?.code
          result_success.authcode = result.token.code
          return res.json result_success
        else
          return res.json result_failed, 400


    #Given user authenticated code, and server apitoken, return the userId (and user)
    user_get: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      userId = req.param('_id')
      if !@isValidToken(apitoken)
        console.log "2nd half of user login faield in user_get api call isValidToken(apitoken)  apitoken used was: ", apitoken
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      result_success = {
        user: {}
        status: "authenticated"
        authcode: ""
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      async.waterfall [
        #Retrieve the user
        (next) ->
          if req.headers['x-ht-auth']
            tokenStr = req.headers['x-ht-auth'] if req.headers['x-ht-auth']
            Token.findOne({token: tokenStr}).lean().exec (err, token) ->
              return next(err) if err
              return next('Token not found') unless token
              User.findById token.userId, internal: false, (err, user) ->
                return next(JSON.stringify(err)) if err
                return next "User not found for provided authcode" unless user
                return next null, user
          else
            User.byId userId, (err, user) ->
              return next err if err
              return next "User not found for _id: #{userId}" unless user
              return next null, user

        #Setup user token
        (user, next) ->
          token = new Token {
            token: crypto.randomBytes(64).toString('hex')
            expires: moment().add(1, 'day').toDate()
            userId: user._id
          }
          token.save (err, token) ->
            return next err if err
            return next "Unauthorized failed to create valid token." unless token
            user.authcode = token.token
            return next null, user

        #Set ClientId
        (user, next) ->
          return next null, user if user.clientId
          Tenant.findById tenantId, (err, tenant) ->
            return next err if err
            return next "Unable to retrieve tenant for tenantId #{tenantId}" unless tenant
            Tenant.getNextClientId tenantId, (err, newClientId) ->
              return next err if err
              return next {error: "new ClientId not found for tenant id: #{tenantId}"} unless newClientId
              userData = {
                _id: user._id
              }
              userData.clientId = tenant.clientPrefix + newClientId
              User.upsert userData, {upsert: false}, (err, userRsp) ->
                return next err if err
                user.clientId = userRsp.clientId
                return next null, userRsp.clientId

        #Get HuntinFoolState info
        (user, next) ->
          HuntinFoolState.byUserId user._id, (err, huntFoolStates) ->
            next err, user, huntFoolStates

      ], (err, user, huntFoolStates) ->
        if err
          console.log "rbo_api user_get() Error: ", err if err
          result_failed.error = err
          return res.json result_failed, 401
        else if user
          user.subscriptions.rifle_specials = user.subscriptions.rifles if user.subscriptions?.rifles?
          user.subscriptions.hunt_specials = user.subscriptions.rifles if user.subscriptions?.rifles?
          user.subscriptions.product_specials = user.subscriptions.rifles if user.subscriptions?.rifles?

          huntFoolState = huntFoolStates[0]
          appData = {}
          appData.legacyHuntPlan = {}
          appData.applications = {}
          appData.application_items = {}
          NRADS_RRADS_MAPPING = {
            'deer': "North American Deer"
            'bighorn sheep': "Rocky Mountain Bighorn Sheep"
            'sheep': "North American Sheep"
            'mountain lion': "Cougar"
            'aoudad (barbary) sheep': "Aoudad Sheep"
            'coues deer': "Coues Whitetail Deer"
            #'mountain goat': ""
            'blacktail deer': "Sitka Blacktail Deer"
            #'wolf': ""
            'duck': "waterfowl"
          }
          if huntFoolStates
            for huntFoolState in huntFoolStates
              if huntFoolState
                huntFoolState.year = "none" unless huntFoolState.year
                appData.application_items[huntFoolState.year] = {}
                showStates = []
                #This block is to hide old nrad hunt plans that had all states saved as entries, filter out the checked=false, empty ones.
                for key in Object.keys(huntFoolState)
                  continue if key is "__v"
                  continue if key is "_id"
                  if key.indexOf("_") > -1
                    stateAbr = key.split("_")[0]
                    if huntFoolState["#{stateAbr}_check"] is "True" or huntFoolState["#{stateAbr}_check"] is "true" or huntFoolState["#{stateAbr}_check"] is true
                      showStates.push stateAbr
                      showStates.push "or" if stateAbr is "ore"
                      continue
                    if huntFoolState["#{stateAbr}_notes"]?.length > 0
                      showStates.push stateAbr
                      showStates.push "or" if stateAbr is "ore"
                      continue
                    if huntFoolState.modified? and moment(huntFoolState.modified).isAfter('2019-01-01T01:00:00Z')
                      showStates.push stateAbr
                      showStates.push "or" if stateAbr is "ore"
                      continue
                for key in Object.keys(huntFoolState)
                  continue if key is "__v"
                  continue if key is "_id"
                  value = huntFoolState[key]
                  value = true if value is "True" or value is "true"
                  value = false if value is "False" or value is "false"
                  if key.indexOf("ore") > -1
                    key = key.replace("ore", "or")
                  if key.indexOf("_notes") > -1 and value?.length
                    appData.legacyHuntPlan[key] = value
                  if key.indexOf("_check") > -1 and value is true
                    appData.applications[key] = true
                  if key.indexOf("_") > -1
                    stateAbr = key.split("_")[0]
                    if key.indexOf("species_picked") > -1
                      tValue = []
                      for sp in value
                        if NRADS_RRADS_MAPPING[sp.toLowerCase()]
                          tValue.push NRADS_RRADS_MAPPING[sp.toLowerCase()]
                        else
                          tValue.push sp
                      value = tValue
                    appData.application_items[huntFoolState.year][key] = value if showStates.indexOf(stateAbr) > -1
                  if key is "gen_notes"
                    appData.application_items[huntFoolState.year][key] = value

          mergedUser = JSON.parse(JSON.stringify(user))
          mergedUser.legacyHuntPlan = appData.legacyHuntPlan
          mergedUser.applications = appData.applications
          mergedUser.application_items = appData.application_items
          result_success.user = mergedUser
          result_success.authcode = user.authcode
          #console.log "rbo_api user_get() returning result_success: ", result_success
          return res.json result_success

        else
          console.log "rbo_api user_get() Error: Could not find user."
          result_failed.error = "Could not find user"
          return res.json result_failed, 401

    #Given user authenticated code, and server apitoken, return the user payment info
    user_getPaymentInfo: (req, res) ->
      @log(req)
      #NOTE: In Express Server hook, it is already callling middleware/auth.coffee user, and authenticate so req.user exists.
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      result_success = {
        payment_info: {}
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      #IF NO PAYMENT INFO RETURNED FROM AUTH, RETURN and empty payment_info object.

      if req.user
        authorizenetapi.getPaymentProfile req.user, (err, results) ->
          if err
            result_failed.error = err
            console.log "Get Payment Info failed with error: ", result_failed
            return res.json result_failed, 401
          result_success.payment_info = results
          return res.json result_success
      else
        result_failed.error = "Could not find user"
        return res.json result_failed, 401


    #Given user authenticated code, and server apitoken, create or update the user payment info in authorize.net
    user_upsertPaymentInfo: (req, res) ->
      @log(req)
      #NOTE: In Express Server hook, it is already callling middleware/auth.coffee user, and authenticate so req.user exists.
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      clientId = req.body.clientId
      authorize_net_data_descriptor = req.body.authorize_net_data_descriptor
      authorize_net_data_value = req.body.authorize_net_data_value
      fullName = req.body.fullName if req.body.fullName
      nameOnAccount = req.body.nameOnAccount if req.body.nameOnAccount
      zip = req.body.zip if req.body.zip
      payment_method = req.body.payment_method if req.body.payment_method
      address1 = req.body.address1 if req.body.address1
      address2 = req.body.address2 if req.body.address2
      country = req.body.country if req.body.country
      state = req.body.state if req.body.state
      city = req.body.city if req.body.city
      return res.json {error: "Bad Request missing clientId"}, 400 unless clientId
      return res.json {error: "Bad Request missing authorize_net_data_descriptor"}, 400 unless authorize_net_data_descriptor
      return res.json {error: "Bad Request missing authorize_net_data_value"}, 400 unless authorize_net_data_value
      return res.json {error: "Bad Request missing or invalid payment_method"}, 400 unless payment_method and (payment_method is "card" or payment_method is "bank")

      if payment_method is "card"
        return res.json {error: "Bad Request missing fullName"}, 400 unless fullName
        return res.json {error: "Bad Request missing address1"}, 400 unless address1
        return res.json {error: "Bad Request missing country"}, 400 unless country
        return res.json {error: "Bad Request missing state"}, 400 unless state
        return res.json {error: "Bad Request missing city"}, 400 unless city
        return res.json {error: "Bad Request missing zip"}, 400 unless zip
      else
        return res.json {error: "Bad Request missing nameOnAccount"}, 400 unless nameOnAccount

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }


      sendSuccessEmail = (user) ->
        template_name = "Server Message"
        subject = "User updated card info"
        mandrilEmails = []
        to = {
          email: "scott@rollingbonesoutfitters.com"
          type: "to"
        }
        mandrilEmails.push to if to
        payload = {
          source: "api_rbo.coffee user_upsertPaymentInfo"
          message: "Card info updated for User name: '#{user.name}', clientId: '#{user.clientId}', userId: '#{user._id}', customerProfileId: '#{user.payment_customerProfileId}', paymentProfileId: '#{user.payment_paymentProfileId}'"
        }
        mailchimpapi.sendEmail null, template_name, subject, mandrilEmails, payload, null, null, null, false, null


      if req.user
        paymentInfo = {
          authorize_net_data_descriptor: authorize_net_data_descriptor
          authorize_net_data_value: authorize_net_data_value
        }
        name = fullName if fullName
        name = nameOnAccount if nameOnAccount
        if name
          names = @parseName(name, true)
          paymentInfo.first_name = names.first_name
          paymentInfo.last_name = names.last_name
        paymentInfo.address = address1 if address1
        paymentInfo.city = city if city
        paymentInfo.state = state if state
        paymentInfo.postal = zip if zip
        paymentInfo.country = country if country
        #First update the auth.net customer profile
        authorizenetapi.upsertCustomerProfile req.user, (err, user) =>
          if err
            result_failed.error = err
            console.log "Update Payment Info failed to update customer profile with error: ", result_failed
            @captureError("api_rbo.coffee user_upsertPaymentInfo", err, req)
            return res.json result_failed, 401
          #Now update the auth.net payment profile
          authorizenetapi.upsertPaymentProfile user, paymentInfo, true, (err, results) =>
            user.payment_paymentProfileId = results.payment_paymentProfileId if results?.payment_paymentProfileId
            if err
              result_failed.error = err
              console.log "Update Payment Info failed with error: ", result_failed
              @captureError("api_rbo.coffee user_upsertPaymentInfo", err, req)
              return res.json result_failed, 401
            sendSuccessEmail(user)
            return res.json result_success
      else
        result_failed.error = "Could not find user"
        return res.json result_failed, 401


    #Called from Mailchimp Web Hook when user changes in MailChimp
    webhook_mailchimp_ping: (req, res) ->
      @log(req)
      return res.json "Web Hook GET validation succeeded."

    #Called from Mailchimp Web Hook when user changes in MailChimp
    webhook_mailchimp: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      apitoken = req.query.token if req.query and !apitoken
      console.log "Skipping mail chimp hook, invalid token: ", apitoken unless @isValidToken(apitoken)
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')

      #Found using mailchimp's api playground tool
      group_huntspecials_id = "11134d3a3b"
      group_statereminders_id = "b66afdefe9"
      group_products_id = "99096a057f"
      group_rifles_id = "c96022ad6d"
      group_newsletters_id = "90795561f5"

      type = req.body['type']
      list_id = req.body['data[list_id]']
      id = req.body['data[id]']
      email = req.body['data[email]']
      email_type = req.body['data[email_type]']
      ip_opt = req.body['data[ip_opt]']
      web_id = req.body['data[web_id]']
      user_email = req.body['data[merges][EMAIL]']
      user_fname = req.body['data[merges][FNAME]']
      user_lname = req.body['data[merges][LNAME]']
      user_address1 = req.body['data[merges][ADDRESS][addr1]']
      user_address2 = req.body['data[merges][ADDRESS][addr2]']
      user_city = req.body['data[merges][ADDRESS][city]']
      user_state = req.body['data[merges][ADDRESS][state]']
      user_zip = req.body['data[merges][ADDRESS][zip]']
      user_country = req.body['data[merges][ADDRESS][country]']
      user_phone = req.body['data[merges][PHONE]']
      interests = req.body['data[merges][INTERESTS]']
      group_id = req.body['data[merges][GROUPINGS][0][id]']
      group_unique_id = req.body['data[merges][GROUPINGS][0][unique_id]']
      group_name = req.body['data[merges][GROUPINGS][0][name]']
      group_interests = req.body['data[merges][GROUPINGS][0][groups]']

      #TODO: Currently only handing interest and subscribe/unsubscribe changes.  Not profile email, name, address changes.
      console.log "Skipping mail chimp hook, bad list_id: ", list_id, MailChimpMasterListId unless list_id is MailChimpMasterListId
      return res.json "Ignoring event, not related to MailChimpMasterListId", 400 unless list_id is MailChimpMasterListId
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      returnError = (err) ->
        console.log "API Endpoint returning error: ", err
        result_failed.error = err
        return res.json result_failed, 400

      usersCtrl = users
      User.findByEmailOrUsername email, email, tenantId, {}, (err, users) ->
        if err
          returnError err
          return
        returnError "User not found for email address: #{email}" unless users?.length > 0
        return unless users?.length > 0

        processUser = (user, done) ->
          async.waterfall [

            #Setup defaults
            (next) ->
              subscriptions = {
                hunts: "false"
                rifles: "false"
                products: "false"
                newsletters: "false"
                statereminders_text: "false"
                statereminders_email: "false"
              }
              #Get existing settings, especially reminder text setting so we don't overwrite it as the API requires it but it's not coming from Mailchimp
              subscriptions.statereminders_text = "true" if user.reminders?.text and (user.reminders?.types?.indexOf("app-start") > -1 or user.reminders?.types?.indexOf("app-end") > -1)
              return next null, subscriptions

            #Get current subscription info from mailchimp webhook call to RADS
            (subscriptions, next) ->
              return next null, subscriptions #TODO: IMPORTANT, MAILCHIMP BUG, WEBHOOK IS CALLED 3 TIMES with inconsistent interests data
              if type is "unsubscribe"
                subscriptions.statereminders_email = "false"
                subscriptions.hunts = "false"
                subscriptions.rifles = "false"
                subscriptions.products = "false"
                subscriptions.newsletters = "false"
                #Keep subscriptions.statereminders_text with whatever was on the user before.
              else if (type is "subscribe" or type is "profile") and interests?.length
                subscriptions.statereminders_email = "true" if interests.indexOf("State Application Deadline Reminders") > -1
                subscriptions.hunts = "true" if interests.indexOf("Hunt Specials") > -1
                subscriptions.rifles = "true" if interests.indexOf("Rifles and Shooting") > -1
                subscriptions.products = "true" if interests.indexOf("Product Specials") > -1
                subscriptions.newsletters = "true" if interests.indexOf("Newsletter and Contests") > -1
              # else
                #TODO: "upemail", "cleaned", "campaign" are also types.  Ignore for now and just return the user's current settings.

            #Work around to mailchimp's webhook bug.  Go pull the correct info instead of receiving it. Besides groups get pushed as profile updates even if status is unsubscribed
            (subscriptions, next) ->
              mailchimpapi.getUser user.email, MailChimpMasterListId, (err, mc_user) ->
                return next err if err
                return next "Mailchimp user not found for email #{user.email}" unless mc_user
                if mc_user.status is "unsubscribe"
                  subscriptions.statereminders_email = "false"
                  subscriptions.hunts = "false"
                  subscriptions.rifles = "false"
                  subscriptions.products = "false"
                  subscriptions.newsletters = "false"
                  #Keep subscriptions.statereminders_text with whatever was on the user before.
                else if (type is "subscribe" or type is "profile") and mc_user.interests
                  for key, value of mc_user.interests
                    if key is group_huntspecials_id
                      subscriptions.hunts = "true" if value is true
                      subscriptions.hunts = "false" if value is false
                    if key is group_rifles_id
                      subscriptions.rifles = "true" if value is true
                      subscriptions.rifles = "false" if value is false
                    if key is group_products_id
                      subscriptions.products = "true" if value is true
                      subscriptions.products = "false" if value is false
                    if key is group_newsletters_id
                      subscriptions.newsletters = "true" if value is true
                      subscriptions.newsletters = "false" if value is false
                    if key is group_statereminders_id
                      subscriptions.statereminders_email = "true" if value is true
                      subscriptions.statereminders_email = "false" if value is false

                return next null, subscriptions

          ], (err, subscriptions) ->
            return done err if err
            #UPDATE NRADS
            usersCtrl.updateSubscriptions user, subscriptions, false, (err, user) ->
              return done err if err
              #UPDATE RRADS
              req.params.tenantId = tenantId
              req.params._id = user._id
              api_rbo_rrads.user_upsert_rads req, (err, result) ->
                return done err, user

        async.mapSeries users, processUser, (err, results) ->
          returnError err if err
          return res.json result_success


    #Given user authenticated code, and server apitoken, update user opt in notification settings
    user_notifications: (req, res) ->
      @log(req)
      body = req.body
      if req.params.direct is true
        apitoken = req.params.token
        tenantId = req.params.tenantId
        hunts_flag = req.params.hunts
        products_flag = req.params.products
        newsletters_flag = req.params.newsletters
        rifles_flag = req.params.rifles
        state_reminders_email_flag = req.params.state_reminders_email
        state_reminders_text_flag = req.params.state_reminders_text
      else
        apitoken = req.param('token')
        tenantId = req.param('tenantId')
        hunts_flag = req.param('hunt_specials')
        products_flag = req.param('product_specials')
        newsletters_flag = req.param('newsletters')
        rifles_flag = req.param('rifle_specials')
        state_reminders_email_flag = req.param('state_reminders_email')
        state_reminders_text_flag = req.param('state_reminders_text')

      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      return res.json {error: "Bad Request missing hunts"}, 400 unless hunts_flag?
      return res.json {error: "Bad Request missing newsletters"}, 400 unless newsletters_flag?
      return res.json {error: "Bad Request missing products"}, 400 unless products_flag?
      return res.json {error: "Bad Request missing rifles"}, 400 unless rifles_flag?
      return res.json {error: "Bad Request missing state_reminders_email"}, 400 unless state_reminders_email_flag?
      return res.json {error: "Bad Request missing state_reminders_text"}, 400 unless state_reminders_text_flag?

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }
      subscriptions = {
        hunts: hunts_flag
        products: products_flag
        newsletters: newsletters_flag
        rifles: rifles_flag
        statereminders_email: state_reminders_email_flag
        statereminders_text: state_reminders_text_flag
      }

      if req.user
        if !req.user.email
          error_msg = "User email address is missing.  Cannot subscribe. Please update your email and subscribe again."
          result_failed.error = error_msg
          result_failed.error_msg = error_msg
          return res.json result_failed, 501
        users.updateSubscriptions req.user, subscriptions, true, (err, user) ->
          if err
            result_failed.error = err
            return res.json result_failed, 401
          else
            result_success.results = user
            return res.json result_success
      else
        result_failed.error = "Could not find user"
        return res.json result_failed, 401


    #Given user authenticated code, and server apitoken, update user opt in reminder settings
    user_reminders: (req, res) ->
      @log(req)
      #NOTE: In Express Server hook, it is already callling middleware/auth.coffee user, and authenticate so req.user exists.
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      subscriptions = {
        statereminders_email: false
        statereminders_text: false
        statereminders_states: []
      }
      subscriptions.statereminders_email = true if req.body.email is true
      subscriptions.statereminders_text = true if req.body.text is true
      if req.body.states?.length
        for state in req.body.states
          if state?.name
            subscriptions.statereminders_states.push state.name

      if req.user
        if !req.user.email
          error_msg = "User email address is missing.  Cannot subscribe. Please update your email and subscribe again."
          result_failed.error = error_msg
          result_failed.error_msg = error_msg
          return res.json result_failed, 501
        users.updateSubscriptions req.user, subscriptions, true, (err, user) ->
          if err
            result_failed.error = err
            return res.json result_failed, 401
          else
            result_success.results = user
            return res.json result_success
      else
        result_failed.error = "Could not find user"
        return res.json result_failed, 401


    #Given user authenticated code, and server apitoken, return all users
    user_index: (req, res) ->
      @log(req)
      #NOTE: In Express Server hook, it is already callling middleware/auth.coffee user, and authenticate so req.user exists.
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      result_success = {
        users: ""
        status: "authenticated"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      if req.user?.isAdmin
        User.findByTenant tenantId, {}, (err, users) =>
          for user in users
            user = @sanatizeUser user
          if err or !users
            result_failed.error = err
            return res.json result_failed, 401
          else
            result_success.users = users
            return res.json result_success
      else
        result_failed.error = "Unauthorized"
        return res.json result_failed, 401


    #Create new user account
    user_create: (req, res) ->
      @log(req)
      usersCtrl = users
      tenantId = req.param('tenantId')
      parent_clientId = req.param('parent_clientId')
      default_parent_clientId = req.param('default_parent_clientId')
      encryptedTimestamp = req.param('stamp')
      disableWelcomeEmail = req.param('disableWelcomeEmail')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId

      stamp = Secure.validate_rads_stamp encryptedTimestamp
      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid

      sendWelcomeEmail = true
      if stamp.params['tenant[whitelabel_level_one_status]'] is 'enabled' and stamp.params['tenant[whitelabel_level_two_status]'] is 'disabled' and stamp.params['tenant[whitelabel_level_three_status]'] is 'disabled'
        sendWelcomeEmail = false

      if disableWelcomeEmail is 'true' or disableWelcomeEmail is true
        sendWelcomeEmail = false

      body = req.body
      result_success = {
        #user: ""
        status: "successful"
        authcode: ""
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      email_template_prefix = body.tenant_email_prefix if body.tenant_email_prefix
      email_from_name = body.tenant_email_from_name if body.tenant_email_from_name
      tUser = body
      passwordTxt = tUser.password

      #Required fields in order to create a new user account
      return res.json {error: "Bad Request missing user email"}, 400 unless tUser.email
      return res.json {error: "Bad Request missing user password"}, 400 unless tUser.password
      return res.json {error: "Bad Request, unauthorized."}, 400 unless tUser.web_page #security step to see what is creating the new bogus users

      #Check default parent assignment
      if default_parent_clientId and !parent_clientId
        parent_clientId = default_parent_clientId

      #Data clean-up and logic
      tUser.name = "#{tUser.first_name} #{tUser.last_name}" if !tUser.name and tUser.first_name and tUser.last_name
      tUser.password = @hashPassword(tUser.password)
      tUser.email = tUser.email.toLowerCase() if tUser.email
      tUser.tenantId = tenantId
      tUser.parent_clientId = parent_clientId if parent_clientId
      tUser.imported = "RRADS"
      tUser.needsWelcomeEmail = false
      tUser.referredBy = tUser.referred_by if tUser.referred_by
      tUser.welcomeEmailSent = new Date()
      tUser.source = tUser.web_page

      #Check if existing by userId and clientId.  Note: Shouldn't have either field set in create req.
      userId = tUser._id if tUser._id
      userId = tUser.id if tUser.id
      userId = tUser.userId if tUser.userId

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null unless userId
          User.findOne({_id: userId, tenantId: tenantId}).lean().exec (err, user) ->
            return next "Create user account failed.  A user already exists for user id: #{userId}" if user
            return next err

        (next) ->
          #Check if user already exists (by clientId and tenant)
          return next null unless tUser.clientId
          User.findOne({type: "local", clientId: tUser.clientId, tenantId: tenantId}).lean().exec (err, user) ->
            return next "Create user account failed.  A user already exists for clientId: #{tUser.clientId}" if user
            return next err

        (next) ->
          #Check if email already belongs to a different user
          return next null unless tUser.email
          User.findOne({email: tUser.email, tenantId: tenantId}).lean().exec (err, user) ->
            return next "Create user account failed.  A user already exists for email: #{tUser.email}" if user
            return next err

        (next) ->
          #Check if username already belongs to a different user
          return next null unless tUser.username
          User.findOne({username: tUser.username, tenantId: tenantId}).lean().exec (err, user) ->
            return next "Create user account failed.  A user already exists for username: #{tUser.username}" if user
            return next err

        (next) =>
          #Check if this user is linked to and being created from another user account
          return next null unless tUser.linked_userId
          User.byId tUser.linked_userId, {internal: true}, (err, linked_user) ->
            console.log "Error: could not find user for linked_userId: #{tUser.linked_userId}: ", err if err
            console.log "Error: could not find user for linked_userId: #{tUser.linked_userId}: " unless linked_user
            return next null if err
            return next null unless linked_user
            tUser.password = linked_user.password if linked_user.password
            return next null

        (next) =>
          #Check and assign parent user
          #return next null unless tUser.parent_clientId
          if tUser.parentId
            return next null
          else if tUser.parent_clientId
            tUser.referredBy = tUser.parent_clientId unless tUser.referredBy
            User.byClientId tUser.parent_clientId, {}, (err, parent) =>
              return next err if err
              if parent
                tUser.parentId = parent._id if parent
                return next null
              else
                console.log "Could not find parent for parent client id: ", tUser.parent_clientId
                return next null
          else
            if tenantId.toString() is TENANT_IDS.RollingBones
              tUser.parentId = "570419ee2ef94ac9688392b0" #Hard coded to Brian and Lynley Mehmen for now.
            else if tenantId.toString() is TENANT_IDS.RollingBonesTest
              tUser.parentId = "5bd7607b02c467db3f70eda2" #Hard coded to top Admin user
            else
              return next null #It's a whitelabel tenant, don't assign parent
            return next null

        (next) =>
          #Create the new user account
          @user_upsert tUser, (err, user) =>
            return next err, user

        (user, next) =>
          #Send new user email
          if sendWelcomeEmail
            Tenant.findById tenantId, (err, tenant) =>
              console.log "Error: failed to send welcome email.  Error: ", err if err
              if tenant
                tenant.tmp_email_template_prefix = email_template_prefix if email_template_prefix
                tenant.tmp_email_from_name = email_from_name if email_from_name
                usersCtrl.sendWelcomeEmail tenant, user, passwordTxt, (err) ->
                  console.log "Welcome email failed to send with error: ", err if err
                  console.log "Welcome email sent." unless err
              return next null, user
          else
            return next null, user

        (user, next) =>
          #Update subscription and state_reminder settings
          if tUser.sign_up_for_specials
            subscriptions = {
              hunts: true
              products: true
              newsletters: true
              rifles: true
              statereminders_email: true
              statereminders_text: false
              statereminders_states: []
            }
            subscriptions.statereminders_states.push tUser.physical_state if tUser.physical_state
            users.updateSubscriptions user, subscriptions, true, (err, user) ->
              console.log "Error: Failed to update subscription settings for user: #{user.name}, #{user._id}", err if err
              return next null, user
          else
            return next null, user

      ], (err, user) =>
        if err
          result_failed.error = err
          return res.json result_failed, 500

        #Some weird object gets retruend that console.log doesn't display but Object.keys does.  JSON'ing it fixes it.
        user = JSON.stringify(user)
        user = JSON.parse(user)
        #result_success.user = @sanatizeUser user   For now, don't return the user object

        @loginUser user.email, tUser.password, tenantId, (err, result) =>
          if err
            result_failed.error = err
            return res.json result_failed, 400
          else if result?.token?.code
            result_success.authcode = result.token.code
            result_success._id = result.user._id if result.user?._id
            result_success.client_id = result.user.clientId if result.user?.clientId
            return res.json result_success
          else
            return res.json result_failed, 400



    #Update user account, does NOT update password
    user_update: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      result_success = {
        user: ""
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }


      tUser = {}

      userId = body._id if body._id
      userId = body.id if body.id
      userId = body.userId if body.userId

      #Required fields in order to create udpate a user account
      return res.json {error: "Bad Request missing user id"}, 400 unless userId
      if !req.user.isAdmin and userId.toString() != req.user._id.toString()
        return res.json {error: "User update request unauthorized."}, 400

      #Data clean-up and logic
      tUser.name = body.name if body.name
      tUser.name = "#{body.first_name} #{body.last_name}" if !body.name and body.first_name and body.last_name
      tUser.email = body.email.toLowerCase() if body.email
      tUser.tenantId = tenantId unless tUser.tenantId
      tUser.first_name = body.first_name if body.first_name
      tUser.last_name = body.last_name if body.last_name
      tUser.phone_cell = body.phone_number if body?.phone_number
      tUser.physical_address = body.physical_address.address_1 if body?.physical_address?.address_1
      tUser.physical_city = body.physical_address.city if body?.physical_address?.city
      tUser.physical_state = body.physical_address.state if body?.physical_address?.state
      tUser.physical_postal = body.physical_address.zip if body?.physical_address?.zip
      tUser.physical_country = body.physical_address.country if body?.physical_address?.country
      tUser.physical_country = "United States" if tUser.physical_country is "United States of America"
      tUser.mail_address = body.mailing_address.address_1 if body?.mailing_address?.address_1
      tUser.mail_city = body.mailing_address.city if body?.mailing_address?.city
      tUser.mail_state = body.mailing_address.state if body?.mailing_address?.state
      tUser.mail_postal = body.mailing_address.zip if body?.mailing_address?.zip
      tUser.mail_country = body.mailing_address.country if body?.mailing_address?.country
      tUser.mail_country = "United States" if tUser.mail_country is "United States of America"
      tUser.shipping_address = body.shipping_address.address_1 if body?.shipping_address?.address_1
      tUser.shipping_city = body.shipping_address.city if body?.shipping_address?.city
      tUser.shipping_state = body.shipping_address.state if body?.shipping_address?.state
      tUser.shipping_postal = body.shipping_address.zip if body?.shipping_address?.zip
      tUser.shipping_country = body.shipping_address.country if body?.shipping_address?.country
      tUser.shipping_country = "United States" if tUser.shipping_country is "United States of America"
      tUser.referredBy = tUser.referred_by if tUser.referred_by
      delete tUser.password

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          User.findOne({_id: userId, tenantId: tenantId}).lean().exec (err, user) ->
            return next "Update user account failed.  User does not exist for user id: #{userId}, tenantId: #{tenantId}" unless user
            return next err, user

        (user, next) =>
          #Check if we need to update the linked userid
          return next null, user if user.linked_userId
          return next null, user unless body.linked_userId
          tUser.linked_userId = body.linked_userId if body.linked_userId
          return next null, user

        (user, next) =>
          #Check if we need to grant a new membership
          return next null, user if user.isMember
          return next null, user unless body.create_membership is true or body.create_membership is "true"
          tUser.isMember = true
          tUser.memberStarted = body.memberStarted if body.memberStarted
          tUser.memberExpires = body.memberExpires if body.memberExpires
          tUser.memberStatus = body.memberStatus if body.memberStatus
          tUser.memberType = body.memberType if body.memberType
          return next null, user

        (user, next) =>
          #Update the user account
          return next "User not found" unless user
          tUser._id = user._id
          @user_upsert tUser, (err, user) ->
            return next err, user

        (user, next) =>
          #Update devices if any
          return next "User not found" unless user
          devices = body.devices if body?.devices?.length
          return next null, user unless devices?.length
          addDevice = (device, done) ->
            User.addDevice user._id, device, (err, uUser) ->
              return done err, uUser
          async.mapSeries devices, addDevice, (err, results) ->
            return next err if err
            most_uptodate_user = user
            for result in results
              most_uptodate_user = result if result
            return next err, most_uptodate_user

      ], (err, user) =>
        if err
          result_failed.error = err
          return res.json result_failed, 500

        if body.do_not_auto_renew_membership is true
          tUser.memberStatus = ""
          delete req.body.hunt_plans if req?.body?.hunt_plans
          delete req.body.best_matches if req?.body?.best_matches
          @captureError "RRADS User Profile Save", "Request to Opt Out of yearly membership auto-renew", req

        #Some weird object gets retruend that console.log doesn't display but Object.keys does.  JSON'ing it fixes it.
        user = JSON.stringify(user)
        user = JSON.parse(user)
        delete user.powerOfAttorney
        result_success.user = @sanatizeUser user
        return res.json result_success



    #Forgot Password
    user_forgotPassword: (req, res) ->
      @log(req)
      url = req.param('url')
      email = req.param('email')
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing url"}, 400 unless url
      return res.json {error: "Bad Request missing email"}, 400 unless email
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId

      body = req.body

      email_template_prefix = body.tenant_email_prefix if body.tenant_email_prefix
      email_from_name = body.tenant_email_from_name if body.tenant_email_from_name

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      template_name = "Forgot Password"
      subject = "Change Password Request"
      to = {
        email: email
        type: "to"
      }
      payload = {
        passwordlink: url
      }
      Tenant.findById tenantId, (err, tenant) ->
        if err
          console.log "Error: user_forgotPassword ", err
          result_failed.error = err
          return res.json result_failed, 500
        else
          tenant.tmp_email_template_prefix = email_template_prefix if email_template_prefix
          tenant.tmp_email_from_name = email_from_name if email_from_name
          mailchimpapi.sendEmail tenant, template_name, subject, to, payload, null, null, null, false, null
          result_success.message = "Email request sent to Mandrill"
          return res.json result_success



    #Forgot Password, will be secure validating on the stamp
#    user_changePassword: (req, res) ->
#      @log(req)
#      tenantId = req.param('tenantId')
#      email = req.param('email')
#      currentPassword = req.param('password')
#      newPassword = req.param('newpassword')
#      encryptedTimestamp = req.param('stamp')
#      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
#      return res.json {error: "Bad Request missing email"}, 400 unless email
#      return res.json {error: "Bad Request missing stamp"}, 400 unless encryptedTimestamp
#      return res.json {error: "Bad Request current password"}, 400 unless currentPassword
#      return res.json {error: "Bad Request missing new password"}, 400 unless newPassword
#
#      body = req.body
#      result_success = {
#        status: "successful"
#      }
#      result_failed = {
#        error: ""
#        status: "failed"
#      }
#
#      stamp = Secure.validate_rads_stamp encryptedTimestamp
#      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid
#
#      encryptedCurrentPassword = @hashPassword(currentPassword)
#      @loginUser email, encryptedCurrentPassword, tenantId, (err, result) =>
#        if err
#          result_failed.error = err
#          return res.json result_failed, 400
#        else if result?.token?.code and result?.user?._id
#          #result_success.authcode = result.token.code
#          User.updatePassword result.user._id, @hashPassword(newPassword), (err) =>
#            if err
#              result_failed.error = err
#              return res.json result_failed, 400
#            else
#              return res.json result_success
#        else
#          return res.json result_failed, 400

    #Forgot Password called from forgot password url link, or Change password from their profile
    user_changePassword: (req, res) ->
      @log(req)
      tenantId = req.param('tenantId')
      newpassword = req.param('password')
      encryptedTimestamp = req.param('stamp')
      return res.json {error: "Bad Request missing stamp"}, 400 unless encryptedTimestamp
      return res.json {error: "Bad Request missing new password"}, 400 unless newpassword
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId

      stamp = Secure.validate_rads_stamp encryptedTimestamp
      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid

      clientId = stamp.params?.client_id
      email = stamp.params?.email
      return res.json {error: "invalid stamp, missing clientId."}, 401 unless clientId
      return res.json {error: "Bad Request missing email"}, 400 unless email

      body = req.body
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }


      User.byClientId clientId, tenantId, (err, user) =>
        if err
          result_failed.error = err
          return res.json result_failed, 500
        console.log "Forgot/Change Password request user not found for clientId: #{clientId} from email: ", email unless user
        return res.json {error: "Bad Request user not found for clientId #{clientId}"}, 400 unless user

        User.updatePassword user._id, @hashPassword(newpassword), (err) =>
          if err
            result_failed.error = err
            return res.json result_failed, 500
          else
            return res.json result_success

    #Return a all hunt catalog items
    huntCatalogs: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      body = req.body

      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Unauthorized"}, 401 unless tenantId
      return res.json {error: "missing userId: userId is required."}, 400 unless body.userId

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant), just for extra security
          return next null, null unless body.userId
          User.findOne({_id: body.userId, tenantId: tenantId}).lean().exec (err, user) ->
            return next err if err
            return next "Failed to find user for userId: #{body.userId}" unless user
            return next "Unauthorized" unless user.isAdmin
            return next err, user

        (user, next) ->
          HuntCatalog.byTenant tenantId, (err, huntCatalogs) ->
            return err if err

            addHuntCatalog = (huntCatalog, done) ->
              delete huntCatalog.startDate unless huntCatalog.startDate and new Date(huntCatalog.startDate.toISOString()) > new Date("2000-01-01")
              delete huntCatalog.endDate unless huntCatalog.endDate and new Date(huntCatalog.endDate.toISOString()) > new Date("2000-01-01")
              return done null, huntCatalog

            async.mapSeries huntCatalogs, addHuntCatalog, (err, huntCatalogs) ->
              return err if err
              tHuntCatalogs = []
              for huntCatalog in huntCatalogs
                tHuntCatalogs.push huntCatalog if huntCatalog
              return next null, tHuntCatalogs
              res.json tHuntCatalogs

      ], (err, huntCatalogs) ->
        return res.json {error: err}, 500 if err
        res.json huntCatalogs


		#Record a purchase from RRADS
    purchase_from_rrads: (req, res) ->
      console.log "Alert DB: purchase_from_rrads called"
      #return res.json {error: "Purchasing is temporarily unavailable.  Please try again later."}, 401
      @log(req)
      apitoken = req.param('token')
      tenantId = req.param('tenantId')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body

      #Top level
      pending_process_uid = req.body.pending_process_uid
      clientId = req.body.clientId
      authorize_net_data_descriptor = req.body.authorize_net_data_descriptor
      authorize_net_data_value = req.body.authorize_net_data_value
      fullName = req.body.fullName if req.body.fullName
      nameOnAccount = req.body.nameOnAccount if req.body.nameOnAccount
      zip = req.body.zip if req.body.zip
      payment_method = req.body.payment_method if req.body.payment_method
      check_name = req.body.check_name if req.body.check_name
      check_number = req.body.check_number if req.body.check_number
      address1 = req.body.address1 if req.body.address1
      address2 = req.body.address2 if req.body.address2
      country = req.body.country if req.body.country
      state = req.body.state if req.body.state
      city = req.body.city if req.body.city
      inStorePurchase = req.body.sub_tenant_store_only if req.body.sub_tenant_store_only is true
      current_sub_tenant_nrads_id = req.body.current_sub_tenant_nrads_id if req.body.current_sub_tenant_nrads_id
      purchaseResponse = req.body.purchase_response

      #CHECK IF SHORTCUT PAY BY CASH OR CHECK:
      if fullName?.toLowerCase().indexOf("*cash") > -1
        payment_method = "cash"
        tCashInfo = fullName.split(" ")
        cash_name = ""
        count = 0
        for piece in tCashInfo
          cash_name = "#{cash_name} #{piece}" if count > 0
          count++
        cash_name = cash_name.trim()
        nameOnAccount = cash_name if cash_name
      else if fullName?.toLowerCase().indexOf("*check") > -1
        payment_method = "check"
        tCheckInfo = fullName.split(" ")
        check_number = ""
        check_name = ""
        count = 0
        for piece in tCheckInfo
          check_number = piece if count is 1
          check_name = "#{check_name} #{piece}" if count > 1
          count++
        check_number = check_number.trim()
        check_name = check_name.trim()
        nameOnAccount = check_name if check_name

      result_success = {
        status: "successful"
        pending_process_uid: pending_process_uid
        tenantId: tenantId
      }
      result_failed = {
        error: ""
        status: "failed"
        pending_process_uid: pending_process_uid
        tenantId: tenantId
      }
      if inStorePurchase and current_sub_tenant_nrads_id
        result_success.tenantId = current_sub_tenant_nrads_id
        result_success.inStorePurchase = inStorePurchase if inStorePurchase
        result_failed.tenantId = current_sub_tenant_nrads_id

      #Required fields in order to submit a purchase request
      return res.json {error: "Bad Request missing pending_process_uid"}, 400 unless pending_process_uid
      return res.json {error: "Bad Request missing clientId"}, 400 unless clientId
      return res.json {error: "Bad Request missing or invalid payment_method"}, 400 unless payment_method and (payment_method is "card" or payment_method is "bank" or payment_method is "cash" or payment_method is "check")

      if payment_method is "card"
        return res.json {error: "Bad Request missing fullName"}, 400 unless fullName
        return res.json {error: "Bad Request missing address1"}, 400 unless address1
        return res.json {error: "Bad Request missing country"}, 400 unless country
        return res.json {error: "Bad Request missing state"}, 400 unless state
        return res.json {error: "Bad Request missing city"}, 400 unless city
        return res.json {error: "Bad Request missing zip"}, 400 unless zip
      else
        return res.json {error: "Bad Request missing nameOnAccount"}, 400 unless nameOnAccount or check_name

      #Payload level
      payload = req.body.payload
      payload_cart = payload.cart
      payload_user = payload.user
      keys = [
        'id'
        'price_todays_payment',
        'price_total','price_processing_fee',
        'price_shipping',
        'price_tags_licenses',
        'price_options',
        'price_sales_tax'
        'start_hunt_date'
        'authorize_automatic_payments'
      ]
      cart = _.pick payload_cart, keys
      cart.payment_method = payment_method

      cart.inStorePurchase = inStorePurchase if inStorePurchase
      cart.current_sub_tenant_nrads_id = current_sub_tenant_nrads_id if current_sub_tenant_nrads_id

      if body.tenant_email_prefix || body.tenant_email_from_name
        emailParams = {}
        emailParams.email_template_prefix = body.tenant_email_prefix if body.tenant_email_prefix
        emailParams.email_from_name = body.tenant_email_from_name if body.tenant_email_from_name
        cart.emailParams = emailParams

      #Payment Object
      paymemtObj = {
        authorize_net_data_descriptor: authorize_net_data_descriptor
        authorize_net_data_value: authorize_net_data_value
      }
      name = fullName if fullName
      name = nameOnAccount if nameOnAccount
      name = check_name if !name and check_name
      if name
        names = @parseName(name, true)
        paymemtObj.first_name = names.first_name if names.first_name
        paymemtObj.last_name = names.last_name if names.last_name
      paymemtObj.address = address1 if address1
      paymemtObj.city = city if city
      paymemtObj.state = state if state
      paymemtObj.postal = zip if zip
      paymemtObj.country = country if country

      cart.cart_entries = []
      for tCart_entry in payload.cart.shopping_cart_entries
        if (inStorePurchase)
          #Zero commissions for in store purchases
          tCart_entry.listing.commission_rbo = 0
          tCart_entry.listing.commission_rep = 0
        pricing_info = tCart_entry.pricing_info_hash #Pricing for single item
        #Listing Object
        listing = tCart_entry.listing
        if listing.class_name is "Course" or listing.class_name is "Rifle"
          if !listing.outfitter?
            if tenantId isnt VerdadTestTenantId
              listing.outfitter = {
                mongo_id: "595bb705e00d2a8ff5f09800" #Rolling Bones Outfitters SD100
              }
            else
              listing.outfitter.mongo_id = "5bd9e98083fdcc04e3c0a638"
        if !listing?.outfitter?.client_id and !listing?.outfitter?.mongo_id
          console.log "Error: missing outfitter or outfitter.client_id for this item."
          console.log "listing: ", listing
          result_failed.error = "Error: missing outfitter client_id for this item."
          return res.json result_failed, 500

        if listing?.class_name?.toLowerCase() is "rep"
          listing.type = "specialist"

        purchaseItem = _.pick tCart_entry, keys
        purchaseItem.cart_id = cart.id
        purchaseItem.imported = "RRADS"
        purchaseItem.paymentMethod = 'secure'
        purchaseItem.paymentUsed =  payment_method
        purchaseItem.basePrice = pricing_info.base_price
        purchaseItem.price_options = pricing_info.price_options
        purchaseItem.amountTotal = pricing_info.total_price
        purchaseItem.minPaymentRequired = pricing_info.minimum_payment
        purchaseItem.todays_payment = pricing_info.price_todays_payment
        purchaseItem.shipping = pricing_info.price_shipping
        purchaseItem.fee_processing = pricing_info.price_processing_fee
        purchaseItem.sales_tax = pricing_info.price_sales_tax
        purchaseItem.sales_tax_percentage = pricing_info.sales_tax_percentage
        purchaseItem.tags_licenses = pricing_info.price_tags_licenses
        purchaseItem.monthlyPaymentNumberMonths = pricing_info.months_count
        purchaseItem.monthlyPayment = 0
        purchaseItem.cc_email = payload_user.email
        purchaseItem.cc_phone = payload_user.phone_number
        purchaseItem.check_number = check_number if check_number
        purchaseItem.check_name = check_name if check_name
        purchaseItem.purchaseNotes = tCart_entry.notes
        purchaseItem.start_hunt_date = tCart_entry.start_hunt_date
        purchaseItem.userSnapShot = JSON.stringify(payload_user)
        purchaseItem.repAgreement = payload.agreement_text if payload.agreement_text
        if pricing_info.amortized_monthly_price
          purchaseItem.monthlyPayment = pricing_info.amortized_monthly_price
          purchaseItem.amortizedTotalAmount = pricing_info.amortized_total_amount
        purchaseItem.auto_renew = false #For anything that is not a membership or rep
        purchaseItem.auto_renew = true if tCart_entry.auto_renew_annually is true or listing?.class_name?.toLowerCase() is "rep"
        tCart_entry.notes
        if req.user.isMember
          purchaseItem.userIsMember = true
        else
          purchaseItem.userIsMember = false
        selected_options = tCart_entry.shopping_cart_entry_options #Selected options on purchase
        purchaseItemOptions = []
        for option in selected_options
          purchaseOption = {}
          purchaseOption.title = option.listing_option.listing_option_group.name         #Group Name
          purchaseOption.description = option.listing_option.listing_option_group.description   #Group Description
          purchaseOption.specific_type = option.listing_option.name #Selected Option Name
          purchaseOption.price = option.listing_option.price
          purchaseOption.commission = option.listing_option.commission_rbo
          purchaseItemOptions.push purchaseOption
        purchaseItem.options = purchaseItemOptions

        #Set purchase status
        if purchaseItem.authorize_automatic_payments
          purchaseItem.status = "auto-pay-monthly" #TODO: Implement auto-pay-yearly, or specified internval
        else
          purchaseItem.status = "invoiced"

        if purchaseItem.paymentUsed is "card" and purchaseItem.todays_payment >= purchaseItem.amountTotal
          purchaseItem.status = "paid-in-full"
        else if purchaseItem.paymentUsed is "check"
          purchaseItem.status = "check-pending"

        #Setup auto payments
        if purchaseItem.status is "auto-pay-monthly"
          today_plus_one_month = moment().add(1,'months')
          purchaseItem.next_payment_date = today_plus_one_month
          purchaseItem.next_payment_amount = purchaseItem.monthlyPayment

        for key, value of purchaseItem
          if typeof value is 'undefined'
            delete purchaseItem[key]

        cart_entry = {
          pricing_info: pricing_info
          purchaseItem: purchaseItem
          listing: listing
        }
        #Handle quantity by splitting them into individual separate entries
        for i in [0...tCart_entry.quantity]
          cart_entry_clone = _.clone(cart_entry)
          cart_entry_clone.purchaseItem = _.clone(cart_entry.purchaseItem)
          cart_entry_clone.pricing_info = _.clone(cart_entry.pricing_info)
          if i > 0
            shipping_quantity_discount = 0
            shipping_quantity_discount = cart_entry.pricing_info.price_shipping if cart_entry?.pricing_info?.price_shipping
            if shipping_quantity_discount
              cart_entry_clone.pricing_info.price_shipping = 0 if cart_entry_clone?.pricing_info
              cart_entry_clone.pricing_info.shipping = 0 if cart_entry_clone?.pricing_info?.shipping
              cart_entry_clone.pricing_info.price_total = cart_entry_clone.pricing_info.price_total - shipping_quantity_discount if cart_entry_clone?.pricing_info?.price_total
              cart_entry_clone.pricing_info.total_price = cart_entry_clone.pricing_info.total_price - shipping_quantity_discount if cart_entry_clone?.pricing_info?.total_price
              cart_entry_clone.pricing_info.price_sub_total = cart_entry_clone.pricing_info.price_sub_total - shipping_quantity_discount if cart_entry_clone?.pricing_info?.price_sub_total
              cart_entry_clone.pricing_info.price_todays_payment = cart_entry_clone.pricing_info.price_todays_payment - shipping_quantity_discount if cart_entry_clone?.pricing_info?.price_todays_payment
            shipping_quantity_discount = 0
            shipping_quantity_discount = cart_entry.purchaseItem.price_shipping if cart_entry?.purchaseItem?.price_shipping
            if shipping_quantity_discount
              cart_entry_clone.purchaseItem.price_shipping = 0 if cart_entry_clone?.purchaseItem
              cart_entry_clone.purchaseItem.shipping = 0 if cart_entry_clone?.purchaseItem
              cart_entry_clone.purchaseItem.price_todays_payment = cart_entry_clone.purchaseItem.price_todays_payment - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.price_todays_payment
              cart_entry_clone.purchaseItem.price_total = cart_entry_clone.purchaseItem.price_total - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.price_total
              cart_entry_clone.purchaseItem.amountTotal = cart_entry_clone.purchaseItem.amountTotal - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.amountTotal
              cart_entry_clone.purchaseItem.todays_payment = cart_entry_clone.purchaseItem.todays_payment - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.todays_payment
          cart.cart_entries.push cart_entry_clone
        #END FOR LOOP

      #Testing Stop and dump info
      if paymemtObj.postal is "00000"
        console.log "alert cart: ", cart
        i=0
        for cart_item in cart
          console.log "alert cart item..."
          console.log "alert cart item [#{i}]: ", cart_item.pricing_info, cart_item.purchaseItem, cart_item.listing
          i=i+1
        result_failed.error = "Running test stopped before purchase. See log file for details."
        result_failed.errorMsg = "Running test stopped before purchase. See log file for details."
        @captureError("purchase_create3: ", "ERROR forced", req)
        return res.json result_failed, 500

      upsertNRADSHuntCatalog = (cart_entry, done) =>
        @upsertHuntCatalogItem cart_entry.listing, tenantId, (err, tHuntCatalogItem) ->
          return done err, tHuntCatalogItem

      #Upsert hunt catalog items in NRADS
      async.mapSeries cart.cart_entries, upsertNRADSHuntCatalog, (err, results) =>
        if err
          result_failed.error = err
          result_failed.errorMsg = "Hunt Catalog item failed purchase update."
          @captureError("purchase_create3: upsertNRADSHuntCatalog()", err, req)
          return res.json result_failed, 500
        i = 0
        for result in results
          cart.cart_entries[i].huntCatalog = result
          i++

        async.waterfall [
          #Update the user info if it is missing
          (next) ->
            return next null unless payload_user?.mongo_id
            User.byId payload_user.mongo_id, {}, (err, nradsUser) ->
              return next err if err
              if (nradsUser.name isnt payload_user?.name) or (nradsUser.physical_address isnt payload_user?.physical_address?.address_1)
                nradsUser.first_name = payload_user.first_name if payload_user?.first_name
                nradsUser.last_name = payload_user.last_name if payload_user?.last_name
                nradsUser.name = payload_user.name if payload_user?.name
                nradsUser.phone_number = payload_user.phone_number if payload_user?.phone_number
                nradsUser.physical_address = payload_user.physical_address.address_1 if payload_user?.physical_address?.address_1
                nradsUser.physical_city = payload_user.physical_address.city if payload_user?.physical_address?.city
                nradsUser.physical_country = payload_user.physical_address.country if payload_user?.physical_address?.country
                nradsUser.physical_postal = payload_user.physical_address.zip if payload_user?.physical_address?.zip
                nradsUser.physical_state = payload_user.physical_address.state if payload_user?.physical_address?.state
                User.upsert nradsUser, {internal: false, upsert: false}, (err, tUser) ->
                  return next err, nradsUser
              else
                return next null, nradsUser

          #For some reason, the user returned on previous user update calls isn't overriding the in memory user so get it clean
          (user, next) ->
            User.byId user._id, {}, (err, cleanUser) ->
              return next err, cleanUser

        ], (err, user) =>
          @captureError("purchase_from_rrads", err, req) if err
          return res.json {error: err}, 500 if err
          huntCatalogs.record_rrads_purchase user, cart, purchaseResponse, (err, results) =>
            console.log "Alert DB: returned from huntCatalogs.record_rrads_purchase with: ", err, results
            if err
              result_failed.error = err
              if err.errorMsg
                result_failed.errorMsg = err.errorMsg
              else if err.message
                result_failed.errorMsg = err.message
              @captureError("purchase_from_rrads: huntCatalogs.record_rrads_purchase", err, req) if err
              api_rbo_rrads.return_pending_process result_failed, (err, result_failed) ->
                console.log "Error: api_rbo_rrads.user_upsert_rads: ", err if err
              return res.json result_failed, 500
            if results
              result_success.results = results
              result_success.purchase_id = results[0].purchaseId if results?.length
              if payload.opt_out_subscription and payload.type is "membership"
                message = "Membership with OPT OUT purchased for: '#{user.name}', clientId: '#{user.clientId}', userId: '#{user._id}'"
                @sendServerEmail "Membership OPT OUT", "api_rbo.purchase_from_rrads()", message
              api_rbo_rrads.return_pending_process result_success, (err, result_success) ->
                console.log "Error: api_rbo_rrads.user_upsert_rads: ", err if err
              return res.json result_success

    #Create purchase version 2 shopping cart
    purchase_create3: (req, res) ->
      console.log "Alert DB: purchase_create3  with req.body.pending_process_uid: ",  req.body.pending_process_uid
      #return res.json {error: "Purchasing is temporarily unavailable.  Please try again later."}, 401
      @log(req)
      apitoken = req.param('token')
      apitoken = req.param('token')
      tenantId = req.param('tenantId')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body

      #Top level
      pending_process_uid = req.body.pending_process_uid
      clientId = req.body.clientId
      authorize_net_data_descriptor = req.body.authorize_net_data_descriptor
      authorize_net_data_value = req.body.authorize_net_data_value
      fullName = req.body.fullName if req.body.fullName
      nameOnAccount = req.body.nameOnAccount if req.body.nameOnAccount
      zip = req.body.zip if req.body.zip
      payment_method = req.body.payment_method if req.body.payment_method
      check_name = req.body.check_name if req.body.check_name
      check_number = req.body.check_number if req.body.check_number
      address1 = req.body.address1 if req.body.address1
      address2 = req.body.address2 if req.body.address2
      country = req.body.country if req.body.country
      state = req.body.state if req.body.state
      city = req.body.city if req.body.city
      inStorePurchase = req.body.sub_tenant_store_only if req.body.sub_tenant_store_only is true
      current_sub_tenant_nrads_id = req.body.current_sub_tenant_nrads_id if req.body.current_sub_tenant_nrads_id

      #CHECK IF SHORTCUT PAY BY CASH OR CHECK:
      if fullName?.toLowerCase().indexOf("*cash") > -1
        payment_method = "cash"
        tCashInfo = fullName.split(" ")
        cash_name = ""
        count = 0
        for piece in tCashInfo
          cash_name = "#{cash_name} #{piece}" if count > 0
          count++
        cash_name = cash_name.trim()
        nameOnAccount = cash_name if cash_name
      else if fullName?.toLowerCase().indexOf("*check") > -1
        payment_method = "check"
        tCheckInfo = fullName.split(" ")
        check_number = ""
        check_name = ""
        count = 0
        for piece in tCheckInfo
          check_number = piece if count is 1
          check_name = "#{check_name} #{piece}" if count > 1
          count++
        check_number = check_number.trim()
        check_name = check_name.trim()
        nameOnAccount = check_name if check_name

      result_success = {
        status: "successful"
        pending_process_uid: pending_process_uid
        tenantId: tenantId
      }
      result_failed = {
        error: ""
        status: "failed"
        pending_process_uid: pending_process_uid
        tenantId: tenantId
      }
      if inStorePurchase and current_sub_tenant_nrads_id
        result_success.tenantId = current_sub_tenant_nrads_id
        result_success.inStorePurchase = inStorePurchase if inStorePurchase
        result_failed.tenantId = current_sub_tenant_nrads_id

      #Required fields in order to submit a purchase request
      return res.json {error: "Bad Request missing pending_process_uid"}, 400 unless pending_process_uid
      return res.json {error: "Bad Request missing clientId"}, 400 unless clientId
      return res.json {error: "Bad Request missing authorize_net_data_descriptor"}, 400 unless authorize_net_data_descriptor
      return res.json {error: "Bad Request missing authorize_net_data_value"}, 400 unless authorize_net_data_value
      return res.json {error: "Bad Request missing or invalid payment_method"}, 400 unless payment_method and (payment_method is "card" or payment_method is "bank" or payment_method is "cash" or payment_method is "check")

      if payment_method is "card"
        return res.json {error: "Bad Request missing fullName"}, 400 unless fullName
        return res.json {error: "Bad Request missing address1"}, 400 unless address1
        return res.json {error: "Bad Request missing country"}, 400 unless country
        return res.json {error: "Bad Request missing state"}, 400 unless state
        return res.json {error: "Bad Request missing city"}, 400 unless city
        return res.json {error: "Bad Request missing zip"}, 400 unless zip
      else
        return res.json {error: "Bad Request missing nameOnAccount"}, 400 unless nameOnAccount or check_name

      #Payload level
      payload = req.body.payload
      payload_cart = payload.cart
      payload_user = payload.user
      keys = [
        'id'
        'price_todays_payment',
        'price_total','price_processing_fee',
        'price_shipping',
        'price_tags_licenses',
        'price_options',
        'price_sales_tax'
        'start_hunt_date'
        'authorize_automatic_payments'
      ]
      cart = _.pick payload_cart, keys
      cart.payment_method = payment_method

      cart.inStorePurchase = inStorePurchase if inStorePurchase
      cart.current_sub_tenant_nrads_id = current_sub_tenant_nrads_id if current_sub_tenant_nrads_id

      if body.tenant_email_prefix || body.tenant_email_from_name
        emailParams = {}
        emailParams.email_template_prefix = body.tenant_email_prefix if body.tenant_email_prefix
        emailParams.email_from_name = body.tenant_email_from_name if body.tenant_email_from_name
        cart.emailParams = emailParams

      #Payment Object
      paymemtObj = {
        authorize_net_data_descriptor: authorize_net_data_descriptor
        authorize_net_data_value: authorize_net_data_value
      }
      name = fullName if fullName
      name = nameOnAccount if nameOnAccount
      name = check_name if !name and check_name
      if name
        names = @parseName(name, true)
        paymemtObj.first_name = names.first_name if names.first_name
        paymemtObj.last_name = names.last_name if names.last_name
      paymemtObj.address = address1 if address1
      paymemtObj.city = city if city
      paymemtObj.state = state if state
      paymemtObj.postal = zip if zip
      paymemtObj.country = country if country

      cart.cart_entries = []
      for tCart_entry in payload.cart.shopping_cart_entries
        if (inStorePurchase)
          #Zero commissions for in store purchases
          tCart_entry.listing.commission_rbo = 0
          tCart_entry.listing.commission_rep = 0
        pricing_info = tCart_entry.pricing_info_hash #Pricing for single item
        #Listing Object
        listing = tCart_entry.listing
        if listing.class_name is "Course" or listing.class_name is "Rifle"
          if !listing.outfitter?
            if tenantId isnt VerdadTestTenantId
              listing.outfitter = {
                mongo_id: "595bb705e00d2a8ff5f09800" #Rolling Bones Outfitters SD100
              }
            else
              listing.outfitter.mongo_id = "5bd9e98083fdcc04e3c0a638"
        if !listing?.outfitter?.client_id and !listing?.outfitter?.mongo_id
          console.log "Error: missing outfitter or outfitter.client_id for this item."
          console.log "listing: ", listing
          result_failed.error = "Error: missing outfitter client_id for this item."
          return res.json result_failed, 500

        if listing?.class_name?.toLowerCase() is "rep"
          listing.type = "specialist"

        purchaseItem = _.pick tCart_entry, keys
        purchaseItem.cart_id = cart.id
        purchaseItem.imported = "RRADS"
        purchaseItem.paymentMethod = 'secure'
        purchaseItem.paymentUsed =  payment_method
        purchaseItem.basePrice = pricing_info.base_price
        purchaseItem.price_options = pricing_info.price_options
        purchaseItem.amountTotal = pricing_info.total_price
        purchaseItem.minPaymentRequired = pricing_info.minimum_payment
        purchaseItem.todays_payment = pricing_info.price_todays_payment
        purchaseItem.shipping = pricing_info.price_shipping
        purchaseItem.fee_processing = pricing_info.price_processing_fee
        purchaseItem.sales_tax = pricing_info.price_sales_tax
        purchaseItem.sales_tax_percentage = pricing_info.sales_tax_percentage
        purchaseItem.tags_licenses = pricing_info.price_tags_licenses
        purchaseItem.monthlyPaymentNumberMonths = pricing_info.months_count
        purchaseItem.monthlyPayment = 0
        purchaseItem.cc_email = payload_user.email
        purchaseItem.cc_phone = payload_user.phone_number
        purchaseItem.check_number = check_number if check_number
        purchaseItem.check_name = check_name if check_name
        purchaseItem.purchaseNotes = tCart_entry.notes
        purchaseItem.start_hunt_date = tCart_entry.start_hunt_date
        purchaseItem.userSnapShot = JSON.stringify(payload_user)
        purchaseItem.repAgreement = payload.agreement_text if payload.agreement_text
        if pricing_info.amortized_monthly_price
          purchaseItem.monthlyPayment = pricing_info.amortized_monthly_price
          purchaseItem.amortizedTotalAmount = pricing_info.amortized_total_amount
        purchaseItem.auto_renew = false #For anything that is not a membership or rep
        purchaseItem.auto_renew = true if tCart_entry.auto_renew_annually is true or listing?.class_name?.toLowerCase() is "rep"
        tCart_entry.notes
        if req.user.isMember
          purchaseItem.userIsMember = true
        else
          purchaseItem.userIsMember = false
        selected_options = tCart_entry.shopping_cart_entry_options #Selected options on purchase
        purchaseItemOptions = []
        for option in selected_options
          purchaseOption = {}
          purchaseOption.title = option.listing_option.listing_option_group.name         #Group Name
          purchaseOption.description = option.listing_option.listing_option_group.description   #Group Description
          purchaseOption.specific_type = option.listing_option.name #Selected Option Name
          purchaseOption.price = option.listing_option.price
          purchaseOption.commission = option.listing_option.commission_rbo
          purchaseItemOptions.push purchaseOption
        purchaseItem.options = purchaseItemOptions

        #Set purchase status
        if purchaseItem.authorize_automatic_payments
          purchaseItem.status = "auto-pay-monthly" #TODO: Implement auto-pay-yearly, or specified internval
        else
          purchaseItem.status = "invoiced"

        if purchaseItem.paymentUsed is "card" and purchaseItem.todays_payment >= purchaseItem.amountTotal
          purchaseItem.status = "paid-in-full"
        else if purchaseItem.paymentUsed is "check"
          purchaseItem.status = "check-pending"

        #Setup auto payments
        if purchaseItem.status is "auto-pay-monthly"
          today_plus_one_month = moment().add(1,'months')
          purchaseItem.next_payment_date = today_plus_one_month
          purchaseItem.next_payment_amount = purchaseItem.monthlyPayment

        for key, value of purchaseItem
          if typeof value is 'undefined'
            delete purchaseItem[key]

        cart_entry = {
          pricing_info: pricing_info
          purchaseItem: purchaseItem
          listing: listing
        }
        #Handle quantity by splitting them into individual separate entries
        for i in [0...tCart_entry.quantity]
          cart_entry_clone = _.clone(cart_entry)
          cart_entry_clone.purchaseItem = _.clone(cart_entry.purchaseItem)
          cart_entry_clone.pricing_info = _.clone(cart_entry.pricing_info)
          if i > 0
            shipping_quantity_discount = 0
            shipping_quantity_discount = cart_entry.pricing_info.price_shipping if cart_entry?.pricing_info?.price_shipping
            if shipping_quantity_discount
              cart_entry_clone.pricing_info.price_shipping = 0 if cart_entry_clone?.pricing_info
              cart_entry_clone.pricing_info.shipping = 0 if cart_entry_clone?.pricing_info?.shipping
              cart_entry_clone.pricing_info.price_total = cart_entry_clone.pricing_info.price_total - shipping_quantity_discount if cart_entry_clone?.pricing_info?.price_total
              cart_entry_clone.pricing_info.total_price = cart_entry_clone.pricing_info.total_price - shipping_quantity_discount if cart_entry_clone?.pricing_info?.total_price
              cart_entry_clone.pricing_info.price_sub_total = cart_entry_clone.pricing_info.price_sub_total - shipping_quantity_discount if cart_entry_clone?.pricing_info?.price_sub_total
              cart_entry_clone.pricing_info.price_todays_payment = cart_entry_clone.pricing_info.price_todays_payment - shipping_quantity_discount if cart_entry_clone?.pricing_info?.price_todays_payment
            shipping_quantity_discount = 0
            shipping_quantity_discount = cart_entry.purchaseItem.price_shipping if cart_entry?.purchaseItem?.price_shipping
            if shipping_quantity_discount
              cart_entry_clone.purchaseItem.price_shipping = 0 if cart_entry_clone?.purchaseItem
              cart_entry_clone.purchaseItem.shipping = 0 if cart_entry_clone?.purchaseItem
              cart_entry_clone.purchaseItem.price_todays_payment = cart_entry_clone.purchaseItem.price_todays_payment - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.price_todays_payment
              cart_entry_clone.purchaseItem.price_total = cart_entry_clone.purchaseItem.price_total - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.price_total
              cart_entry_clone.purchaseItem.amountTotal = cart_entry_clone.purchaseItem.amountTotal - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.amountTotal
              cart_entry_clone.purchaseItem.todays_payment = cart_entry_clone.purchaseItem.todays_payment - shipping_quantity_discount if cart_entry_clone?.purchaseItem?.todays_payment
          cart.cart_entries.push cart_entry_clone
        #END FOR LOOP

      #Testing Stop and dump info
      if paymemtObj.postal is "00000"
        console.log "alert cart: ", cart
        i=0
        for cart_item in cart
          console.log "alert cart item..."
          console.log "alert cart item [#{i}]: ", cart_item.pricing_info, cart_item.purchaseItem, cart_item.listing
          i=i+1
        result_failed.error = "Running test stopped before purchase. See log file for details."
        result_failed.errorMsg = "Running test stopped before purchase. See log file for details."
        @captureError("purchase_create3: ", "ERROR forced", req)
        return res.json result_failed, 500

      upsertNRADSHuntCatalog = (cart_entry, done) =>
        @upsertHuntCatalogItem cart_entry.listing, tenantId, (err, tHuntCatalogItem) ->
          return done err, tHuntCatalogItem

      #Upsert hunt catalog items in NRADS
      async.mapSeries cart.cart_entries, upsertNRADSHuntCatalog, (err, results) =>
        if err
          result_failed.error = err
          result_failed.errorMsg = "Hunt Catalog item failed purchase update."
          @captureError("purchase_create3: upsertNRADSHuntCatalog()", err, req)
          return res.json result_failed, 500
        i = 0
        for result in results
          cart.cart_entries[i].huntCatalog = result
          i++

        async.waterfall [
          #Update the user info if it is missing
          (next) ->
            return next null unless payload_user?.mongo_id
            User.byId payload_user.mongo_id, {}, (err, nradsUser) ->
              return next err if err
              if (nradsUser.name isnt payload_user?.name) or (nradsUser.physical_address isnt payload_user?.physical_address?.address_1)
                nradsUser.first_name = payload_user.first_name if payload_user?.first_name
                nradsUser.last_name = payload_user.last_name if payload_user?.last_name
                nradsUser.name = payload_user.name if payload_user?.name
                nradsUser.phone_number = payload_user.phone_number if payload_user?.phone_number
                nradsUser.physical_address = payload_user.physical_address.address_1 if payload_user?.physical_address?.address_1
                nradsUser.physical_city = payload_user.physical_address.city if payload_user?.physical_address?.city
                nradsUser.physical_country = payload_user.physical_address.country if payload_user?.physical_address?.country
                nradsUser.physical_postal = payload_user.physical_address.zip if payload_user?.physical_address?.zip
                nradsUser.physical_state = payload_user.physical_address.state if payload_user?.physical_address?.state
                User.upsert nradsUser, {internal: false, upsert: false}, (err, tUser) ->
                  return next err
              else
                return next null

          #Upsert authorize.net customer profile
          (next) =>
            return next null, req.user if cart.payment_method is "cash" or cart.payment_method is "check"  or cart.renewal_only or cart.auto_payment
            authorizenetapi.upsertCustomerProfile req.user, (err, user) ->
              return next err, user

          #Upsert authorize.net payment profile
          (user, next) =>
            return next null, user if cart.payment_method is "cash" or cart.payment_method is "check"  or cart.renewal_only or cart.auto_payment
            authorizenetapi.upsertPaymentProfile user, paymemtObj, false, (err, user) ->
              return next err, user

          #For some reason, the user returned on previous user update calls isn't overriding the in memory user so get it clean
          (user, next) ->
            User.byId user._id, {}, (err, cleanUser) ->
              return next err, cleanUser

        ], (err, user) =>
          @captureError("purchase_create3", err, req) if err
          return res.json {error: err}, 500 if err
          #NOTE: If needed, I can job the purchase3 call and imeediatly return the api call.  The the jobbed purchase3() call when done will call pending process return call.
          huntCatalogs.purchase3 user, cart, (err, results) =>
            console.log "Alert DB: returned from huntCatalogs.purchase3 with: ", err, results
            if err
              result_failed.error = err
              if err.errorMsg
                result_failed.errorMsg = err.errorMsg
              else if err.message
                result_failed.errorMsg = err.message
              @captureError("purchase_create3: huntCatalogs.purchase3", err, req) if err
              api_rbo_rrads.return_pending_process result_failed, (err, result_failed) ->
                console.log "Error: api_rbo_rrads.user_upsert_rads: ", err if err
              return res.json result_failed, 500
            if results
              result_success.results = results
              result_success.purchase_id = results[0].purchaseId if results?.length
              if payload.opt_out_subscription and payload.type is "membership"
                message = "Membership with OPT OUT purchased for: '#{user.name}', clientId: '#{user.clientId}', userId: '#{user._id}'"
                @sendServerEmail "Membership OPT OUT", "api_rbo.purchase_create3()", message
              api_rbo_rrads.return_pending_process result_success, (err, result_success) ->
                console.log "Error: api_rbo_rrads.user_upsert_rads: ", err if err
              return res.json result_success


    purchase_create3_direct: (payload, cb) ->
      console.log "Alert DB: purchase_create3_direct() called"
      tenantId = payload.tenantId
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = payload

      if payload.authorize_net_data_descriptor
        authorize_net_data_descriptor = payload.authorize_net_data_descriptor
      else
        authorize_net_data_descriptor = "n/a"

      if payload.authorize_net_data_value
        authorize_net_data_value = payload.authorize_net_data_value
      else
        authorize_net_data_value = "n/a"

      pending_process_uid = "n/a"

      #Top level
      clientId = body.clientId
      fullName = body.fullName if body.fullName
      nameOnAccount = body.nameOnAccount if body.nameOnAccount
      zip = body.zip if body.zip
      payment_method = body.payment_method if body.payment_method
      address1 = body.address1 if body.address1
      address2 = body.address2 if body.address2
      country = body.country if body.country
      state = body.state if body.state
      city = body.city if body.city
      payment_method = body.payment_method

      result_success = {
        status: "successful"
        tenantId: tenantId
      }
      result_failed = {
        error: ""
        status: "failed"
        tenantId: tenantId
      }

      #Required fields in order to submit a purchase request
      return cb {error: "Bad Request missing pending_process_uid"}, 400 unless pending_process_uid
      return cb {error: "Bad Request missing clientId"}, 400 unless clientId
      return cb {error: "Bad Request missing authorize_net_data_descriptor"}, 400 unless authorize_net_data_descriptor
      return cb {error: "Bad Request missing authorize_net_data_value"}, 400 unless authorize_net_data_value
      return cb {error: "Bad Request missing or invalid payment_method"}, 400 unless payment_method and (payment_method is "card" or payment_method is "bank" or payment_method is "cash" or payment_method is "check" or payment_method is "auto-pay-card")

      if payment_method is "card"
        return cb {error: "Bad Request missing fullName"}, 400 unless fullName
        return cb {error: "Bad Request missing address1"}, 400 unless address1
        return cb {error: "Bad Request missing country"}, 400 unless country
        return cb {error: "Bad Request missing state"}, 400 unless state
        return cb {error: "Bad Request missing city"}, 400 unless city
        return cb {error: "Bad Request missing zip"}, 400 unless zip
      else
        return cb {error: "Bad Request missing nameOnAccount"}, 400 unless nameOnAccount

      #Payload level
      payload_cart = payload.cart
      payload_user = payload.user
      keys = [
        'id'
        'price_todays_payment',
        'price_total','price_processing_fee',
        'price_shipping',
        'price_tags_licenses',
        'price_options',
        'price_sales_tax',
        'renewal_only'
        'auto_payment'
        'send_email_sync'
        'do_not_send_email'
        'opt_out_subscription'
      ]
      cart = _.pick payload_cart, keys
      cart.payment_method = payment_method

      emailParams = null
      if payload.tenant_email_from_name || payload.tenant_email_prefix
        emailParams = {}
        emailParams.email_from_name  = payload.tenant_email_from_name if payload.tenant_email_from_name
        emailParams.email_template_prefix = payload.tenant_email_prefix if payload.tenant_email_prefix
        cart.emailParams = emailParams

      #Payment Object
      paymemtObj = {
        authorize_net_data_descriptor: authorize_net_data_descriptor
        authorize_net_data_value: authorize_net_data_value
      }
      name = fullName if fullName
      name = nameOnAccount if nameOnAccount
      if name
        names = @parseName(name, true)
        paymemtObj.first_name = names.first_name if names.first_name
        paymemtObj.last_name = names.last_name if names.last_name
      paymemtObj.address = address1 if address1
      paymemtObj.city = city if city
      paymemtObj.state = state if state
      paymemtObj.postal = zip if zip
      paymemtObj.country = country if country

      cart.cart_entries = []
      for tCart_entry in payload.cart.shopping_cart_entries
        pricing_info = tCart_entry.pricing_info_hash #Pricing for single item

        #Listing Object
        listing = tCart_entry.listing
        if listing.class_name is "Course" or listing.class_name is "Rifle"
          if !listing.outfitter?
            if tenantId isnt VerdadTestTenantId
              listing.outfitter = {
                mongo_id: "595bb705e00d2a8ff5f09800" #Rolling Bones Outfitters SD100
              }
            else
              listing.outfitter.mongo_id = "5bd9e98083fdcc04e3c0a638"
        else if listing.class_name is "rbo"
          if !listing.outfitter?
            if tenantId isnt VerdadTestTenantId
              listing.outfitter = {
                mongo_id: "595bb705e00d2a8ff5f09800" #Rolling Bones Outfitters SD100
              }
            else
              listing.outfitter.mongo_id = "5bd9e98083fdcc04e3c0a638"
        else if listing.class_name is "oss"
          if !listing.outfitter?.client_id and !listing.outfitter?.mongo_id
            if tenantId isnt VerdadTestTenantId
              listing.outfitter = {
                mongo_id: "5e1dfc1a01d227bd8e0c3ebd" #Outdoor Software Solutions RBOSS
              }
            else
              listing.outfitter.mongo_id = "5bd9e98083fdcc04e3c0a638"

        if !listing?.outfitter?.client_id and !listing?.outfitter?.mongo_id
          console.log "Error: missing outfitter or outfitter.client_id for this item."
          console.log "listing: ", listing
          result_failed.error = "Error: missing outfitter client_id for this item."
          return cb result_failed, 500

        if listing?.class_name?.toLowerCase() is "rep"
          listing.type = "specialist"

        purchaseItem = _.pick tCart_entry, keys
        purchaseItem.cart_id = cart.id
        purchaseItem.imported = "RRADS"
        purchaseItem.paymentMethod = 'secure'
        purchaseItem.paymentUsed =  payment_method
        purchaseItem.basePrice = pricing_info.base_price
        purchaseItem.price_options = pricing_info.price_options
        purchaseItem.amountTotal = pricing_info.total_price
        purchaseItem.minPaymentRequired = pricing_info.minimum_payment
        purchaseItem.todays_payment = pricing_info.price_todays_payment
        purchaseItem.shipping = pricing_info.price_shipping
        purchaseItem.fee_processing = pricing_info.price_processing_fee
        purchaseItem.sales_tax = pricing_info.price_sales_tax
        purchaseItem.sales_tax_percentage = pricing_info.sales_tax_percentage
        purchaseItem.tags_licenses = pricing_info.price_tags_licenses
        purchaseItem.monthlyPaymentNumberMonths = pricing_info.months_count
        purchaseItem.monthlyPayment = 0
        purchaseItem.cc_email = payload_user.email
        purchaseItem.cc_phone = payload_user.phone_number
        purchaseItem.check_number = payload.check_number if payload.check_number
        purchaseItem.check_name = payload.check_name if payload.check_name
        purchaseItem.purchaseNotes = tCart_entry.notes
        purchaseItem.userSnapShot = JSON.stringify(payload_user)
        purchaseItem.repAgreement = payload.agreement_text if payload.agreement_text
        purchaseItem.applyTo_purchaseId = payload.applyTo_purchaseId if payload.applyTo_purchaseId
        purchaseItem.applyTo_invoiceNumber = payload.applyTo_invoiceNumber if payload.applyTo_invoiceNumber
        if pricing_info.amortized_monthly_price
          purchaseItem.monthlyPayment = pricing_info.amortized_monthly_price
          purchaseItem.amortizedTotalAmount = pricing_info.amortized_total_amount
        purchaseItem.auto_renew = false #For anything that is not a membership or rep
        #TODO: NOT CORRECT LOGIC IF MEMBERSHIP PATH MAYBE
        purchaseItem.auto_renew = true if tCart_entry.auto_renew_annually is true or listing?.class_name?.toLowerCase() is "rep"
        purchaseItem.auto_renew = true if tCart_entry.auto_renew is true
        purchaseItem.opt_out_subscription = tCart_entry.opt_out_subscription if tCart_entry.opt_out_subscription
        selected_options = tCart_entry.shopping_cart_entry_options #Selected options on purchase
        purchaseItemOptions = []
        for option in selected_options
          purchaseOption = {}
          purchaseOption.title = option.listing_option.listing_option_group.name         #Group Name
          purchaseOption.description = option.listing_option.listing_option_group.description   #Group Description
          purchaseOption.specific_type = option.listing_option.name #Selected Option Name
          purchaseOption.price = option.listing_option.price
          purchaseOption.commission = option.listing_option.commission_rbo
          purchaseItemOptions.push purchaseOption
        purchaseItem.options = purchaseItemOptions

        #Set purchase status
        if purchaseItem.auto_renew and tCart_entry.purchaseStatus?.length
          purchaseItem.status = tCart_entry.purchaseStatus #auto-pay-monthly, or auto-pay-yearly
        else if purchaseItem.authorize_automatic_payments
          #authorize_automatice_payments is a checkbox only if a layaway plan was chosen.
          purchaseItem.status = "auto-pay-monthly"
        else if purchaseItem.paymentUsed is "card" and purchaseItem.todays_payment >= purchaseItem.amountTotal
          purchaseItem.status = "paid-in-full"
        else if purchaseItem.paymentUsed is "check"
          purchaseItem.status = "check-pending"
        else
          purchaseItem.status = "invoiced"

        for key, value of purchaseItem
          if typeof value is 'undefined'
            delete purchaseItem[key]

        cart_entry = {
          pricing_info: pricing_info
          purchaseItem: purchaseItem
          listing: listing
        }
        #Handle quantity by splitting them into individual separate entries
        for i in [0...tCart_entry.quantity]
          cart_entry_clone = _.clone(cart_entry)
          cart_entry_clone.purchaseItem = _.clone(cart_entry.purchaseItem)
          cart.cart_entries.push cart_entry_clone
      #END FOR LOOP

      #Testing Stop and dump info
      if paymemtObj.postal is "00000"
        console.log "cart: ", cart
        result_failed.error = "Running test stopped before purchase. See log file for details."
        result_failed.errorMsg = "Running test stopped before purchase. See log file for details."
        @captureError("purchase_create3: ", err, payload) if err
        return cb result_failed, 500

      upsertNRADSHuntCatalog = (cart_entry, done) =>
        @upsertHuntCatalogItem cart_entry.listing, tenantId, (err, tHuntCatalogItem) ->
          return done err, tHuntCatalogItem

      #Upsert hunt catalog items in NRADS
      async.mapSeries cart.cart_entries, upsertNRADSHuntCatalog, (err, results) =>
        if err
          result_failed.error = err
          result_failed.errorMsg = "Hunt Catalog item failed purchase update."
          @captureError("purchase_create3_direct: upsertNRADSHuntCatalog()", err, payload)
          return cb result_failed, 500
        i = 0
        for result in results
          cart.cart_entries[i].huntCatalog = result
          i++

        async.waterfall [

          (next) =>
            User.byId payload_user._id, {}, (err, user) ->
              return next err, user

          #Upsert authorize.net customer profile
          (user, next) =>
            return next null, user if cart.payment_method is "cash" or cart.payment_method is "check" or cart.renewal_only or cart.auto_payment
            authorizenetapi.upsertCustomerProfile user, (err, user) ->
              return next err, user

          #Upsert authorize.net payment profile
          (user, next) =>
            return next null, user if cart.payment_method is "cash" or cart.payment_method is "check" or cart.renewal_only or cart.auto_payment
            authorizenetapi.upsertPaymentProfile user, paymemtObj, false, (err, user) ->
              return next err, user

          #If payment_recurring_paymentProfileId is empty, set it from the current customer payment profile.
          (user, next) =>
            return next null, user unless cart.renewal_only or cart.auto_payment
            return next null, user if user.payment_recurring_paymentProfileId
            return next "Customer missing paymentProfileId, userId: #{user._id}" unless user.payment_paymentProfileId
            userData = {
              _id: user._id
              payment_recurring_paymentProfileId: user.payment_paymentProfileId
            }
            User.upsert userData, {}, (err, user) ->
              return next err, user

        ], (err, user) =>
          @captureError("purchase_create3", err, payload) if err
          return cb {error: err}, 500 if err
          #NOTE: If needed, I can job the purchase3 call and imeediatly return the api call.  The the jobbed purchase3() call when done will call pending process return call.
          huntCatalogs.purchase3 user, cart, (err, results) =>
            if err
              result_failed.error = err
              if err.errorMsg
                result_failed.errorMsg = err.errorMsg
              else if err.message
                result_failed.errorMsg = err.message
              @captureError("purchase_create3: huntCatalogs.purchase3", err, payload) if err
              return cb result_failed, 500
            if results
              result_success.results = results
              result_success.purchase_id = results[0].purchaseId if results?.length
              if payload.opt_out_subscription and payload.type is "membership"
                message = "Membership with OPT OUT purchased for: '#{user.name}', clientId: '#{user.clientId}', userId: '#{user._id}'"
                @sendServerEmail "Membership OPT OUT", "api_rbo.purchase_create3()", message
              return cb null, result_success

    #Create purchase: Wrap to call @purchase_create3 or @purchase_create3_direct to handle membership purchases
    purchase_create: (req, res) ->
      if req?.body?.type is "Cart"
        @purchase_create3(req, res)
        return
      else if req?.body?.type is "membership"
        @log(req)
        return res.json {error: "Missing required fields."}, 401 unless req?.body
        tenantId = req.param('tenantId')
        return res.json {error: "Missing tenant."}, 500 if tenantId isnt RollingBonesTenantId and tenantId isnt VerdadTestTenantId #Not quite ready for all tenants.  Need to assign outfitter in some way to save the listing
        Tenant.findById tenantId, (err, tenant) =>
          return res.json err, 401 if err
          return res.json {error: "Missing tenant."}, 401 unless tenant
          pending_process_uid = req.body.pending_process_uid
          rrads_membership_id = req.body.membership_id
          membership_features = req.body.membership_features
          user = req.body.payload.user
          payload = req.body
          payload.membership_group = "membership" if payload.membership_group is "rbo"
          #clean up the payload object
          delete payload.membership_features
          delete payload.payload

          #only passed in if membership was opt in auto renew annual.  Monthly is always auto_renew
          if payload.membership_billing_cycle is 'yearly'
            auto_renew = false
            auto_renew_annually = false
            opt_out_subscription = true
            if payload.auto_renew_annually?
              if payload.auto_renew_annually is true
                auto_renew_annually = true
                auto_renew = true
                opt_out_subscription = false
          else
            auto_renew = true #for now, all purchases initiated from the new rrads membership pages are set to auto_renew

          #handle pay by check
          if payload.payment_method is "check"
            payload.nameOnAccount = payload.check_name

          totalPrice = parseFloat(payload.amount)
          totalPrice += parseFloat(payload.sales_tax) if payload.sales_tax
          totalPrice = parseFloat(totalPrice.toFixed(2))
          payload.tenantId = tenantId
          payload.cart = {}
          payload.user = user
          #payload.cart.id = xxxx
          payload.cart.price_todays_payment = totalPrice
          payload.cart.price_total = totalPrice
          payload.cart.price_processing_fee = 0
          payload.cart.price_shipping = 0
          payload.cart.price_tags_licenses = 0
          payload.cart.price_options = 0
          payload.cart.price_sales_tax = 0
          payload.cart.renewal_only = false
          payload.cart.auto_payment = false
          payload.cart.send_email_sync = false
          payload.cart.do_not_send_email = false
          payload.cart.shopping_cart_entries = []
          listing = {}
          listing.membership_group = payload.membership_group
          listing.specific_type = payload.membership_group
          listing.class_name = payload.membership_group
          listing.type = payload.membership_group
          listing.payment_plan = payload.membership_billing_cycle
          listing.status = "available"
          listing.price_member = payload.amount
          listing.price_non_member = payload.amount
          listing.price_processing_fee = 0
          listing.commission_rbo = payload.amount
          listing.commission_rep = payload.commission_rep
          listing.price_total = payload.amount
          listing.price_non_commissionable = 0
          listing.price_commissionable = payload.amount
          listing.price_rep_commissionable = payload.amount
          listing.price_description = ""
          listing.refund_policy = "Your subscription can be cancelled at anytime by contacting us."
          listing.createMemberType = payload.membership_name.toLowerCase() if payload.membership_name

          now = new Date()
          listing.updated_at = now
          listing.created_at = now
          abrName = payload.membership_name.replace(/[^a-z0-9+]+/gi, '') #strip all non alpha chars
          if payload.membership_group is "membership"
            catalog_id = "#{tenant.clientPrefix}MBR-#{abrName}"
          else
            catalog_id = "#{tenant.clientPrefix}#{payload.membership_group}-#{abrName}"
          listing.catalog_id = catalog_id.toUpperCase()
          listing.outfitter = {}
          description = ""
          for feature in membership_features
            description += "#{feature.name}\n"
          listing.description = description
          if payload.membership_group is "oss"
            listing.title = "OSS #{payload.membership_name}"
            listing.outfitter.client_id = "RBOSS"
          else
            listing.title = "Membership #{payload.membership_name}"
            listing.outfitter.client_id = "RB2979"
            listing.outfitter.client_id ="VD1" if tenantId is VerdadTestTenantId

          pricing_info_hash = {}
          pricing_info_hash.base_price = payload.amount
          pricing_info_hash.price_options = 0
          pricing_info_hash.total_price = totalPrice
          pricing_info_hash.minimum_payment = payload.amount
          pricing_info_hash.price_todays_payment = totalPrice
          pricing_info_hash.price_shipping = 0
          pricing_info_hash.price_processing_fee = 0
          pricing_info_hash.price_sales_tax = payload.sales_tax
          pricing_info_hash.price_tags_licenses = 0
          entry = {
            pricing_info_hash: pricing_info_hash
            listing: listing
            shopping_cart_entry_options: []
            quantity: 1
            auto_renew: auto_renew
          }
          if payload.membership_billing_cycle is "monthly"
            entry.purchaseStatus = "auto-pay-monthly"
          else if payload.membership_billing_cycle is "yearly"
            entry.purchaseStatus = "auto-pay-yearly"
          entry.opt_out_subscription = true if opt_out_subscription
          payload.cart.shopping_cart_entries.push entry

          @purchase_create3_direct payload, (result_failed, result_success) =>
            if result_failed
              result_failed.pending_process_uid = pending_process_uid
              result_failed.membership_id = rrads_membership_id
              result_failed.auto_renew = auto_renew
              result_failed.purchase_id = -1
              @captureError("@purchase_create3_direct: api_rbo.purchase_create membership", result_failed, req)
              api_rbo_rrads.return_pending_process result_failed, (err, result_failed) ->
                console.log "Error: api_rbo_rrads.user_upsert_rads: ", err if err
              return res.json result_failed, 500
            else if result_success
              result_success.pending_process_uid = pending_process_uid
              result_success.membership_id = rrads_membership_id
              result_success.auto_renew = auto_renew
              api_rbo_rrads.return_pending_process result_success, (err, t_result) ->
                console.log "Error: api_rbo_rrads.user_upsert_rads: ", err if err
              return res.json result_success
            else
              return res.json {error: "Error: purchase failed no results."}, 500
      else
        @log(req)
        return res.json {error: "Purchasing is temporarily unavailable.  Missing cart and type.  Please try again later."}, 401


    #Retrieve Purchases by user
    purchase_byuser: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      user = req.user
      result_success = {
        purchases: ""
        hasPurchases: false
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      @getPurchases user, (err, purchases) =>
        filteredPurchases = []
        for purchase in purchases
          #filteredPurchases.push purchase     #Don't push the whole object in, it's too big.  Just grab what we need for RRADS for now
          tHuntCatalogCopy = _.pick(purchase.huntCatalogCopy[0], ["title","species","name","state","type"])
          tPurchase = _.pick(purchase,["_id", "amountTotal", "createdAt", "amountPaid", "amountTotal", "amount", "price_total","purchase_cancelled"])

          #To make RRADS work
          if purchase.huntCatalogCopy[0].rradsObj
            t_rradsObj = purchase.huntCatalogCopy[0].rradsObj
            t_rradsObj = JSON.parse(t_rradsObj)
            rradsObj = _.pick(t_rradsObj, ["class_name", "title"]) if t_rradsObj
            tHuntCatalogCopy.rradsObj = JSON.stringify(rradsObj)

          tPurchase.huntCatalogCopy = []
          tPurchase.huntCatalogCopy[0] = tHuntCatalogCopy
          filteredPurchases.push tPurchase
        if err
          result_failed.error = err
          console.log "Error: Failed to retrieve purchases for user. ", err
          return res.json result_failed, 401
        else if user
          if filteredPurchases?.length
            result_success.hasPurchases = true
            result_success.purchases = filteredPurchases if filteredPurchases
          else
            result_success.hasPurchases = false
          return res.json result_success
        else
          result_failed.error = "Could not find user"
          return res.json result_failed, 401

    #Retrieve Purchases by NRADS Id
    purchase_byId: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      purchaseId = req.param('purchaseId')
      return_cart_view = req.param('return_cart_view')
      admin_view = req.param('admin_view')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      user = req.user
      return_cart_view = return_cart_view is "true"
      show_cart_view_button = !return_cart_view
      result_success = {
        purchase: ""
        receipt: []
        show_cart_view_button: show_cart_view_button
        purchase_status: "Congratulations!  Your payment has been accepted."
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      payment_statuses = [
        { name: "paid in full", value: "paid-in-full" }
        { name: "invoiced", value: "invoiced" }
        { name: "transferred", value: "transfer" }
        { name: "check pending", value: "check-pending" }
        { name: "check cleared", value: "check-cleared" }
        { name: "auto pay monthly", value: "auto-pay-monthly" }
        { name: "auto pay yearly", value: "auto-pay-yearly" }
        { name: "auto pay retry monthly", value: "auto-pay-monthly-retry" }
        { name: "auto pay retry yearly", value: "auto-pay-yearly-retry" }
        { name: "cancelled", value: "cancelled" }
        { name: "over due", value: "over_due" }
        { name: "cc failed", value: "cc_failed" }
      ]

      @getPurchaseById purchaseId, tenantId, (err, purchase) =>
        if err
          result_failed.error = err
          return res.json result_failed, 401
        else if purchase
          purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]
          result_success.purchase = purchase

          if return_cart_view
            @buildCartReceipt purchase, tenantId, (err, receipt) =>
              if err
                result_failed.error = err
                return res.json result_failed, 401
              else
                result_success.receipt = receipt
                #delete result_success.purchase.huntCatalogCopy
                result_success.purchase.huntCatalogCopy.title = "Purchase Order Summary"
                delete result_success.purchase.userSnapShot
                return res.json result_success

          else if admin_view
            delete result_success.purchase.userSnapShot
            return res.json result_success

          else

            #Build the receipt in sections:
            #Purchase Receipt section
            purchase.options_total = 0
            if purchase.options?.length
              for option in purchase.options
                purchase.options_total += option.price

            purchase_receipt = []
            purchase_receipt.push {"Purchase Date": @formatDateStr(purchase.createdAt)}
            purchase_receipt.push {"Purchase Order #": purchase.orderNumber} if purchase.orderNumber
            purchase_receipt.push {"Authorization Number": purchase.cc_transId}
            purchase_receipt.push {"Item": "#{purchase.huntCatalogCopy.huntNumber}, #{purchase.huntCatalogCopy.title}"}
            purchase_receipt.push {"Invoice #": purchase.invoiceNumber} if purchase.invoiceNumber
            if purchase.huntCatalogCopy.type is "hunt"
              purchase_receipt.push {"Base Price": "#{@formatMoneyStr(purchase.basePrice)}, (*The hunt price is subject to change, and does not include add-ons or upgrades provided as options by the outfitter.)"}
            else
              purchase_receipt.push {"Price": @formatMoneyStr(purchase.basePrice)}

            purchase_receipt.push {"Option add ons": @formatMoneyStr(purchase.options_total)} if purchase.options_total and purchase.options_total > 0
            purchase_receipt.push {"Tags and Licenses": @formatMoneyStr(purchase.tags_licenses)} if purchase.tags_licenses and purchase.tags_licenses > 0
            purchase_receipt.push {"Processing Fee": @formatMoneyStr(purchase.fee_processing)} if purchase.fee_processing and purchase.fee_processing > 0
            purchase_receipt.push {"Shipping": @formatMoneyStr(purchase.shipping)} if purchase.shipping and purchase.shipping > 0
            purchase_receipt.push {"Sales Tax": @formatMoneyStr(purchase.sales_tax)} if purchase.sales_tax and purchase.sales_tax > 0
            purchase_receipt.push {"Total Amount": @formatMoneyStr(purchase.amountTotal)}
            purchase_receipt.push {"Today's Payment": @formatMoneyStr(purchase.amount)}

            if purchase.huntCatalogCopy.type is "hunt"
              purchase_receipt.push {"Total due 60 days prior to hunt start date": @formatMoneyStr(purchase.amountTotal - purchase.amount)}
            else
              purchase_receipt.push {"Total due": @formatMoneyStr(purchase.amountTotal - purchase.amount)}

            purchase_receipt.push {"Purchase Notes": purchase.purchaseNotes} if purchase.purchaseNotes
            if purchase.options?.length
              for option in purchase.options
                key = option.title
                value = option.specific_type
                item = {}
                item[key] = value
                purchase_receipt.push item

            result_success.receipt.push {"Purchase Receipt": purchase_receipt}

            #Status section
            if purchase.isSubscription and purchase.huntCatalogCopy.paymentPlan is "subscription_yearly"
              result_success.purchase_status = "Your account will be charged #{@formatMoneyStr(purchase.amount)} each year for this service. You can cancel at anytime by contacting us."
            else if purchase.isSubscription and purchase.huntCatalogCopy.paymentPlan is "subscription_monthly"
              result_success.purchase_status = "Your account will be charged #{@formatMoneyStr(purchase.amount)} each year for this service. You can cancel at anytime by contacting us."
            else if purchase.huntCatalogCopy.type is "hunt"
              result_success.purchase_status = "Congratulations!  Your payment to reserve this hunt has been accepted and the hunt and your requested dates have been received. The hunt reservation and dates will be finalized upon completion of your final agreement with your Rolling Bones Concierge Specialist and the Outfitter or Guide."
            else
              result_success.purchase_status = "Congratulations!  Your payment has been accepted."

            #Details section
            if purchase.huntCatalogCopy.type is "hunt"
              details = []
              details.push {"Location": "#{purchase.huntCatalogCopy.state}, #{purchase.huntCatalogCopy.country}"}
              details.push {"Species": purchase.huntCatalogCopy.species}
              details.push {"Hunt Date Requested": "#{@formatDateStr(purchase.start_hunt_date)}.  Note the hunt dates are a request only and must be approved and confirmed by the outfitter before the hunt dates are finalized."} if purchase.start_hunt_date
              result_success.receipt.push {"Details": details}
            else if purchase.huntCatalogCopy.type is "course"
              details = []
              details.push {"Shooting Course Date Requested": "#{@formatDateStr(purchase.start_hunt_date)}.  Dates and availability must be approved and confirmed by Rolling Bones before the dates are finalized."} if purchase.start_hunt_date
              result_success.receipt.push {"Details": details}

            #Payment Information section
            payment_info = []
            if purchase.paymentUsed
              payment_used = purchase.paymentUsed
            else
              payment_used = purchase.paymentMethod

            payment_used = "Card" if payment_used is "card"
            payment_used = "Bank" if payment_used is "bank"
            payment_info.push {"Payment Method": payment_used}

            payment_info.push {"Account Number": purchase.cc_accountNum} if purchase.cc_accountNum
            payment_info.push {"Amount Charged": @formatMoneyStr(purchase.amount)}
            if purchase.huntCatalogCopy.refund_policy
              payment_info.push {"Refund Policy": purchase.huntCatalogCopy.refund_policy}
            else if purchase.huntCatalogCopy.type is "hunt"
              payment_info.push {"Refund Policy": "Deposit 80% refundable 1 year prior to hunt date. 40% refundable 6 months prior to hunt date. No refunds under 6 months of the hunt date."}
            else
              payment_info.push {"Refund Policy": "All sales are final"}
            result_success.receipt.push {"Initial Payment Information": payment_info}

            #Payment Status
            payment_status = []
            for pStatus in payment_statuses
              purchaseStatus = pStatus.name if pStatus.value is purchase.status
            payment_status.push {"Total Price": @formatMoneyStr(purchase.amountTotal)}
            payment_status.push {"Total Payments Received": @formatMoneyStr(purchase.amountPaid)}
            payment_status.push {"Total Due": @formatMoneyStr(purchase.amountTotal - purchase.amountPaid)}
            payment_status.push {"Purchase Status": purchaseStatus} if purchaseStatus
            payment_status.push {"Authorized Automatic Payments": purchase.authorize_automatic_payments} if purchase.authorize_automatic_payments
            payment_status.push {"Next Payment Date": @formatDateStr(purchase.next_payment_date)} if purchase.next_payment_date
            payment_status.push {"Next Payment Amount": @formatMoneyStr(purchase.next_payment_amount)} if purchase.next_payment_amount
            payment_status.push {"Amount Refunded": @formatMoneyStr(purchase.refund_amount)} if  purchase.refund_amount
            payment_status.push {"Purchase Cancelled": @formatDateStr(purchase.purchase_cancelled)} if purchase.purchase_cancelled
            result_success.receipt.push {"Current Payment Status": payment_status} if !(purchase.huntCatalogCopy?.type is "payment")

            delete result_success.purchase.userSnapShot
            return res.json result_success

        else
          result_failed.error = "Could not find purchase"
          return res.json result_failed, 401


    #Build Cart Receipt
    buildCartReceipt: (purchase, tenantId, cb) ->
      orderNumber = purchase.orderNumber
      receipt = []

      getPurchasesForOrder = (purchase, done) ->
        if !purchase.orderNumber
          return done null, [purchase]
        else
          Purchase.byOrderNumber purchase.orderNumber, tenantId, (err, purchases) ->
            return done err, purchases

      getPurchasesForOrder purchase, (err, purchases) =>
        if err
          console.log "Error: View cart receipt requested but no items found for Purchase order number: ", orderNumber
          return cb err

        if purchases?.length
          cart_price = 0
          cart_tags_licenses = 0
          cart_fee_processing = 0
          cart_shipping = 0
          cart_options = 0
          cart_subtotal = 0
          cart_salestax = 0
          cart_grandtotal = 0
          cart_todays_payment = 0
          itemsDescription = ""

          for purchase in purchases
            purchase.huntCatalogCopy = purchase.huntCatalogCopy[0] if Array.isArray(purchase.huntCatalogCopy)
            cart_price += purchase.basePrice
            cart_tags_licenses += purchase.tags_licenses
            cart_fee_processing += purchase.fee_processing
            cart_shipping += purchase.shipping
            cart_salestax += purchase.sales_tax
            if purchase.options?.length
              for option in purchase.options
                cart_options += option.price
            cart_grandtotal = cart_price + cart_options + cart_tags_licenses + cart_fee_processing + cart_shipping + cart_salestax
            cart_todays_payment += purchase.amount
            if itemsDescription.length is 0
              itemsDescription = "#{purchase.huntCatalogCopy.title}"
            else
              itemsDescription = "#{itemsDescription}, #{purchase.huntCatalogCopy.title}"

          #Purchase Order Summary section
          cart_info = []
          cart_info.push {"Purchase Order #:": orderNumber}
          cart_info.push {"Items:": itemsDescription}
          cart_info.push {"Total Price": @formatMoneyStr(cart_price)}
          cart_info.push {"Total Option add ons": @formatMoneyStr(cart_options)} if cart_options
          cart_info.push {"Total Tags & Licenses": @formatMoneyStr(cart_tags_licenses)} if cart_tags_licenses
          cart_info.push {"Total Processing fee": @formatMoneyStr(cart_fee_processing)} if cart_fee_processing
          cart_info.push {"Total Shipping": @formatMoneyStr(cart_shipping)} if cart_shipping
          cart_info.push {"Total Sales Tax": @formatMoneyStr(cart_salestax)} if cart_salestax
          cart_info.push {"Grand Total": @formatMoneyStr(cart_grandtotal)} if cart_grandtotal
          cart_info.push {"Amount Charged": @formatMoneyStr(cart_todays_payment)}
          receipt.push {"Purchase Order Summary": cart_info}

          #Payment Information section
          payment_info = []
          if purchase.paymentUsed
            payment_used = purchase.paymentUsed
          else
            payment_used = purchase.paymentMethod
          payment_used = "Card" if payment_used is "card"
          payment_used = "Bank" if payment_used is "bank"
          payment_used = "Check" if payment_used is "check"
          payment_used = "Cash" if payment_used is "cash"
          payment_info.push {"Purchase Date": @formatDateStr(purchase.createdAt)}
          payment_info.push {"Authorization Number": purchase.cc_transId}
          payment_info.push {"Payment Method": payment_used}
          payment_info.push {"Account Number": purchase.cc_accountNum} if purchase.cc_accountNum
          receipt.push {"Purchase Information": payment_info}

          #Individual Items in the cart
          i = 1
          for purchase in purchases
            item_info = []
            purchase.options_total = 0
            if purchase.options?.length
              for option in purchase.options
                purchase.options_total += option.price

            item_info.push {"Item": "#{purchase.huntCatalogCopy.huntNumber}, #{purchase.huntCatalogCopy.title}"}
            item_info.push {"Invoice #": purchase.invoiceNumber} if purchase.invoiceNumber
            if purchase.huntCatalogCopy.type is "hunt"
              item_info.push {"Base Price": "#{@formatMoneyStr(purchase.basePrice)}, (*The hunt price is subject to change, and does not include add-ons or upgrades provided as options by the outfitter.)"}
            else
              item_info.push {"Price": @formatMoneyStr(purchase.basePrice)}
            item_info.push {"Option add ons": @formatMoneyStr(purchase.options_total)} if purchase.options_total and purchase.options_total > 0
            item_info.push {"Tags and Licenses": @formatMoneyStr(purchase.tags_licenses)} if purchase.tags_licenses and purchase.tags_licenses > 0
            item_info.push {"Processing Fee": @formatMoneyStr(purchase.fee_processing)} if purchase.fee_processing and purchase.fee_processing > 0
            item_info.push {"Shipping": @formatMoneyStr(purchase.shipping)} if purchase.shipping and purchase.shipping > 0
            item_info.push {"Sales Tax": @formatMoneyStr(purchase.sales_tax)} if purchase.sales_tax and purchase.sales_tax > 0
            item_info.push {"Total Amount": @formatMoneyStr(purchase.amountTotal)}
            item_info.push {"Today's Payment": @formatMoneyStr(purchase.amount)}
            if purchase.huntCatalogCopy.type is "hunt"
              item_info.push {"Total due 60 days prior to hunt start date": @formatMoneyStr(purchase.amountTotal - purchase.amount)}
            else
              item_info.push {"Total due": @formatMoneyStr(purchase.amountTotal - purchase.amount)}
            item_info.push {"Purchase Notes": purchase.purchaseNotes} if purchase.purchaseNotes
            if purchase.options?.length
              for option in purchase.options
                key = option.title
                value = option.specific_type
                item = {}
                item[key] = value
                item_info.push item


            if purchase.isSubscription and purchase.huntCatalogCopy.paymentPlan is "subscription_yearly"
              purchase_status = "Your account will be charged #{@formatMoneyStr(purchase.amount)} each year for this subscription. You can cancel at anytime by contacting us."
            else if purchase.isSubscription and purchase.huntCatalogCopy.paymentPlan is "subscription_monthly"
              purchase_status = "Your account will be charged #{@formatMoneyStr(purchase.amount)} each month for this subscription. You can cancel at anytime by contacting us."
            else if purchase.huntCatalogCopy.type is "hunt"
              purchase_status = "Congratulations!  Your payment to reserve this hunt has been accepted and the hunt and your requested dates have been confirmed and held. The hunt reservation and dates will be finalized upon completion of your final agreement with your Rolling Bones Concierge Specialist and the Outfitter or Guide."
            else
              purchase_status = "Congratulations!  Your payment has been accepted."
            #item_info.push {"Purchase Status": purchase_status}

            if purchase.huntCatalogCopy.type is "hunt"
              detailsStr = ""
              detailsStr += "Location: #{purchase.huntCatalogCopy.state}, #{purchase.huntCatalogCopy.country},  "
              detailsStr += "Species: #{purchase.huntCatalogCopy.species},  "
              detailsStr += "Hunt Date Requested: #{@formatDateStr(purchase.start_hunt_date)}.  Note the hunt dates are a request only and must be approved and confirmed by the outfitter before the hunt dates are finalized." if purchase.start_hunt_date
              item_info.push {"Details": detailsStr}
            else if purchase.huntCatalogCopy.type is "course"
              detailsStr = ""
              detailsStr += "Shooting Course Date Requested: #{@formatDateStr(purchase.start_hunt_date)}.  Dates and availability must be approved and confirmed by Rolling Bones before the dates are finalized." if purchase.start_hunt_date
              item_info.push {"Details": detailsStr}

            if purchase.huntCatalogCopy.refund_policy
              item_info.push {"Refund Policy": purchase.huntCatalogCopy.refund_policy}
            else if purchase.huntCatalogCopy.type is "hunt"
              item_info.push {"Refund Policy": "Deposit 80% refundable 1 year prior to hunt date. 40% refundable 6 months prior to hunt date. No refunds under 6 months of the hunt date."}
            else
              item_info.push {"Refund Policy": "All sales are final"}

            #Payment Status
            item_info.push {"Authorized Automatic Payments":  purchase.authorize_automatic_payments} if purchase.authorize_automatic_payments

            receipt.push {"Item #{i}": item_info}
            i++

          return cb null, receipt

        else
          console.log "Error: View cart receipt requested but no items found for Purchase order number: ", orderNumber
          return cb "No items found for this purchase order."

    #Send contact request to Adivsor directly
    contact_advisor: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      contactRequest = req.body.contact_me_request
      tenantDomain = contactRequest.tenant_domain
      tenantDomain = contactRequest.request_domain if contactRequest.request_domain
      email_template_prefix = contactRequest.email_template_prefix if contactRequest.email_template_prefix
      email_from_name = contactRequest.email_from_name if contactRequest.email_from_name
      advisor_client_id = req.body.advisor_client_id if req.body.advisor_client_id

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      tenant = null
      async.waterfall [
        #Get rep that is receiving the email
        (next) ->
          Tenant.findById tenantId, (err, t_tenant) ->
            console.log "Error share: ", err if err
            tenant = t_tenant if t_tenant
            tenant.tmp_email_template_prefix = email_template_prefix if email_template_prefix
            tenant.tmp_email_from_name = email_from_name if email_from_name

            return next 'Missing client id for advisor' unless advisor_client_id
            User.byClientId advisor_client_id, {}, (err, advisor) =>
              return next err if err
              if advisor
                return next err, advisor
              else
                return next "Could not find user for client id #{advisor_client_id}"

        #Send email notification to the rep
        (advisor, next) ->
          template_name = "Appointment Request"
          subject = "RBO User Appointment Request"
          mandrilEmails = []
          to_user = {
            email: advisor.email
            name: advisor.name
          }
          mandrilEmails.push to_user
          merge_vars = {}
          merge_vars["advisor_name"] = advisor.name
          merge_vars["user_full_name"] = contactRequest.name
          merge_vars["user_email"] = contactRequest.email
          merge_vars["user_phone"] = contactRequest.phone_number
          merge_vars["user_message"] = contactRequest.message

          mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, merge_vars, null, null, false, false, (err, results) ->
            return next err, results

      ], (err, results) ->
        if err
          result_failed.error = err
          return res.json result_failed, 500

        result_success.results = "Advisor email sent successfully"
        return res.json result_success


    #Create Contact Request (Service Request)
    servicerequest_create: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')

      request_type = req.param('request_type') #Handling "specific_state_application", "apply_states", "hunt_plan", "contact_me", "hunt", "product", "membership", "rifle", "course", "whitelabel_listing_approval", "show_on_rads"
      email = req.param('email')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      return res.json {error: "Bad Request missing email"}, 400 unless email
      return res.json {error: "Bad Request missing request_type"}, 400 unless request_type

      name = req.param('name')
      phone_number = req.param('phone_number')
      message = req.param('message')
      internal_note = req.param('internal_note')
      request_url = req.param('request_url')
      client_id = req.param('client_id')
      contactable_id = req.param('contactable_id')
      contactable_type = req.param('contactable_type')
      contactable = req.param('contactable') #This is the serilazed item they were on
      contactable = JSON.stringify(contactable) if contactable
      catalog_id = req.param('catalog_id') #Hunt Catalog Number
      listing_title = req.param('listing_title') #Hunt Catalog Listing title
      metadata = req.param('metadata')

      request_type = "sell_on_rbo" if request_type is "show_on_rads"
      base_tenant_id = req.param('base_tenant_id')
      tenantId = base_tenant_id if base_tenant_id

      body = req.body
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      serviceRequestData = {}
      hfsUser = null
      async.waterfall [
        (next) ->
          serviceRequestData = {
            tenantId: tenantId
            subtype: request_type
            email: email
            name: name
            phone: phone_number
            message: message
            notes: internal_note
            referral_url: request_url
            referral_source: contactable_type
            contactable: contactable
          }
          if catalog_id or listing_title
            message = "#{catalog_id}: #{listing_title},    #{message}"
          if contactable_type?.toLowerCase() is "hunt"
            serviceRequestData.type = "Request Hunt Info"
          else
            serviceRequestData.type = "Support"
          return next null, serviceRequestData

        (serviceRequestData, next) ->
          return next null, serviceRequestData unless client_id
          User.byClientId client_id, {}, (err, user) ->
            return next err if err
            return next "Failed to find user match for client_id: ", client_id unless user
            hfsUser = user
            serviceRequestData.name = user.name
            serviceRequestData.first_name = user.first_name
            serviceRequestData.last_name = user.last_name
            serviceRequestData.userId = user._id
            return next null, serviceRequestData

        (serviceRequestData, next) =>
          return next null, serviceRequestData if serviceRequestData.first_name or serviceRequestData.last_name
          return next null, serviceRequestData unless name and !serviceRequestData.first_name?.length and !serviceRequestData.last_name?.length
          names = @parseName(name)
          serviceRequestData.first_name = names.first_name
          serviceRequestData.last_name = names.last_name
          return next null, serviceRequestData

        (serviceRequestData, next) ->
          return next null, serviceRequestData unless request_type is "specific_state_application" and hfsUser and metadata?.length
          now = new Date()
          hfsData = {
            userId: hfsUser._id
            client_id: hfsUser.clientId
            tenantId: tenantId
            modified: now
          }
          for item in metadata
            if item["key"] is "state"
              statePrefix = item["value"]
              statePrefix = statePrefix.toLowerCase() if statePrefix
          statePrefix = "ore" if statePrefix is "or"
          if statePrefix
            hfsData["#{statePrefix}_notes"] = message
          HuntinFoolState.upsert hfsData, (err, results) ->
            return next err, serviceRequestData

      ], (err, serviceRequestData) ->
          return res.json err, 500 if err
          ServiceRequest.upsert serviceRequestData, (err, serviceRequest) ->
            if err
              result_failed.error = err
              return res.json result_failed, 500
            if !serviceRequest
              result_failed.error = "Failed to create nnrads service request."
              return res.json result_failed, 500

            result_success.serviceRequest = serviceRequest
            return res.json result_success


    #Retrieve reminders
    reminders_index: (req, res) ->
      @log(req)
      DAY_MILISECONDS = 1000 * 60 * 60 * 24
      MONTH_MILISECONDS = DAY_MILISECONDS * 7 * 4.33333
      now = new Date().getTime()
      CURRENT_START = now - (1*DAY_MILISECONDS)
      CURRENT_END = now + (1*MONTH_MILISECONDS)
      ALL_START = now - (12*MONTH_MILISECONDS)

      RANGE_START = now - (3*DAY_MILISECONDS)
      RANGE_END = now + (3*MONTH_MILISECONDS)
      RANGE_HARD_START = now - (12*MONTH_MILISECONDS) #Use this instead of fullYear check hard coded to 2018 below
      apitoken = req.param('token')
      source_page = req.param('source_page')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      return res.json {error: "Bad Request missing source_page"}, 400 unless source_page
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      body = req.body
      user = req.user
      result_success = {
        state_application_reminders: ""
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      result_success.state_application_reminders = []

      Tenant.findById tenantId, (err, tenant) =>
        if !tenant.rrads_use_production_token
          tenantId = GotMyTagTenantId #JUST FOR TESTING
        else
          tenantId = RollingBonesTenantId #Always use Rolling Bones Reminders
        states = ["none"]
        states = req.user.reminders.states if req.user?.reminders?.states
        Reminder.byStatesTenantAll tenantId, states, (err, reminders) ->
          #TODO:  if coming from dashboard....endate is 2 days ago or 30 days in the future.  Order by end date cloests to farthest
          if err
            result_failed.error = err
            return res.json result_failed, 401
          else if reminders
            result_success.state_application_reminders = []
            result_success.state_application_reminders_all = []
            result_success.state_application_reminders_future = []
            result_success.state_application_reminders_current = []
            for reminder in reminders
              addIt = true
              record = _.pick reminder, "start", "end", "state", "title"
              record.start = new Date(record.start).getTime()
              record.end = new Date(record.end).getTime()
              record.startDate = new Date(record.start)
              record.endDate = new Date(record.end)

              if reminder.isDrawResultSuccess is true or reminder.isDrawResultUnsuccess is true
                addIt = false
                continue

              if tenantId is GotMyTagTenantId
                #For testing
                result_success.state_application_reminders.push record
                result_success.state_application_reminders_all.push record
                result_success.state_application_reminders_future.push record
                result_success.state_application_reminders_current.push record
                continue

              start_fullYear = record.startDate.getFullYear()
              end_fullYear = record.endDate.getFullYear()
              if start_fullYear < 2018 or end_fullYear < 2018
                addIt = false
              if addIt
                if source_page is "dashboard"
                  #Just show the most recent
                  if record.start > RANGE_START and record.end < RANGE_END
                    addIt = true
                  else if tenantId is GotMyTagTenantId
                    addIt = true
                  else
                    addIt = false
                else if source_page is "settings"
                  #Show all
                  x=""

              result_success.state_application_reminders.push record if addIt
              if record.start > ALL_START
                result_success.state_application_reminders_all.push record
              if record.start > now
                result_success.state_application_reminders_future.push record
              if ((record.start > CURRENT_START and record.start < CURRENT_END) or (record.end > CURRENT_START and record.end < CURRENT_END))
                result_success.state_application_reminders_current.push record
            return res.json result_success
          else
            result_failed.error = "Could not find reminders"
            return res.json result_failed, 401

    #Send an email to share a hunt catalog item
    huntcatalog_share: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      hunt_catalog_item = req.body.sharable
      shareable_item = req.body.sharable
      tenantDomain = req.body.tenant_domain
      tenantDomain = req.body.request_domain if req.body.request_domain
      return res.json {error: "Bad Request missing sharable identifier"}, 400 unless hunt_catalog_item

      email_template_prefix = req.body.email_template_prefix if req.body.email_template_prefix
      email_from_name = req.body.email_from_name if req.body.email_from_name

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      tenant = null

      async.waterfall [

        #Get the from user if one is available
        (next) ->
          Tenant.findById tenantId, (err, t_tenant) ->
            console.log "Error share: ", err if err
            tenant = t_tenant if t_tenant
            tenant.tmp_email_template_prefix = email_template_prefix if email_template_prefix
            tenant.tmp_email_from_name = email_from_name if email_from_name
            return next null, null unless req.body.client_id
            User.byClientId req.body.client_id, tenantId, (err, user) ->
              return next err if err
              return "User not found for clientId: #{req.body.client_id}" unless user
              return next null, user

        #Get rep for this user
        (user, next) ->
          return next null, user, null unless user and user?.parentId
          User.byId user.parentId, {}, (err, parent) ->
            return next err if err
            return "Parent not found for id: #{user._id}" unless parent
            return next null, user, parent

      ], (err, user, parent) ->
        if err
          result_failed.error = err
          console.log "Error: ", result_failed

        #Map the fields from the RRADS req data
        title = hunt_catalog_item.title
        if tenantDomain
          base_url = tenantDomain
        else
          base_url = RRADS_API_BASEURL
          base_url = RRADS_API_BASEURL_STAGING if tenantId is VerdadTestTenantId
        purchase_link = "#{base_url}#{req.body.request_url}"
        if user?.isRep and user?.clientId
          purchase_link = "#{base_url}/a?clientId=#{user.clientId}&link_to=#{encodeURI(req.body.request_url)}"
        else if parent?.isRep and parent?.clientId
          purchase_link = "#{base_url}/a?clientId=#{parent.clientId}&link_to=#{encodeURI(req.body.request_url)}"

        if req.body?.class_name is "HuntPlan"
          huntPlan = hunt_catalog_item
          description = "This hunt plan has been shared with you."
          description = "#{description} <br/> From: #{user.name}, #{user.email}" if user
          description = "#{description} <br/> Title: #{huntPlan.title}" if huntPlan?.title
          description = "#{description} <br/> Species: #{huntPlan.species.name}" if huntPlan?.species?.name
          description = "#{description} <br/> Goals: #{huntPlan.this_hunt_goals_description}" if huntPlan?.this_hunt_goals_description
        else if req.body?.class_name is "Membership"
          if shareable_item?.group is "oss"
            packageType = ""
            packageType = shareable_item.name if shareable_item?.name
            title = "Outdoor Software Solutions #{packageType} Package"
            description = "Product Storefront, Point of Sale, Customer Dashboard, CRM, Admin Tools
              | Further monetize on your client base.
              | Get paid commissions on products sold through your own product store
              | Take advantage of special offers established for Outdoor Software Solution clients.
              | Simple, easy tools to enter and update your hunt content on the web.
              | (webmaster not needed for updating your hunt pricing, schedule, content, media, etc. Huge time and cost savings).
              | Enable hunt purchases via credit card or eCheck payments immediately online
              | Admin tools to receive notifications and view purchases
              | Captures clientele into a specialized hunting CRM.
              | Add, update, and manage your users. View their history of purchases, access their contact info, mailing lists, etc.
              | Users can register with your website and have their very own login.
              | Set Hunt goals saved on their dashboard
              | View hunt and product specials
              | View all of their purchase receipts.
              | "
          else if shareable_item?.group is "rbo"
            packageType = ""
            packageType = shareable_item.name if shareable_item?.name
            title = "Rolling Bones #{packageType} Membership"
            description = "OUR MISSION IS TO DELIVER YOUR MOST MEMORABLE ADVENTURE EVER. PERIOD.
              | At Rolling Bones Outfitters we have a passion for great people and the great outdoors.
              | People like saving money on the quality products and services they use while doing what they love to do, so we provide our members exceptional value and personalized service on all aspects of their outdoor adventures.
              | We understand the anticipation and excitement that goes into preparing for your next dream hunting and fishing trip, so we partner with experienced, professional guides and outfitters to create the best opportunities for your trip of a lifetime."
        else
          description = hunt_catalog_item.description

        from_user_name = "A friend"
        message = ""
        message = req.body.message if req?.body?.message
        if user
          if user.name
            from_user_name = user.name
          else if user.first_name or user.last_name
            from_user_name = "#{user.first_name} #{user.last_name}"
          else if user.email
            from_user_name = user.email
          else
            from_user_name = "A friend"
        images_block = ""
        if req?.body?.sharable?.featured_image_url
          imgLink = '<img title="Featured Image" style="width: 100%;" src="' + req.body.sharable.featured_image_url + '"/>'
          images_block = imgLink

        #Send to the target emails
        template_name = "Share Hunt"
        subject = title
        #send emails
        emails = req.body.email_addresses_raw.split(",")

        #CC Rep on the target email
        copyrep = false
        repDisabled = false
        repDisabled = true if tenant.disableReps? and tenant.disableReps is true
        if user?.email and user?.isRep and !repDisabled
          repEmail = user.email.toLowerCase().trim() if user?.email?.length
          repName = user.name if user?.name
          copyrep = true
        else if parent?.email and parent?.isRep and !repDisabled
          repEmail = parent.email.toLowerCase().trim() if parent?.email?.length
          repName = parent.name if parent?.name
          copyrep = true

        for email in emails
          mandrilEmails = []
          email = email.toLowerCase().trim() if email?.length
          to = {
            email: email
            type: "to"
          }
          mandrilEmails.push to if to
          #CC The rep also
          if repEmail and !repDisabled
            cc = {
              email: repEmail
              type: "cc"
            }
            cc.name = repName if repName
            mandrilEmails.push cc if cc

          #Send the target emails
          payload = {
            title: title
            description: description
            from_user_name: from_user_name
            message: message
            purchase_link: purchase_link
            images_block: images_block
            shared_emails_addresses: req.body.email_addresses_raw
            parent_name: ""
            user_name: ""
            repName: ""
            repEmail: ""
            copyrep: copyrep
          }
          payload.repName = repName if repName
          payload.repEmail = repEmail if repEmail
          mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, payload, null, null, null, true, null

        #Now send a copy to the person who sent the email
        if user?.email
          template_name = "Share Hunt Sender Copy"
          subject = "You Shared #{title}"
          mandrilEmails = []
          to = {
            email: user.email
            type: "to"
          }
          to.name = user.name if user?.name
          mandrilEmails.push to if to
          payload = {
            title: title
            description: description
            from_user_name: from_user_name
            message: message
            purchase_link: purchase_link
            images_block: images_block
            shared_email_addresses: req.body.email_addresses_raw
            parent_name: ""
            user_name: ""
            repName: ""
            repEmail: ""
            copyrep: copyrep
          }
          payload.repName = repName if repName
          payload.repEmail = repEmail if repEmail
          payload.user_name = user.name if user?.name
          mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, payload, null, null, null, false, null

        #Now send a copy to the person who sent the email's rep.  Could be the rep's rep if the user was a rep
        if parent?.email and parent?.isRep and !repDisabled
          template_name = "Share Hunt Rep Copy"
          subject = "User Shared #{title}"
          mandrilEmails = []
          to = {
            email: parent.email
            type: "to"
          }
          to.name = parent.name if parent.name
          mandrilEmails.push to if to
          payload = {
            title: title
            description: description
            from_user_name: from_user_name
            message: message
            purchase_link: purchase_link
            images_block: images_block
            shared_email_addresses: req.body.email_addresses_raw
            parent_name: ""
            repName: ""
            repEmail: ""
            copyrep: copyrep
          }
          payload.repName = repName if repName
          payload.repEmail = repEmail if repEmail
          payload.parent_name = parent.name if parent?.name
          payload.user_name = user.name if user?.name
          mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, payload, null, null, null, false, null

        result_success.message = "Email requests for sharing hunt catalog items sent to Mandrill: #{req.body.email_addresses.join(",")}"
        return res.json result_success


    #Create Hunt Application
    huntApplication: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId

      user = req.user
      year = req.param('year')
      state = req.param('state')
      state_abr = req.param('state_abr').toLowerCase() if req.param('state_abr')
      species = req.param('species') if req.param('species')
      note = req.param('note')
      apply_for_me = req.param('apply_for_me')
      deleteMe = req.param('delete_me')
      return res.json {error: "Bad Request missing year"}, 400 unless year
      return res.json {error: "Bad Request missing state"}, 400 unless state
      return res.json {error: "Bad Request missing state_abr"}, 400 unless state_abr
      return res.json {error: "Bad Request missing user"}, 400 unless user
      #return res.json {error: "Bad Request missing species"}, 400 unless species
      #return res.json {error: "Bad Request missing note"}, 400 unless note

      state_abr = "ore" if state_abr is "or"
      if apply_for_me is true
        apply_for_me = true
      else if apply_for_me is false
        apply_for_me = false
      else if !apply_for_me
        apply_for_me = false
      else if apply_for_me.toLowerCase() is "true"
        apply_for_me = true
      else
        apply_for_me = false


      if deleteMe is true
        deleteMe = true
      else if deleteMe is false
        deleteMe = false
      else if deleteMe?.toLowerCase() is "true"
        deleteMe = true
      else
        deleteMe = false

      body = req.body
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      async.waterfall [
        (next) ->
          #Get HFS for this user/year
          HuntinFoolState.byUserIdYear user._id, year, (err, hfs) ->
            return next err, hfs unless hfs
            hfs["#{state_abr}_comments"] = "" unless hfs and hfs["#{state_abr}_comments"]
            return next err, hfs

        (hfs, next) ->
          now = new Date()
          hfsData = {
            userId: user._id
            client_id: user.clientId
            year: year
            tenantId: tenantId
            modified: now
          }
          hfsData._id = hfs._id if hfs #Create vs Update

          if state is "gen_notes"
            hfsData["gen_notes"] = note
            return next null, hfsData
          else
            x="" #Need noop to if hfs below works in compiled code
            hfsData["#{state_abr}_comments"] = hfs["#{state_abr}_comments"] if hfs
            hfsData["#{state_abr}_comments"] = "" unless hfsData["#{state_abr}_comments"]

          if deleteMe
            hfsData["#{state_abr}_check"] = ""
            hfsData["#{state_abr}_notes"] = ""
            hfsData["#{state_abr}_species_picked"] = []
            hfsData["#{state_abr}_comments"] = hfs["#{state_abr}_comments"] + " User deleted this application on #{moment().format("YYYY-MM-DD")}.  Previous notes were: #{hfs["#{state_abr}_notes"]}" if hfs
            return next null, hfsData
          else
            #Trying to make this all backward compatible
            if apply_for_me is true
              hfsData["#{state_abr}_check"] = "True"
            else
              hfsData["#{state_abr}_check"] = "False"

            if note
              hfsData["#{state_abr}_notes"] = note
            else
              hfsData["#{state_abr}_notes"] = ""

            if species
              hfsData["#{state_abr}_species_picked"] = species
            else
              hfsData["#{state_abr}_species_picked"] = []

            return next null, hfsData

        (hfsData, next) ->
          HuntinFoolState.upsert hfsData, {honorYear: true, upsert: true, query: null}, (err, hfs) ->
            return next err, hfs

      ], (err, hfs) ->
        if err
          result_failed.error = err
          console.log "Upsert HFS State Application failed with error: ", result_failed
          return res.json result_failed, 401
        result_success.hfs = hfs
        return res.json result_success


    #RRADS Rep Dashboard APIs
    repDashboardAPI: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      payload = req.body
      return res.json {error: "Bad Request missing api identifier"}, 400 unless payload.req_type
      reportsCtrl = reports
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }
      req.body.userId = req.user._id

      async.waterfall [
        (next) ->
          return next null, null unless payload.req_type is "rep_commissions"
          reportsCtrl.repCommissions2 req, (err, results) ->
            return next err if err
            repIdTotalCommissions = 0
            for result in results
              repIdTotalCommissions += result.repIdTotalCommissions if result.repIdTotalCommissions
            totalComm = {repIdTotalCommissions: repIdTotalCommissions}
            return next err, totalComm

        (results, next) ->
          return next null, results unless payload.req_type is "rep_commissions_all"
          reportsCtrl.repCommissions2 req, (err, results) ->
            return next err, results

        (results, next) ->
          return next null, results unless payload.req_type is "rep_catalog_items_by_type"
          types = {}
          reportsCtrl.repPurchases2 req, (err, results) ->
            return next err if err
            for result in results
              type = result.huntCatalogCopy.type
              type = "product" if type is "specialist"
              types[type] = 0 if !types[type]
              types[type]++
            return next null, types

        (results, next) ->
          return next null, results unless payload.req_type is "rep_purchases_all"
          reportsCtrl.repPurchases2 req, (err, results) ->
            return next err, results

        (results, next) ->
          return next null, results unless payload.req_type is "rep_leaderboard"
          reportsCtrl.repLeaderboard req, (err, results) ->
            return next err, results

        (results, next) ->
          return next null, results unless payload.req_type is "rep_users_stats"
          req.body.includeProspects = true
          reportsCtrl.repUsers req, (err, results) ->
            return next err if err
            users = []
            adviser_count = 0
            member_count = 0
            prospect_count = 0
            for result in results
              users.push _.pick(result, "_id", "name", "clientId", "email")
              adviser_count++ if result.isRep
              member_count++ if result.isMember
              prospect_count++ if !result.isMember and !result.isRep
            userStats = {
              adviser_count: adviser_count
              member_count: member_count
              prospect_count: prospect_count
              members: []
            }
            userStats.members = _.sortBy(results, 'created')
            userStats.members = _.first(results,6) #TODO: FIX should be the last 6 but that isn't working?

            return next null, userStats

        (results, next) ->
          return next null, results unless payload.req_type is "rep_users"
          req.body.includeProspects = true
          reportsCtrl.repUsers req, (err, results) ->
            return next err if err
            users = []
            for result in results
              #users.push _.pick(result, "_id", "name", "clientId", "email", "created")
              users.push result
            users = _.sortBy(users, 'created')
            return next null, users

      ], (err, results) ->
        if err
          result_failed.error = err
          console.log "repDashboardAPI failed with error: ", result_failed
          return res.json result_failed, 401
        else
          result_success.results = results
          return res.json result_success


    #RRADS Rep Dashboard APIs
    adminDashboardAPI: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      subTenantId = req.param('sub_tenant_id')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      payload = req.body
      return res.json {error: "Bad Request missing api identifier"}, 400 unless payload.req_type
      reportsCtrl = reports
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }
      req.body.userId = req.user._id

      async.waterfall [
        (next) ->
          return next null, null unless payload.req_type is "oss_purchases"
          req.body.type = "all"
          reportsCtrl.adminPurchases req, (err, results) ->
            return next err, results

        (results, next) ->
          return next null, results unless payload.req_type is "oss_purchases_report"
          if req.body.listing_types?
            req.body.type = req.body.listing_types
          else
            req.body.type = "all"
          reportsCtrl.adminPurchases req, (err, results) ->
            return next err, results

        (results, next) ->
          return next null, results unless payload.req_type is "oss_purchases_stats"
          req.body.type = "all"
          stats = {
            purchases_volume: 0
            counts: {}
          }

          reportsCtrl.adminPurchases req, (err, results) ->
            return next err if err
            purchases_volume = 0
            for purchase in results
              purchases_volume += purchase.amountTotal if purchase.amountTotal
              if !stats.counts[purchase.huntCatalogCopy.type]
                stats.counts[purchase.huntCatalogCopy.type] = 0
              stats.counts[purchase.huntCatalogCopy.type] += 1
            stats.purchases_volume = purchases_volume
            return next err, stats


      ], (err, results) ->
        if err
          result_failed.error = err
          console.log "adminDashboardAPI failed with error: ", result_failed
          return res.json result_failed, 401
        else
          result_success.results = results
          return res.json result_success


    adminQB_API: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      #tenantId = "5684a2fc68e9aa863e7bf182" #hard coded to test QB against live
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId

      payload = req.body
      return res.json {error: "Bad Request missing api identifier"}, 400 unless payload.req_type
      reportsCtrl = reports
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }
      req.body.userId = req.user._id

      async.waterfall [
        (next) ->
          return next null, null unless payload.req_type is "qb_purchases"
          catalog_type = req.param('catalog_type')
          filter_qb_invoice = req.param('filter_qb_invoice')
          filter_qb_expense = req.param('filter_qb_expense')
          balances_due_only = req.param('balances_due_only')
          if catalog_type?
            req.body.type = catalog_type
          else
            req.body.type = "all"
          req.body.filter_qb_invoice = filter_qb_invoice if filter_qb_invoice?
          req.body.filter_qb_expense = filter_qb_expense if filter_qb_expense?
          req.body.balances_due_only = balances_due_only if balances_due_only?
          reportsCtrl.adminPurchases req, (err, results) ->
            return next err, results

        (results, next) ->
          return next null, results unless payload.req_type is "update_qb_fields"
          return res.json {error: "Bad Request missing nrads_purchase_id"}, 400 unless payload.nrads_purchase_id
          Purchase.byId payload.nrads_purchase_id, tenantId, (err, purchase) ->
            return next err, null if err
            return next "Error: NRADS Purchase not found for _id: #{payload.nrads_purchase_id}, tenantId: #{tenantId}" unless purchase
            purchaseData = {
              _id: purchase._id
            }
            if payload.qb_mark_invoiced and !purchase.qb_invoice_recorded?
              purchaseData.qb_invoice_recorded = true
            if payload.qb_mark_expensed_billed and (!purchase.qb_expense_bill_recorded? || !purchase.qb_expense_bill_recorded)
              purchaseData.qb_expense_bill_recorded = true
            if payload.qb_expense_payment_paid and (!purchase.qb_expense_payment_paid? || !purchase.qb_expense_payment_paid)
              purchaseData.qb_expense_payment_paid = true
            if payload.qb_expense_balance_due?
              purchaseData.qb_expense_balance_due = payload.qb_expense_balance_due
            if payload.qb_expense_payment_paid_date
              purchaseData.qb_expense_payment_paid_date = payload.qb_expense_payment_paid_date
            if Object.keys(purchaseData).length > 1
              console.log "Alert: about to update database with purchase data:", purchaseData
              Purchase.upsert purchaseData, {}, (err, purchase) ->
                return next err, null if err
                console.log "Alert: Purchase updated successfully: qb_invoice_recorded: #{purchase.qb_invoice_recorded}, qb_expense_bill_recorded: #{purchase.qb_expense_bill_recorded}, for purchase._id: #{purchase._id}"
                return next err, purchase
            else
              console.log "Alert: NRADS Purchase already marked as qb recorded for _id: #{purchase._id}"
              return next null, purchase

      ], (err, results) ->
        if err
          result_failed.error = err
          console.log "adminQB_API #{payload.req_type} failed with error: ", result_failed
          return res.json result_failed, 401
        else
          result_success.results = results
          return res.json result_success


    #RRADS Admin Applications Report
    adminAllApplications: (req, res) ->
      @log(req)
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      payload = req.body
      huntsCtrl = hunts
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }
      req.body.userId = req.user._id

      async.waterfall [
        (next) ->
          huntsCtrl.adminAllApplications req, (err, results) ->
            return next err, results

      ], (err, results) ->
        if err
          result_failed.error = err
          console.log "adminAllApplications failed with error: ", result_failed
          return res.json result_failed, 401
        else
          result_success.results = results
          return res.json result_success

#******************PRIVATE METHODS*******************


    loginUser: (email, encryptedPassword, tenantId, cb) =>
      User.findByEmailOrUsernamePassword email, email, encryptedPassword, tenantId, {internal: false}, (err, user) =>
        if err
          console.error "Unexpected error on login: ", err
          return cb err if err
        return cb "Unauthorized" if not user or user.password isnt encryptedPassword

        token = new Token {
          token: crypto.randomBytes(64).toString('hex')
          expires: moment().add(1, 'day').toDate()
          userId: user._id
        }

        token.save (err, token) ->
          if err
            console.error "Failed to update local user token:", err
            console.error "Failed to update local user token:" unless token
            return cb err if err
            return cb "Failed to update local user token" unless token

          result = {
            user: _.pick(user, '_id', 'name', 'clientId')
            token: {
              code: token.get 'token'
              expires: token.get 'expires'
            }
          }

          return cb null, result


    hashPassword: (password) ->
      shasum = crypto.createHash('sha1')
      shasum.update(password)
      shasum.update(salt)
      shasum.digest('hex')

    isValidToken: (token) ->
      return token is APITOKEN_RB or token is APITOKEN_VDTEST or token is APITOKEN_MAILCHIMP or token is APITOKEN_MAILCHIMP_VDTEST or token is APITOKEN_RADS_APP

    sanatizeUser: (user) ->
      user.id = user._id
      deleteKeys = ["__v","password","ssn","username","safety","license","agreement", "weight", "eyes", "hair", "height", "dl_state", "field"]
      keys = Object.keys(user)
      for key in keys
        key_lowercase= key.toLowerCase()
        contains = false
        for deleteKey in deleteKeys
          if key_lowercase.indexOf(deleteKey) > -1
            contains = true
            break
        delete user[key] if contains
      return user

    getPurchases: (user, cb) ->
      Purchase.byUserIdIgnoreTenant user._id, (err, purchases) ->
        for purchase in purchases
          delete purchase.userSnapShot #Just optimizing a bit to not send as much data across the api calls
        return cb err, purchases

    getPurchaseById: (purchaseId, tenantId, cb) ->
      Purchase.byIdIgnoreTenant purchaseId, (err, purchase) ->
        return cb err, purchase

    user_upsert: (tUser, cb) ->
      #Check if existing by userId and clientId.
      userId = tUser._id if tUser._id
      userId = tUser.id if tUser.id
      userId = tUser.userId if tUser.userId

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null, null unless userId
          User.findOne({_id: userId, tenantId: tUser.tenantId}).lean().exec (err, user) ->
            return next null, user if user
            return next err

        (user, next) ->
          #Check if user already exists (by clientId and tenant)
          return next null, user if user
          return next null, user unless tUser?.clientId
          User.findOne({type: "local", clientId: tUser.clientId, tenantId: tenantId}).lean().exec (err, user) ->
            return next null, user if user
            return next err

        (user, next) ->
          #Insert or update the user
          if user
            #========UPDATE THE USER========
            tUser._id = user._id
            console.log "user update:", user._id, user.name
            User.upsert tUser, {internal: false, upsert: false}, (err, user) ->
              if user and !err
                console.log "Successfully updated user:", user._id, user.name
              return next err, user
          else
            #========INSERT NEW USER========
            console.log "creating new user:", tUser.email if tUser?.email
            requiredFields = {
              'password': "users first name",
              'email': "users email",
              'tenantId': "user tenant id"
            }
            missing = NavTools.required requiredFields, tUser
            return next "The following parameters are required when creating a new user: " + missing.join(', ') if missing.length

            tUser.type = 'local'
            tUser.needsWelcomeEmail = false
            if tUser.powerOfAttorney == "true" || tUser.powerOfAttorney == "1"
              tUser.powerOfAttorney = true
            else
              tUser.powerOfAttorney = false

            #Assign the new user a Client Id
            Tenant.findById tUser.tenantId, (err, tenant) ->
              return next err if err
              return next "Error: Could not find tenant for tenant id ''#{tUser.tenantId}" unless tenant

              Tenant.getNextClientId tenant._id, (err, newClientId) ->
                return next err if err
                return next {error: "tenant not found for id: #{tUser.tenantId}"} unless newClientId
                tUser.clientId = "#{tenant.clientPrefix}#{newClientId}"

                #Insert the new user
                User.upsert tUser, {internal: false, upsert: true}, (err, user) ->
                  console.log "Successfully created new user:", user._id, user.name
                  return next err, user

      ], (err, user) ->
        return cb err, user

    upsertHuntCatalogItem: (rradsItem, tenantId, cb) ->
      isNewHuntCatalogItem = false
      async.waterfall [

        #Grab the outfitter by clientId
        (next) ->
          if rradsItem?.outfitter?.client_id
            User.byClientId rradsItem.outfitter.client_id, {}, (err, outfitter) ->
              return next "Failed to find outfitter or vendor for purchase item.  Client Id: #{rradsItem.outfitter.client_id}" unless outfitter
              return next err, outfitter
          else if rradsItem?.outfitter?.mongo_id
            User.byId rradsItem.outfitter.mongo_id, {}, (err, outfitter) ->
              return next "Failed to find outfitter or vendor for purchase item. Id: #{rradsItem.outfitter.mongo_id}" unless outfitter
              return next err, outfitter
          else
            console.log "Error: missing outfitter client_id and mongo_id for this item.", rradsItem
            return next "missing outfitter client_id and/or mongo_id"

        #Grab the existing hunt catalog item, or return an new empty container
        (outfitter, next) ->
          HuntCatalog.byHuntNumber rradsItem.catalog_id, tenantId, (err, nradsItem) ->
            return next err if err
            if !nradsItem
              isNewHuntCatalogItem = true
              nradsItem = {}
            next err, outfitter, nradsItem

        #Popluate nnrads hunt catalog item from the rrads hunt catalog item
        (outfitter, nradsItem, next) ->
          try
            nradsItem.rradsObj = JSON.stringify(rradsItem)
            nradsItem.huntNumber = rradsItem.catalog_id
            nradsItem.vendor_product_number = rradsItem.vendor_product_number
            nradsItem.title = rradsItem.title
            nradsItem.outfitter_userId = outfitter._id
            nradsItem.outfitter_name = outfitter.name
            nradsItem.tenantId = tenantId
            if rradsItem.status is "available"
              nradsItem.isActive = true
            else
              nradsItem.isActive = false
            nradsItem.isHuntSpecial = rradsItem.run_special
            if rradsItem.price_non_member > rradsItem.price_member
              nradsItem.memberDiscount = true
            else
              nradsItem.memberDiscount = false
            nradsItem.country = rradsItem.country
            nradsItem.state = rradsItem.state
            nradsItem.area = rradsItem.area
            nradsItem.species = rradsItem.species.name if rradsItem.species
            nradsItem.weapon = rradsItem.weapon.name if rradsItem.weapon
            nradsItem.price = rradsItem.price_member
            nradsItem.fee_processing = rradsItem.price_processing_fee
            nradsItem.price_nom = rradsItem.price_non_member
            nradsItem.rbo_commission = rradsItem.commission_rbo
            nradsItem.rbo_reps_commission = rradsItem.commission_rep
            nradsItem.startDate = new Date(rradsItem.start_at) if rradsItem.start_at
            nradsItem.endDate = new Date(rradsItem.end_at) if rradsItem.end_at
            nradsItem.internalNotes = rradsItem.admin_notes
            nradsItem.pricingNotes = rradsItem.price_description
            nradsItem.description = rradsItem.description
            #nradsItem.huntSpecialMessage = rradsItem.xxxxxxxxxxxxxx
            nradsItem.classification = "#{rradsItem.classification_min}-#{rradsItem.classification_max}"
            nradsItem.classification += ", #{rradsItem.classification_description}" if rradsItem.classification_description
            nradsItem.price_total = rradsItem.price_total #based on member price plus processing fee, licensing, shipping.  NOT include Sales Tax
            nradsItem.price_non_commissionable = rradsItem.price_non_commissionable if rradsItem.price_non_commissionable
            nradsItem.price_commissionable = rradsItem.price_commissionable if rradsItem.price_commissionable
            nradsItem.price_rep_commissionable = rradsItem.price_rep_commissionable if rradsItem.price_rep_commissionable
            nradsItem.refund_policy = rradsItem.refund_policy
            nradsItem.createMemberType = rradsItem.createMemberType
            type = rradsItem.class_name.toLowerCase()
            if type is "membership"
              nradsItem.createMember = true
            else
              nradsItem.createMember = false
            if type is "rep"
              nradsItem.createRep = true
            else
              nradsItem.createRep = false

            #MEMBERSHIPS ARE PURCHASED not as products anymore, except 1 that can be added to the cart.
            if nradsItem.huntNumber?.toLowerCase()?.indexOf('rbsilver') > -1
              nradsItem.createMember = true
              nradsItem.createMemberType = 'silver'
            else if nradsItem.huntNumber?.toLowerCase()?.indexOf('rbgold') > -1
              nradsItem.createMember = true
              nradsItem.createMemberType = 'gold'
            else if nradsItem.huntNumber?.toLowerCase()?.indexOf('rbplatinum') > -1
              nradsItem.createMember = true
              nradsItem.createMemberType = 'platinum'
            else if nradsItem.huntNumber?.toLowerCase()?.indexOf('rbms') > -1
              nradsItem.createMember = true
              nradsItem.createMemberType = 'silver'

            nradsItem.updatedAt = new Date(rradsItem.updated_at)
            nradsItem.createdAt = new Date(rradsItem.created_at)
            nradsItem.status = rradsItem.status
            nradsItem.type = type

            if nradsItem.type is "product" and rradsItem.specific_type is "specialist"
              nradsItem.type = "specialist"

            if rradsItem.membership_group
              #This purchase is being done via the membership onboarding process
              if rradsItem.membership_billing_cycle is "monthly"
                nradsItem.paymentPlan = "subscription_monthly"
              else if rradsItem.membership_billing_cycle is "yearly"
                nradsItem.paymentPlan = "subscription_yearly"
              else
                nradsItem.paymentPlan = "full"

              if rradsItem.membership_group is "membership"
                nradsItem.createMember = true
              else if rradsItem.membership_group is "oss"
                nradsItem.isOSSSale = true
              else if rradsItem.membership_group is "rep"
                nradsItem.createRep = true

            else
              #This purchase is being done via the cart
              nradsItem.paymentPlan = "full"
              if type is "hunt"
                if rradsItem.payment_plan is "monthly"
                  nradsItem.paymentPlan = "hunt"
                else
                  nradsItem.paymentPlan = "full"
              else if ['membership', 'rep'].indexOf(type) < 0
                if rradsItem.payment_plan is "0"
                  nradsItem.paymentPlan = "full"
                else
                  nradsItem.paymentPlan = "months"
              else if type is "membership"
                  nradsItem.paymentPlan = "subscription_yearly"
                  nradsItem.createMember = true
              else if type is "rep"
                nradsItem.paymentPlan = "subscription_monthly"
                nradsItem.createRep = true

          catch ex
            console.log "Caught Error: ",ex
            return next ex.message
          return next null, nradsItem

      ], (err, nradsItem) ->
        return cb err if err
        HuntCatalog.upsert nradsItem, (err, huntCatalogItem) ->
          return cb err, huntCatalogItem


    parseName: (name, onlyFirstAndLast) ->
      names =
        prefix: ""
        first_name: ""
        middle_name: ""
        last_name: ""
        suffix: ""

      if !name
        return names

      if name is "n/a"
        names =
          first_name: "n/a"
          middle_name: ""
          last_name: "n/a"
        return names

      nameSplit = name.split(" ")

      # NEAL E TOKOWITZ
      if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]

      # ARNOLD CHARLES PITTS
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]

      # CLAIRE PHELAN
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          last_name: matches[2]

      # EARL BENEDICT AXALAN MACASAET
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})\s+(\w{4,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2] + ' ' + matches[3]
          last_name: matches[4]

      # JOHN TITO BERTILACCHI JR
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})\s+(\w{1,3})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]
          suffix: matches[4]

      # JAMES W CRAWFORD III
      else if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w{2,})\s+(\w{1,3})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]
          suffix: matches[4]

      # MR. SCOTT ALLEN FINLEY
      else if matches = name.match(/^([\w\.]{1,3})\s+(\w{2,})\s+(\w{2,})\s+(\w{2,})$/)
        names =
          prefix: matches[1]
          first_name: matches[2]
          middle_name: matches[3]
          last_name: matches[4]

      # BRETT D K VISSER
      else if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w)\s+(\w{4,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2] + ' ' + matches[3]
          last_name: matches[4]

      else if nameSplit?.length > 1
        console.log "Could not parse name! Splitting into two halfs:", name
        i=0
        for nm in nameSplit
          names.first_name = "#{names.first_name} #{nameSplit[i]}" if i < nameSplit.length - 1
          names.last_name = "#{names.last_name} #{nameSplit[i]}" if i == nameSplit.length - 1
          i++
          console.log "Parsed names: ", names

      else
        console.log "Could not parse name!:", name

      if onlyFirstAndLast
        names.first_name = "#{names.prefix} #{names.first_name}" if names.prefix?.length
        names.first_name = "#{names.first_name} #{names.middle_name}" if names.middle_name?.length
        names.last_name = "#{names.last_name} #{names.suffix}" if names.suffix?.length

      return names


    formatMoneyStr: (number) ->
      number = number.toFixed(2) if number
      return number unless number?.toString()
      numberAsMoneyStr = number.toString()
      mpStrArry = numberAsMoneyStr.split(".")
      if mpStrArry?.length > 0 and mpStrArry[1]?.length == 1
        numberAsMoneyStr = "#{number}0"
      else
        numberAsMoneyStr = "#{number}"
      return "$#{numberAsMoneyStr}"

    formatDateStr: (date) ->
      dformat = [date.getMonth()+1, date.getDate(), date.getFullYear()].join('/')
      return dformat


    #RUN TEST
    run_test: (req, res) ->
      @log(req)
      usersCtrl = users
      apitoken = req.param('token')
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(apitoken)
      tenantId = req.param('tenantId')
      return res.json {error: "Bad Request missing tenant identifier"}, 400 unless tenantId
      encryptedTimestamp = req.param('stamp')
      stamp = Secure.validate_rads_stamp encryptedTimestamp
      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid

      body = req.body
      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      result_success.message = "API test with toke and stamp, successful."
      return res.json result_success


      User.byClientId req.param('clientId'), {}, (err, user) ->
        if err
          result_failed.error = err
          console.log "Welcome email failed to send with error: ", result_failed
          return res.json result_failed, 500
        usersCtrl.sendWelcomeEmail req.tenant, user, null, (err) ->
          console.log "Welcome email failed to send with error: ", err if err
          console.log "Welcome email sent." unless err

          result_success.message = "Welcome email request sent to Mandrill"
          return res.json result_success

  }

  _.bindAll.apply _, [API].concat(_.functions(API))
  return API
