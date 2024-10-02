_ = require "underscore"
async = require "async"
moment = require "moment"
request = require "request"
https = require 'https'

module.exports = (APITOKEN_RB, APITOKEN_VDTEST, RollingBonesTenantId, VerdadTestTenantId, NavTools,
  salt, Secure, Token, HuntinFoolState, authorizenetapi, RRADS_API_BASEURL, RRADS_API_BASEURL_STAGING,
  Tenant, User, HuntCatalog, Purchase, ServiceRequest, huntCatalogs) ->

  API_RADS = {

    log: (reqData, resData) ->
      logIt = false
      if logIt and reqData
        console.log "API Req params: ", reqData.params
        console.log "API Req body: ", reqData.body
        if !reqData.body and !reqData.params
          console.log "API Req: ", reqData
      else if logIt and resData
        console.log "API response: ", resData
      else
        return

    returnError: (errMsg, err, errCode, res, cb) ->
      result_failed = {
        error: err
        errMsg: errMsg
        status: "failed"
      }
      console.log "API Endpoint returning error: ", result_failed
      if cb
        return cb result_failed
      else
        return res.json result_failed, 400

    pushTenantToRRADS: (req, cb) ->
      @tenant_create req, (err, results) ->
        return cb err, results

    tenant_create: (req, res) ->
      @log(req)
      cb = null
      if typeof res is "function"
        cb = res
        tenant = req.tenant
        tenantId = tenant._id
        tenant_name = tenant.name
        tenant_client_prefix = tenant.clientPrefix
      else
        #not yet implemented.  Currently only called directly from the tenant controller
        tenantId = req.param('tenantId')
        tenant = req.body

      @assignAPIToken tenant, tenantId, (err, apitoken) =>
        return @returnError "", "Bad Request missing tenant identifier", 400, res, cb unless tenantId
        return @returnError "", "Bad Request missing apitoken for tenantId", 400, res, cb unless apitoken

        result_success = {
          results: ""
          status: "successful"
        }
        result_failed = {
          error: ""
          status: "failed"
        }

        params = {}
        body = {
          nrads_id: tenantId
          token: apitoken
          name: tenant_name
          catalog_id_prefix: tenant_client_prefix
        }

        @post tenantId, "/api/tenants", "POST", params, body, (err, results) =>
          return @returnError "", err, 500, res, cb if err
          result_success.results = results
          if cb
            return cb null, result_success
          else
            return res.json result_success


    user_upsert_rads: (req, res) ->
      #TODO: hit both the currentUser and the parent
      @log(req)

      cb = null
      if typeof res is "function"
        cb = res
        tenantId = req.params.tenantId
        userId = req.params._id
      else
        tenantId = req.param('tenantId')
        userId = req.param('_id')

      @assignAPIToken req.tenant, tenantId, (err, apitoken) =>
        return @returnError "", "Bad Request missing tenant identifier", 400, res, cb unless tenantId
        return @returnError "", "Bad Request missing apitoken for tenantId", 400, res, cb unless apitoken
        return @returnError "", "Bad Request missing userId", 400, res, cb unless userId

        body = req.body
        result_success = {
          results: ""
          status: "successful"
        }
        result_failed = {
          error: ""
          status: "failed"
        }

        params = {}
        body = {
          _id: userId
          token: apitoken
          tenant_id: tenantId
        }

        @post tenantId, "/api/users", "POST", params, body, (err, results) =>
          return @returnError "", err, 500, res, cb if err
          result_success.results = results
          if cb
            return cb null, result_success
          else
            return res.json result_success

    reassign_rep_downline_all: (req, res) ->
      @log(req)
      @user_update_rrads_partial req, res

    user_update_rrads_partial: (req, res) ->
      @log(req)
      cb = null
      if typeof res is "function"
        cb = res
        tenantId = req.params.tenantId
        userId = req.params._id
        parentId = req.params.parentId
        clientId = req.params.clientId
      else if req.body
        tenantId = req.body['tenantId']
        userId = req.body['_id']
        parentId = req.body['parentId']
        clientId = req.body['clientId']
      else
        tenantId = req.param('tenantId')
        userId = req.param('_id')
        parentId = req.params('parentId')
        clientId = req.params('clientId')

      @assignAPIToken req.tenant, tenantId, (err, apitoken) =>
        return @returnError "", err, 500, res, cb if err
        return @returnError "", "Bad Request missing tenant identifier", 400, res, cb unless tenantId
        return @returnError "", "Bad Request missing apitoken for tenantId", 400, res, cb unless apitoken
        return @returnError "", "Bad Request missing userId", 400, res, cb unless userId
        return @returnError "", "Bad Request missing clientId", 400, res, cb unless clientId
        result_success = {
          results: ""
          status: "successful"
        }
        result_failed = {
          error: ""
          status: "failed"
        }
        params = {}
        body = {
          id: userId
          token: apitoken
          tenantId: tenantId
          parentId: parentId
          clientId: clientId
        }
        if req.params?
          keys = Object.keys(req.params)
          for key in keys
            body[key] = req.params[key]
        if req.body?
          keys = Object.keys(req.body)
          for key in keys
            body[key] = req.body[key]
        @post tenantId, "/api/users/#{userId}/update_user_partial", "POST", params, body, (err, results) =>
          return @returnError "", err, 500, res, cb if err
          try
            results = JSON.parse(results)
          catch err
            return @returnError "", err, 500, res, cb if err
          if results?.error?.length
            return @returnError "", results.error, 500, res, cb
          result_success.results = results
          if cb
            return cb null, result_success
          else
            return res.json result_success


    user_refresh_from_rrads: (req, res) ->
      #TODO: hit both the currentUser and the parent
      @log(req)

      cb = null
      if typeof res is "function"
        cb = res
        tenantId = req.params.tenantId
        clientId = req.params.clientId
      else
        tenantId = req.param('tenantId')
        clientId = req.param('clientId')

      @assignAPIToken req.tenant, tenantId, (err, apitoken) =>

        return @returnError "", "Bad Request missing tenant identifier", 400, res unless tenantId
        return @returnError "", "Bad Request missing apitoken for tenantId", 400, res unless apitoken
        return @returnError "", "Bad Request missing clientId", 400, res unless clientId

        body = req.body
        result_success = {
          results: ""
          status: "successful"
        }
        result_failed = {
          error: ""
          status: "failed"
        }

        params = {
          tenantId: tenantId
          clientId: clientId
          token: apitoken
        }
        body = {
          tenantId: tenantId
          clientId: clientId
          token: apitoken
        }

        @post tenantId, "/api/users", "GET", params, body, (err, results) =>
          return @returnError "", err, 500, res, cb if err
          caughtError = false
          try
            results = JSON.parse(results)
          catch ex
            console.log "ERROR: THIS ERROR OCCURRED LIKELY BECAUSE THE RRADS API IS NOT AVAILABLE"
            console.log "results: ", results
            console.log "Error: ", ex
            err = ex
            caughtError = true
          return @returnError "", err, 500, res, cb if err

          user_rrads = results.user

          User.byClientId clientId, tenantId, (err, tUser) =>
            return @returnError "", err, 500, res, cb if err
            return @returnError "", "User not found for clientId: #{clientId}", 500, res, cb unless tUser
            return @returnError "", "RRADs User not found for clientId: #{clientId}", 500, res, cb unless user_rrads

            updateUser = false

            userData = {}
            userData._id = tUser._id

            if !tUser.phone_cell and user_rrads.phone_number
              updateUser = true
              userData.phone_cell = user_rrads.phone_number
            else if tUser.phone_cell isnt user_rrads.phone_number
              updateUser = true
              userData.phone_cell = user_rrads.phone_number

            if !tUser.physical_address and user_rrads.physical_address?.address_1
              updateUser = true
              userData.physical_address = user_rrads.physical_address.address_1 if user_rrads?.physical_address?.address_1
              userData.physical_address += "#{user_rrads.physical_address.address_1}, #{user_rrads.physical_address.address_2}" if user_rrads?.physical_address?.address_2
              userData.physical_city = user_rrads.physical_address.city if user_rrads?.physical_address?.city
              userData.physical_country = user_rrads.physical_address.country if user_rrads?.physical_address?.country
              userData.physical_postal = user_rrads.physical_address.zip if user_rrads?.physical_address?.zip
              userData.physical_state = user_rrads.physical_address.state if user_rrads?.physical_address?.state
            else if user_rrads.physical_address?.address_1 and tUser.physical_address isnt user_rrads.physical_address?.address_1
              updateUser = true
              userData.physical_address = user_rrads.physical_address.address_1 if user_rrads?.physical_address?.address_1
              userData.physical_address += "#{user_rrads.physical_address.address_1}, #{user_rrads.physical_address.address_2}" if user_rrads?.physical_address?.address_2
              userData.physical_city = user_rrads.physical_address.city if user_rrads?.physical_address?.city
              userData.physical_country = user_rrads.physical_address.country if user_rrads?.physical_address?.country
              userData.physical_postal = user_rrads.physical_address.zip if user_rrads?.physical_address?.zip
              userData.physical_state = user_rrads.physical_address.state if user_rrads?.physical_address?.state

            if !tUser.mail_address and user_rrads.mailing_address?.address_1
              updateUser = true
              userData.mail_address = user_rrads.mailing_address.address_1 if user_rrads?.mailing_address?.address_1
              userData.mail_address += "#{user_rrads.mailing_address.address_1}, #{user_rrads.mailing_address.address_2}" if user_rrads?.mailing_address?.address_2
              userData.mail_city = user_rrads.mailing_address.city if user_rrads?.mailing_address?.city
              userData.mail_country = user_rrads.mailing_address.country if user_rrads?.mailing_address?.country
              userData.mail_postal = user_rrads.mailing_address.zip if user_rrads?.mailing_address?.zip
              userData.mail_state = user_rrads.mailing_address.state if user_rrads?.mailing_address?.state
            else if user_rrads.mailing_address?.address_1 and tUser.mail_address isnt user_rrads.mailing_address?.address_1
              updateUser = true
              userData.mail_address = user_rrads.mailing_address.address_1 if user_rrads?.mailing_address?.address_1
              userData.mail_address += "#{user_rrads.mailing_address.address_1}, #{user_rrads.mailing_address.address_2}" if user_rrads?.mailing_address?.address_2
              userData.mail_city = user_rrads.mailing_address.city if user_rrads?.mailing_address?.city
              userData.mail_country = user_rrads.mailing_address.country if user_rrads?.mailing_address?.country
              userData.mail_postal = user_rrads.mailing_address.zip if user_rrads?.mailing_address?.zip
              userData.mail_state = user_rrads.mailing_address.state if user_rrads?.mailing_address?.state

            if !tUser.shipping_address and user_rrads.shipping_address?.address_1
              updateUser = true
              userData.shipping_address = user_rrads.shipping_address.address_1 if user_rrads?.shipping_address?.address_1
              userData.shipping_address += "#{user_rrads.shipping_address.address_1}, #{user_rrads.shipping_address.address_2}" if user_rrads?.shipping_address?.address_2
              userData.shipping_city = user_rrads.shipping_address.city if user_rrads?.shipping_address?.city
              userData.shipping_country = user_rrads.shipping_address.country if user_rrads?.shipping_address?.country
              userData.shipping_postal = user_rrads.shipping_address.zip if user_rrads?.shipping_address?.zip
              userData.shipping_state = user_rrads.shipping_address.state if user_rrads?.shipping_address?.state
            else if user_rrads.shipping_address?.address_1 and tUser.shipping_address isnt user_rrads.shipping_address?.address_1
              updateUser = true
              userData.shipping_address = user_rrads.shipping_address.address_1 if user_rrads?.shipping_address?.address_1
              userData.shipping_address += "#{user_rrads.shipping_address.address_1}, #{user_rrads.shipping_address.address_2}" if user_rrads?.shipping_address?.address_2
              userData.shipping_city = user_rrads.shipping_address.city if user_rrads?.shipping_address?.city
              userData.shipping_country = user_rrads.shipping_address.country if user_rrads?.shipping_address?.country
              userData.shipping_postal = user_rrads.shipping_address.zip if user_rrads?.shipping_address?.zip
              userData.shipping_state = user_rrads.shipping_address.state if user_rrads?.shipping_address?.state

            userData.physical_country = "United States" if userData.physical_country? is "United States of America"
            userData.mail_country = "United States" if userData.mail_country? is "United States of America"
            userData.shipping_country = "United States" if userData.shipping_country? is "United States of America"

            if updateUser
              User.upsert userData, {upsert: false, multi: false}, (err, results) =>
                return @returnError "", err, 500, res, cb if err
                result_success.results = "User refreshed from RRADS successfully."
                if cb
                  return cb null, result_success
                else
                  return res.json result_success
            else
              result_success.results = "No new user data to refresh. Refreshed from RRADS successfully."
              if cb
                return cb null, result_success
              else
                return res.json result_success


    return_pending_process: (req, res) ->
      @log(req)

      result_success = {
        status: "successful"
      }
      result_failed = {
        error: ""
        status: "failed"
      }

      cb = null
      if typeof res is "function"
        cb = res
        tenantId = req.tenantId
        status = req.status
        errorFull = req.error
        error = req.errorMsg
        pending_process_uid = req.pending_process_uid
        purchase_id = req.purchase_id
        membership_id = req.membership_id
        auto_renew = req.auto_renew
        resultsRsp = req.results
        inStorePurchase = req.inStorePurchase
      else
        tenantId = req.param('tenantId')
        status = req.param('status')
        errorFull = req.param('error')
        error = req.param('errorMsg')
        purchase_id = req.param('purchase_id')
        membership_id = req.param('membership_id')
        auto_renew = req.param('auto_renew')
        resultsRsp = req.param('results')
        inStorePurchase = req.param('inStorePurchase')

      Tenant.findById tenantId, (err, tenant) =>
        return cb err if err
        #Should be backward compatible
        if tenant?.rrads_use_production_token is true
          apitoken = APITOKEN_RB
        else if tenant?.rrads_use_production_token is false
          apitoken = APITOKEN_VDTEST
        else if tenantId is RollingBonesTenantId
          apitoken = APITOKEN_RB
        else if tenantId is VerdadTestTenantId
          apitoken = APITOKEN_VDTEST

        return @returnError "", "Bad Request missing tenant identifier", 400, res, cb unless tenantId
        return @returnError "", "Bad Request missing apitoken for tenantId", 400, res, cb unless apitoken
        return @returnError "", "Bad Request missing purchase_id", 400, res, cb unless purchase_id
        return @returnError "", "Bad Request missing status", 400, res, cb unless status

        body = req.body
        getPurchaseData = (resultRsp, done) ->
          Purchase.byId resultRsp.purchaseId, tenant._id, (err, purchase) ->
            return done err, purchase
        async.mapSeries resultsRsp, getPurchaseData, (err, results) =>
          if err
            #don't through an error, just continue
            console.log "Error occurred sending purchase details back to RRADS: ", err
            results = []

          keys = ["_id", "createdAt","orderNumber","invoiceNumber","purchaseNotes","start_hunt_date",
            "basePrice","options_total","tags_licenses","fee_processing","shipping",
            "sales_tax","amountTotal","amount",
            "amountTotal","paymentMethod","paymentUsed"
          ]
          summary = []
          for result in results
            purchaseData = _.pick(result, keys)
            huntCatalogCopy = result.huntCatalogCopy[0]
            huntCatalogCopy.title = huntCatalogCopy.title.replace(/…/g,'...')
            purchaseData['catalogNumber'] = huntCatalogCopy.huntNumber
            purchaseData['type'] = huntCatalogCopy.type
            purchaseData['title'] = huntCatalogCopy.title
            purchaseData['num_title'] = "#{huntCatalogCopy.huntNumber}, #{huntCatalogCopy.title}"
            purchaseData['paymentPlan'] = huntCatalogCopy.paymentPlan
            purchaseData['location'] = "#{huntCatalogCopy.state}, #{huntCatalogCopy.country}" if huntCatalogCopy.state
            purchaseData['species'] = huntCatalogCopy.species if huntCatalogCopy.species
            purchaseData['options_total'] = 0
            if result.options?.length
              purchaseData['options'] = ""
              for option in result.options
                key = option.title.replace(/…/g,'...')
                value = option.specific_type.replace(/…/g,'...')
                purchaseData['options'] = "#{key}: #{value},  #{purchaseData['options'].replace(/…/g,'...')}"
                purchaseData['options_total'] += option.price

            summary.push purchaseData

          params = {
            token: apitoken
          }
          body = {
            purchase_id: purchase_id
            status: status
            error: error
            errorFull: errorFull
            token: apitoken
          }
          body.membership_id = membership_id if membership_id
          body.auto_renew = auto_renew if auto_renew?
          body.summary = summary
          body.inStorePurchase = inStorePurchase if inStorePurchase
          post_url = "/api/pending_processes/#{pending_process_uid}"
          console.log "Alert: calling rrads api return_pending_process() with post_url: ", post_url

          @post tenantId, post_url, "PUT", params, body, (err, results) =>
            return @returnError "", err, 500, res, cb if err
            result_success.results = results
            if cb
              return cb null, result_success
            else
              return res.json result_success




    post: (tenantId, path, method, params, body, cb) ->
      logDetails = false
      Tenant.findById tenantId, (err, tenant) =>
        return cb err if err
        #if tenant.rrads_api_base_url?
        #  url_domain = tenant.rrads_api_base_url
        if tenant?.rrads_use_production_token
          url_domain = RRADS_API_BASEURL
        else
          url_domain = RRADS_API_BASEURL_STAGING

        postData = JSON.stringify(body)
        options =
          hostname: url_domain
          port: 443
          path: path
          method: method
          headers:
            'Content-Type': 'application/json'
            'Content-Length': postData.length

        if logDetails
          console.log "HTTP.REQUEST Options: ", options
          console.log "HTTP.REQUEST Params: ", params
          console.log "HTTP.REQUEST Body: ", body
        req = https.request(options, (res) ->
          console.log 'response statusCode:', res.statusCode
          console.log 'response headers:', res.headers
          fullResponse = ""
          res.on 'data', (chunk) ->
            #console.log('Response chunk: ' + chunk)
            fullResponse+=chunk
          res.on 'end', () ->
            console.log "Finished and full response content is:", fullResponse if logDetails
            return cb null, fullResponse
        )
        req.on 'error', (err) ->
          console.log "API RBO RRADS POST Error: ", err
          return cb err

        #Send the request
        req.write postData
        req.end()


    assignAPIToken: (tenant, tenantId, cb) ->
      async.waterfall [
        (next) ->
          return next null, tenant if tenant
          Tenant.findById tenantId, (err, tenant) ->
            return next err, tenant

      ], (err, tenant) ->
        return cb err if err
        apitoken = null

        if tenant?.rrads_use_production_token is true
          apitoken = APITOKEN_RB
        else if tenant?.rrads_use_production_token is false or !tenant?.rrads_use_production_token?
          apitoken = APITOKEN_VDTEST
        else if tenantId.toString() is RollingBonesTenantId
          apitoken = APITOKEN_RB
        else if tenantId.toString() is VerdadTestTenantId
          apitoken = APITOKEN_VDTEST
        return cb null, apitoken

  }

  _.bindAll.apply _, [API_RADS].concat(_.functions(API_RADS))
  return API_RADS
