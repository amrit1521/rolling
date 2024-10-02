_ = require "underscore"
async = require "async"
crypto = require "crypto"
moment = require "moment"
amqp        = require "amqp"
AuthorizeNet  = require 'authorizenet'
AuthContracts = AuthorizeNet.APIContracts
AuthControllers = AuthorizeNet.APIControllers
AuthConstants = AuthorizeNet.Constants

module.exports = (APITOKEN, HuntCatalog, User, Purchase, CreditCardClients, Tenant, authorizenetapi,
  GotMyTagTenantId, GotMyTagDevTenantId, RollingBonesTenantId, RollingBonesTestTenantId, VerdadTestTenantId,
  OSSTenantId, OSSTestTenantId, ServiceRequest, mailchimpapi, RBO_AUTHNET_PUBLIC_KEY) ->

  HuntCatalogs = {

    adminIndex: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Admin user required'}, 400 unless req?.user?.isAdmin or req?.user?.userType is 'tenant_manager'
      group_outfitterIds = null
      if req.user?.group_outfitterIds
        group_outfitterIds = req.user.group_outfitterIds
      else if req.param('outfitterId')
        group_outfitterIds = [req.param('outfitterId')]

      HuntCatalog.byTenant req.tenant._id, (err, huntCatalogs) ->
        return res.json err, 500 if err

        addHuntCatalog = (huntCatalog, done) ->
          if req.user.userType is 'tenant_manager' or group_outfitterIds?.length
            allowed = false
            for outfitterId in group_outfitterIds
              if huntCatalog.outfitter_userId?.toString() is outfitterId.toString()
                allowed = true
                break
            if allowed
              return done err, huntCatalog
            else
              return done err, null
          else
            return done err, huntCatalog


        async.mapSeries huntCatalogs, addHuntCatalog, (err, huntCatalogs) ->
          return res.json err, 500 if err
          tHuntCatalogs = []
          for hc in huntCatalogs
            tHuntCatalogs.push hc if hc
          huntCatalogs = tHuntCatalogs
          res.json huntCatalogs


    adminRead: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Admin user required'}, 400 unless req?.user?.isAdmin or req?.user?.userType is 'tenant_manager'
      HuntCatalog.byId req.param('id'), (err, huntCatalog) ->
        return res.json err, 500 if err
        return res.json {error: "Tenant unauthorized to retrieve this hunt catalog."}, 500 unless huntCatalog?.tenantId.toString() is req?.tenant?._id.toString()
        if !req.user.isAdmin and req.user.userType is 'tenant_manager'
          allowed = false
          for outfitterId in req.user.group_outfitterIds
            if huntCatalog.outfitter_userId?.toString() is outfitterId.toString()
              allowed = true
              break
          if allowed
            return res.json huntCatalog
          else
            return res.json "User unauthorized to retrieve this hunt catalog.", 500
        else
          return res.json huntCatalog

    index: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      HuntCatalog.byTenant req.tenant._id, (err, huntCatalogs) ->
        return res.json err, 500 if err

        addHuntCatalog = (huntCatalog, done) ->
          if huntCatalog.isActive
            tHuntCatalog = _.pick(huntCatalog, '_id','huntNumber','title','isHuntSpecial','memberDiscount','country',
              'state','area','species','weapon','price','startDate','endDate','pricingNotes','description','huntSpecialMessage',
              'classification','updatedAt','status','type', 'fee_processing', 'price_total')
            tHuntCatalog.media = huntCatalog.media if huntCatalog.media
            delete tHuntCatalog.startDate unless huntCatalog.startDate and new Date(huntCatalog.startDate.toISOString()) > new Date("2000-01-01")
            delete tHuntCatalog.endDate unless huntCatalog.endDate and new Date(huntCatalog.endDate.toISOString()) > new Date("2000-01-01")
            return done err, tHuntCatalog
          else
            return done err, null

        async.mapSeries huntCatalogs, addHuntCatalog, (err, huntCatalogs) ->
          return res.json err, 500 if err
          tHuntCatalogs = []
          for huntCatalog in huntCatalogs
            tHuntCatalogs.push huntCatalog if huntCatalog
          res.json tHuntCatalogs

    read: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      HuntCatalog.byId req.param('id'), (err, huntCatalog) ->
        return res.json err, 500 if err
        return res.json {error: "Tenant unauthorized to retrieve this hunt catalog."}, 500 unless huntCatalog?.tenantId.toString() is req?.tenant?._id.toString()
        #Remove admin only fields
        delete huntCatalog.createMember
        res.json huntCatalog

    #Will be obselete once new RRADS shopping cart is live
    purchase: (req, res) ->
      return res.json {error: 'Invalid Item. All purchases must be done through RADS.'}, 400


    sendEmailPurchaseNotifications_PerCartEntry: (user, outfitter, huntCatalog, purchaseId, tenantId, emailParams, cb) ->
      if !user.email
        console.err "Purchase Error sending email receipt:  User email not found for user: ", user._id, user.clientId, user.name
        return cb null, null if cb?
        return

      email_from_name = emailParams.email_from_name if emailParams?.email_from_name
      email_template_prefix = emailParams.email_template_prefix if emailParams?.email_template_prefix
      inStorePurchase = emailParams.inStorePurchase if emailParams?.inStorePurchase

      Purchase.byId purchaseId, tenantId, (err, purchaseItem) ->
        if err or !purchaseItem
          console.err "Purchase Error sending email receipt for purchaseId: #{purchaseId} ",  err
          return cb null, null if cb?
          return

        formatMoneyStr = (number) ->
          return number if isNaN(number)
          try
            number = parseFloat(number) unless typeof number is 'number'
            number = number.toFixed(2) if number
            return number unless number?.toString()
            numberAsMoneyStr = number.toString()
            mpStrArry = numberAsMoneyStr.split(".")
            if mpStrArry?.length > 0 and mpStrArry[1]?.length == 1
              numberAsMoneyStr = "#{number}0"
            else
              numberAsMoneyStr = "$#{number}"
            return numberAsMoneyStr
          catch ex
            console.log "Caught error sendEmailPurchaseNotifications_PerCartEntry(): ", ex
            return "$#{number}"

        hasOptionAddOns = false
        purchaseItem.options_total = 0
        purchaseItem.options_rbo_commissions_total = 0
        options_descriptions = ""
        if purchaseItem.options?.length
          hasOptionAddOns = true
          inc = 0
          for option in purchaseItem.options
            purchaseItem.options_total += option.price
            purchaseItem.options_rbo_commissions_total += option.commission if option.commission
            option_desc = "#{option.title}: #{option.specific_type}"
            #option_desc = "#{option.title}: #{option.specific_type} (#{formatMoneyStr(option.price)})"
            if inc is 0
              options_descriptions = "#{option_desc}"
            else
              options_descriptions = "#{options_descriptions}, #{option_desc}"
            inc++
        purchaseItem.options_totalToOutfitter = purchaseItem.options_total - purchaseItem.options_rbo_commissions_total

        total_price = purchaseItem.basePrice
        total_price += purchaseItem.options_total if purchaseItem.options_total
        total_price += purchaseItem.tags_licenses if purchaseItem.tags_licenses
        total_price += purchaseItem.fee_processing if purchaseItem.fee_processing
        total_price += purchaseItem.shipping if purchaseItem.shipping
        total_price += purchaseItem.sales_tax if purchaseItem.sales_tax

        basePrice = formatMoneyStr(purchaseItem.basePrice) if purchaseItem.basePrice
        options_total = formatMoneyStr(purchaseItem.options_total) if purchaseItem.options_total
        tags_licenses = formatMoneyStr(purchaseItem.tags_licenses) if purchaseItem.tags_licenses
        fee_processing = formatMoneyStr(purchaseItem.fee_processing) if purchaseItem.fee_processing
        shipping = formatMoneyStr(purchaseItem.shipping) if purchaseItem.shipping
        sales_tax = formatMoneyStr(purchaseItem.sales_tax) if purchaseItem.sales_tax
        total_price = formatMoneyStr(total_price)
        amount = formatMoneyStr(purchaseItem.amount) #today's payment

        #to Outfitter or Vendor
        totalToOutfitter = formatMoneyStr(purchaseItem.totalToOutfitter)
        options_totalToOutfitter = formatMoneyStr(purchaseItem.options_totalToOutfitter)
        remainingDepositToSend = formatMoneyStr(purchaseItem.remainingDepositToSend)
        clientOwes = formatMoneyStr(purchaseItem.clientOwes)

        #to RBO
        commission = formatMoneyStr(purchaseItem.commission)
        commissions_addition_from_options = formatMoneyStr(purchaseItem.options_rbo_commissions_total)

        outfitterEmail = outfitter.email if outfitter.email
        outfitterEmail = outfitter.business_email if outfitter.business_email
        #remove when name is duplicated
        outfitter_name = ""
        if outfitter?.name
          outfitter_name = outfitter.name
          outfitter_name_first_half = outfitter_name.substr(0, outfitter_name.length/2).trim()
          outfitter_name_second_half = outfitter_name.substr(outfitter_name.length/2, outfitter_name.length).trim()
          if outfitter_name_first_half is outfitter_name_second_half
            outfitter_name = outfitter_name_first_half

        merge_vars = {
          "purchase_orderNumber": ""
          "purchase_invoiceNumber": ""
          "outfitter_name": outfitter_name
          "huntCatalog_title": ""
          "huntCatalog_huntNumber": ""
          "huntCatalog_vendor_product_number": ""
          "purchase_options_descriptions": ""
          "purchase_notes": ""
          "purchase_user_first_name": ""
          "purchase_user_last_name": ""
          "purchase_user_clientId": ""
          "purchase_user_email": ""
          "purchase_user_phone_cell": ""
          "purchase_user_mail_address": ""
          "purchase_user_mail_city": ""
          "purchase_user_mail_state": ""
          "purchase_user_mail_country": ""
          "purchase_user_mail_postal": ""
          "purchase_user_shipping_address": ""
          "purchase_user_shipping_city": ""
          "purchase_user_shipping_state": ""
          "purchase_user_shipping_country": ""
          "purchase_user_shipping_postal": ""
          "purchase_user_physical_address": ""
          "purchase_user_physical_city": ""
          "purchase_user_physical_state": ""
          "purchase_user_physical_country": ""
          "purchase_user_physical_postal": ""
          "purchase_basePrice": ""
          "purchase_options_total": ""
          "purchase_tags_licenses": ""
          "purchase_fee_processing": ""
          "purchase_shipping" : ""
          "purchase_sales_tax" : ""
          "purchase_TOTAL_PRICE": ""
          "purchase_amount": ""
          "purchase_totalToOutfitter": ""
          "purchase_options_totalToOutfitter": ""
          "purchase_remainingDepositToSend": ""
          "purchase_clientOwes": ""
          "purchase_commission": ""
          "purchase_commission_additional_from_options": ""
          "hasPurchaseNotes" : false
          "hasMailingAddress": false
          "hasShippingAddress": false
          "hasPhysicalAddress": false
        }
        merge_vars["purchase_orderNumber"] = purchaseItem.orderNumber if purchaseItem.orderNumber
        merge_vars["purchase_invoiceNumber"] = purchaseItem.invoiceNumber if purchaseItem.invoiceNumber
        merge_vars["outfitter_name"] = outfitter_name
        merge_vars["huntCatalog_title"] = huntCatalog.title if huntCatalog.title
        merge_vars["huntCatalog_huntNumber"] = huntCatalog.huntNumber if huntCatalog.huntNumber
        merge_vars["huntCatalog_vendor_product_number"] = huntCatalog.vendor_product_number if huntCatalog.vendor_product_number
        merge_vars["purchase_options_descriptions"] = options_descriptions if options_descriptions
        merge_vars["purchase_notes"] = purchaseItem.purchaseNotes if purchaseItem.purchaseNotes
        merge_vars["purchase_user_first_name"] = user.first_name if user.first_name
        merge_vars["purchase_user_last_name"] = user.last_name if user.last_name
        merge_vars["purchase_user_clientId"] = user.clientId if user.clientId
        merge_vars["purchase_user_email"] = user.email if user.email
        merge_vars["purchase_user_phone_cell"] = user.phone_cell if user.phone_cell
        merge_vars["purchase_user_mail_address"] = user.mail_address if user.mail_address
        merge_vars["purchase_user_mail_city"] = user.mail_city if user.mail_city
        merge_vars["purchase_user_mail_state"] = user.mail_state if user.mail_state
        merge_vars["purchase_user_mail_postal"] = user.mail_postal if user.mail_postal
        merge_vars["purchase_user_mail_country"] = user.mail_country if user.mail_country
        merge_vars["purchase_user_shipping_address"] = user.shipping_address if user.shipping_address
        merge_vars["purchase_user_shipping_city"] = user.shipping_city if user.shipping_city
        merge_vars["purchase_user_shipping_state"] = user.shipping_state if user.shipping_state
        merge_vars["purchase_user_shipping_postal"] = user.shipping_postal if user.shipping_postal
        merge_vars["purchase_user_shipping_country"] = user.shipping_country if user.shipping_country
        merge_vars["purchase_user_physical_address"] = user.physical_address if user.physical_address
        merge_vars["purchase_user_physical_city"] = user.physical_city if user.physical_city
        merge_vars["purchase_user_physical_state"] = user.physical_state if user.physical_state
        merge_vars["purchase_user_physical_postal"] = user.physical_postal if user.physical_postal
        merge_vars["purchase_user_physical_country"] = user.physical_country if user.physical_country

        merge_vars["purchase_basePrice"] = basePrice if basePrice
        merge_vars["purchase_options_total"] = options_total if options_total
        merge_vars["purchase_tags_licenses"] = tags_licenses if tags_licenses
        merge_vars["purchase_fee_processing"] = fee_processing if fee_processing
        merge_vars["purchase_shipping"] = shipping if shipping
        merge_vars["purchase_sales_tax"] = sales_tax if sales_tax
        merge_vars["purchase_TOTAL_PRICE"] = total_price if total_price
        merge_vars["purchase_amount"] = amount if amount

        merge_vars["purchase_totalToOutfitter"] = totalToOutfitter if totalToOutfitter
        merge_vars["purchase_options_totalToOutfitter"] = options_totalToOutfitter if options_totalToOutfitter
        merge_vars["purchase_remainingDepositToSend"] = remainingDepositToSend if remainingDepositToSend
        merge_vars["purchase_clientOwes"] = clientOwes if clientOwes

        merge_vars["purchase_commission"] = commission if commission
        merge_vars["purchase_commission_additional_from_options"] = commissions_addition_from_options if commissions_addition_from_options

        merge_vars["hasOptionAddOns"] = hasOptionAddOns
        merge_vars["hasMailingAddress"] = true if user.mail_address
        merge_vars["hasShippingAddress"] = true if user.shipping_address
        merge_vars["hasPhysicalAddress"] = true if user.physical_address
        merge_vars["hasPurchaseNotes"] = true if purchaseItem.purchaseNotes?.length

        tenant = null
        repDisabled = false
        whitelabelHuntsOnly = false

        async.waterfall [

          #Get the tenant and rep for this user
          (next) ->
            Tenant.findById tenantId, (err, t_tenant) ->
              console.log "Error purchase notification: ", err if err
              tenant = t_tenant if t_tenant
              tenant.tmp_email_template_prefix = email_template_prefix if email_template_prefix
              tenant.tmp_email_from_name = email_from_name if email_from_name
              repDisabled = true if tenant.disableReps? and tenant.disableReps is true
              whitelabelHuntsOnly = true if tenant.whitelabelHuntsOnly? and tenant.whitelabelHuntsOnly is true
              return next null, null unless user and user?.parentId
              User.byId user.parentId, {}, (err, parent) ->
                return next err if err
                console.log "sendEmailPurchaseNotifications_PerCartEntry Error: Parent not found for id: #{user.parentId}" unless parent
                return next null, null unless parent
                return next null, parent

          #Email user receipt email
          (parent, next) ->
            if huntCatalog.type is "renewal_rep"
              template_name = "Specialist Renewal Receipt"
              subject = "Adventure Advisor Renewal"
            else if huntCatalog.type is "renewal_membership"
              template_name = "Membership Renewal Receipt"
              subject = "Rolling Bones Membership Renewal"
            else if huntCatalog.type is "renewal_oss"
              template_name = "OSS SaaS Purchase Renewal Receipt"
              subject = "OSS Renewal Receipt"
            else if huntCatalog.type is "oss"
              template_name = "OSS SaaS Purchase Receipt"
              subject = "OSS Purchase Receipt"
            else
              template_name = "Purchase Receipt"
              subject = "Purchase Notification"
            mandrilEmails = []
            if huntCatalog.type is "renewal_oss"
              to_user = {
                email: "scott@rollingbonesoutfitters.com"
                type: "cc"
              }
              mandrilEmails.push to_user
            else
              to_user = {
                email: user.email
                name: user.name
              }
              mandrilEmails.push to_user

            mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, merge_vars, null, null, false, false, (err, results) ->
              return next err, parent

          #Email notification to rep
          (parent, next) ->
            return next null, null if repDisabled
            return next null, null unless parent?.email
            return next null, null if huntCatalog.type is "renewal_oss"
            template_name = "Purchase Receipt Rep Copy"
            subject = "Purchase Notification (Rep)"
            mandrilEmails = []
            to_user = {
              email: parent.email
              name: parent.name
            }
            mandrilEmails.push to_user
            merge_vars["parent_name"] = parent.name

            mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, merge_vars, null, null, false, false, (err, results) ->
              return next err, results

          #Email notification to outfitter if it's a hunt
          (results, next) ->
            return next null, null unless huntCatalog?.type is "hunt"
            return next null, null unless outfitterEmail
            return next null, null if whitelabelHuntsOnly
            return next null, null if inStorePurchase
            template_name = "Purchase Hunt Notify Outfitter"
            subject = "Purchase Notification"
            mandrilEmails = []
            to_user = {
              email: outfitterEmail
              name: outfitter_name
            }
            mandrilEmails.push to_user

            mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, merge_vars, null, null, false, false, (err, results) ->
              return next err, results

          #Email notification to vendor if it's a product, oss, or rifle
          (results, next) ->
            return next null, null unless huntCatalog?.type is "product" or huntCatalog?.type is "oss" or huntCatalog?.type is "rifle" or huntCatalog?.type is "specialist"
            return next null, null if inStorePurchase
            if huntCatalog.type is "oss"
              template_name = "OSS SaaS Purchase"
              subject = "OSS Purchased"
            else if huntCatalog.type is "rifle"
              template_name = "Purchase Product"
              subject = "Rifle Purchased: #{huntCatalog.huntNumber}"
            else
              template_name = "Purchase Product"
              subject = "Purchase Notification: #{huntCatalog.huntNumber}"
            mandrilEmails = []
            tmp_type = "cc"
            tmp_type = "to" unless outfitterEmail
            if (tenant.clientPrefix is "RB" or tenant.clientPrefix is "RBD")
              mandrilEmails.push {
                email: "orders@rbohome.com"
                name: "RBO Orders"
                type: tmp_type
              }
            if outfitterEmail
              to_user = {
                email: outfitterEmail
                name: outfitter_name
              }
              mandrilEmails.push to_user

            mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, merge_vars, null, null, false, true, (err, results) ->
              return next err, results


          #Extra Email notifications
          (results, next) ->
            #Items to CC Lynley
            lynley = "lynley@rbohome.com"
            companies = [
              "leupold"
              "quik signs"
            ]
            sendExtraCopy = false

            if outfitter_name?.length and companies.indexOf(outfitter_name.trim().toLowerCase()) > -1
              sendExtraCopy = true
            else if huntCatalog?.type is "rifle"
              sendExtraCopy = true
            else if huntCatalog?.type is "course"
              sendExtraCopy = true
            else if huntCatalog?.type is "specialist"
              sendExtraCopy = true

            if sendExtraCopy
              template_name = "Purchase Product"
              subject = "#{outfitter_name} Purchase Notification: #{huntCatalog.huntNumber}"
              mandrilEmails = []
              to_user = {
                email: lynley
                type: "to"
              }
              mandrilEmails.push to_user
              mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, merge_vars, null, null, false, true, (err, results) ->
                return next err, results
            else
              return next null, null

        ], (err, results) ->
          if err
            console.log "Error: Failed to send all email notifications with hunt purchase: #{huntCatalog.title}, for user: #{user._id}, #{user.name}: Error: ",  err
          return cb null, null if cb?
          return #don't error, just continue with purchase workflow.


    upsert: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Type required'}, 400 unless req?.body?.type
      return res.json {error: 'Payment Plan required'}, 400 unless req?.body?.paymentPlan
      return res.json {error: 'Outfitter required'}, 400 unless req?.body?.outfitter_userId

      #Special case, assign tenantId if the user was a super admin (isAdmin=true, and no tenantId)
      if !(req?.body?.tenantId) and req?.user?.isAdmin and !req?.user?.tenantId
        req.body.tenantId = req.tenant._id

      return res.json {error: 'Tenant id required'}, 400 unless req?.body?.tenantId
      HuntCatalog.upsert req.body, (err, huntCatalog) ->
        return res.json err, 500 if err
        res.json huntCatalog


    mediaAdd: (req, res) ->
      try
        token = req.param('token')
        return res.json "Unauthorized", 500 unless token is APITOKEN
        console.log "mediaAdd req.files", req.files

        huntCatalogId = req.param('id')

        HuntCatalog.byId huntCatalogId, (err, huntCatalog) ->
          return res.json err, 500 if err
          return res.json {error: "huntCatalog doesn't exist for id: #{huntCatalogId}"}, 500 if err
          huntCatalog.media = [] unless huntCatalog.media?.length

          if req.files?.uploadedFiles?.length
            for file in req.files.uploadedFiles
              ext = ""
              extArray = file.path.split(".")
              ext = extArray[extArray.length-1] if extArray.length > 0
              huntCatalog.media.push {
                originalName: file.originalname
                extension: ".#{ext}"
                mimetype: file.mimetype
                url: file.path
                size: file.size
                encoding: file.encoding
              }

            HuntCatalog.upsert huntCatalog, (err, huntCatalog) ->
              return res.json err, 500 if err
              return res.json huntCatalog
          else
            return res.json {msg: "No files found to upload"}

      catch ex
        console.log "mediaAdd catch error:", ex
        return res.json {error: "An error occurred trying to update media for hunt catalog: #{huntCatalogId}"}, 500 if err


    mediaRemove: (req, res) ->
      try
        token = req.param('token')
        return res.json "Unauthorized", 500 unless token is APITOKEN

        huntCatalogId = req.param('id')
        newMediaList = []

        console.log "mediaRemove req.body.fileNames", req.body?.fileNames

        removeFilename = req.body.fileNames


        HuntCatalog.byId huntCatalogId, (err, huntCatalog) ->
          return res.json err, 500 if err
          return res.json {error: "huntCatalog doesn't exist for id: #{huntCatalogId}"}, 500 if err
          huntCatalog.media = [] unless huntCatalog.media?.length

          for media in huntCatalog.media
            newMediaList.push media unless media.originalName is removeFilename

          huntCatalog.media = newMediaList

          HuntCatalog.upsert huntCatalog, (err, huntCatalog) ->
            return res.json err, 500 if err
            return res.json huntCatalog

      catch ex
        console.log "mediaRemove catch error:", ex
        return res.json {error: "An error occurred trying to update media for hunt catalog: #{huntCatalogId}"}, 500 if err


    #Called from purchase_edit.coffee, save the purchase, then optionally recalculate the commissions and save them too.
    adminCommissions: (req, res) ->
      try
        return res.json {error: 'Unauthorized'}, 400 unless req.user?.isAdmin
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        tenantId = req.tenant._id.toString()
        purchaseData = req.body.purchaseData
        recalcCommissions = purchaseData?.recalcCommissions

        return res.json {error: 'Purchase Item _id required'}, 400 unless purchaseData?._id
        return res.json {error: 'Purchase Item userId required'}, 400 unless purchaseData?.userId
        return res.json {error: 'Purchase Item huntCatalog id required'}, 400 unless purchaseData?.huntCatalogId
        #return res.json {error: 'Purchase Item userParentId required'}, 400 unless purchaseData?.userParentId
        return res.json {error: 'Purchase Item outfitter_userId required'}, 400 unless purchaseData?.outfitter_userId

        tPurchaseData = {}
        #LIMIT what a non full admin can update.
#        if req.user.userType isnt "super_admin"
#          tPurchaseData._id = purchaseData._id
#          tPurchaseData.adminNotes = purchaseData.adminNotes if purchaseData.adminNotes
#          tPurchaseData.purchase_confirmed_by_client = purchaseData.purchase_confirmed_by_client if purchaseData.purchase_confirmed_by_client
#          tPurchaseData.purchase_confirmed_by_outfitter = purchaseData.purchase_confirmed_by_outfitter if purchaseData.purchase_confirmed_by_outfitter
#          tPurchaseData.confirmation_sent_outfitter = purchaseData.confirmation_sent_outfitter if purchaseData.confirmation_sent_outfitter
#          tPurchaseData.confirmation_sent_client = purchaseData.confirmation_sent_client if purchaseData.confirmation_sent_client
#          tPurchaseData.start_hunt_date = purchaseData.start_hunt_date if purchaseData.start_hunt_date
#          tPurchaseData.end_hunt_date = purchaseData.end_hunt_date if purchaseData.end_hunt_date
#          recalcCommissions = false
#        else
#          tPurchaseData = purchaseData
        tPurchaseData = purchaseData

        Purchase.upsert tPurchaseData, {upsert: false}, (err, purchase) =>
          return res.json {error: "An error occurred trying to save purchase from adminCommissions", err: err}, 500 if err
          if !recalcCommissions
            return res.json purchase
          else
            async.waterfall [
              # Retrieve the user info
              (next) ->
                return next "Missing userId" unless purchaseData.userId
                User.findById purchaseData.userId, internal: false, (err, user) ->
                  return next err if err
                  return next {error: "User not found"}, code: 500 unless user
                  return next null, user

              # Retrieve the Outfitter info
              (user, next) ->
                return next "Missing outfitter_userId" unless purchaseData.outfitter_userId
                User.findById purchaseData.outfitter_userId, internal: false, (err, outfitter) ->
                  return next err if err
                  return next {error: "Outfitter not found"}, code: 500 unless outfitter
                  return next null, user, outfitter

              # Calculate and Save Commissions
              (user, outfitter, next) =>
                @calculateCommissions user, outfitter, purchase, purchase.basePrice, (err, commResults) ->
                  console.log "Error processing commissions for this purchase: ", err if err
                  #Ignore the error and move on
                  return next null, purchase
            ], (err, purchase) ->
              return res.json {error: "An error occurred trying to adminCommissions", err: err}, 500 if err
              return res.json purchase

      catch ex
        console.log "admin_recalCommissions catch error:", ex
        return res.json {error: "An error occurred trying to recalculate commissions"}, 500 if err


    parseName: (name) ->
      names =
        prefix: ""
        first_name: ""
        middle_name: ""
        last_name: ""
        suffix: ""

      if !name
        return names

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

      else
        console.log "could not parse name!:", name
      names



    processUserUpdates: (purchase, cb) ->
      return cb("Invalid hunt catalog, missing id.") unless purchase.huntCatalogId
      return cb("Invalid hunt catalog, missing tenant.") unless purchase.tenantId
      return cb("Invalid hunt catalog, missing user.") unless purchase.userId
      results = {
        tenant: null
        huntCatalog: null
        user: null
        userDataToUpdate: {}
        updateUser: false
      }
      p_huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?

      async.waterfall [
        (next) ->
          Tenant.findById purchase.tenantId, (err, tenant) ->
            next "Missing clientPrefix from Tenant." unless tenant?.clientPrefix
            results.tenant = tenant
            next err, results

        (results, next) ->
          HuntCatalog.byId purchase.huntCatalogId, (err, huntCatalog) ->
            results.huntCatalog = huntCatalog
            next err, results

        (results, next) ->
          User.byId purchase.userId, (err, user) ->
            results.user = user
            next err, results

        (results, next) ->
          #Assign a user.clientId if the user doesn't already have one
          return next null, results if results?.user?.clientId
          Tenant.getNextClientId results.tenant._id, (err, newClientId) ->
            next err if err
            next {"New ClientId not found for tenant id: #{results.tenant._id}"} unless newClientId
            results.userDataToUpdate.clientId = results.tenant.clientPrefix + newClientId
            return next null, results

        (results, next) ->
          #Should we make the user a member?
          return next null, results unless results?.huntCatalog?.createMember
          results.newMemberCreated = true
          results.userDataToUpdate.memberId = results.user.clientId if results?.user?.clientId
          results.userDataToUpdate.memberId = results.userDataToUpdate.clientId if results?.userDataToUpdate?.clientId
          if p_huntCatalogCopy?.createMemberType
            results.userDataToUpdate.memberType = p_huntCatalogCopy.createMemberType
          else
            results.userDataToUpdate.memberType = "member"
          results.userDataToUpdate.isMember = true
          if purchase.isSubscription
            if purchase.status is 'auto-pay-monthly'
              results.userDataToUpdate.memberStatus = "auto-renew-monthly"
              results.userDataToUpdate.memberStarted = moment().format('YYYY-MM-DD') if !results?.user?.memberStarted?
              results.userDataToUpdate.memberExpires = moment().add(1, 'months').format('YYYY-MM-DD')
            else
              results.userDataToUpdate.memberStatus = "auto-renew-yearly"
              results.userDataToUpdate.memberStarted = moment().format('YYYY-MM-DD') if !results?.user?.memberStarted?
              results.userDataToUpdate.memberExpires = moment().add(1, 'years').format('YYYY-MM-DD')
            results.userDataToUpdate.membership_next_payment_amount = purchase.next_payment_amount if purchase.next_payment_amount
          else
            results.userDataToUpdate.memberStarted = moment().format('YYYY-MM-DD') if !results?.user?.memberStarted?
            results.userDataToUpdate.memberExpires = moment().add(1, 'years').format('YYYY-MM-DD') if !results?.user?.memberExpires?
          results.newMember = {
            memberId: results.userDataToUpdate.memberId
            memberType: results.userDataToUpdate.memberType
            memberStatus: results.userDataToUpdate.memberStatus
            memberExpires: results.userDataToUpdate.memberExpires
            isMember: results.userDataToUpdate.isMember
          }
          results.newMember.memberStarted = results.userDataToUpdate.memberStarted
          results.newMember.membership_next_payment_amount = results.userDataToUpdate.membership_next_payment_amount if results.userDataToUpdate.membership_next_payment_amount

          #If the membership auto renew was opt'd out, clear out the memberStatus and next payment fields
          if purchase.opt_out_subscription
            results.userDataToUpdate.memberStatus = null
            results.userDataToUpdate.membership_next_payment_amount = null

          results.updateUser = true
          return next null, results

        (results, next) ->
          #Should we make the user a rep?
          return next null, results unless results?.huntCatalog?.createRep
          results.newRepCreated = true
          if !results?.user?.repType?.length #If they are already a rep, skip this. They could AA or higher
            #results.userDataToUpdate.repType = "Associate Adventure Advisor"
            results.userDataToUpdate.repType = "Adventure Advisor"
          results.userDataToUpdate.isRep = true
          results.userDataToUpdate.repStatus = "auto-renew-monthly" if purchase.isSubscription
          results.userDataToUpdate.repStarted = moment().format('YYYY-MM-DD') if !results?.user?.repStarted?
          results.userDataToUpdate.repExpires = undefined #reset expired date to null
          results.userDataToUpdate.rep_next_payment = moment().add(1,'months').format('YYYY-MM-DD') #set next payment out one month
          results.userDataToUpdate.rep_next_payment_amount = purchase.next_payment_amount if purchase.next_payment_amount
          results.newRep = {
            memberType: results.userDataToUpdate.memberType
            repStatus: results.userDataToUpdate.repStatus
            repStarted: results.userDataToUpdate.repStarted
            isRep: results.userDataToUpdate.isRep
            rep_next_payment: results.userDataToUpdate.rep_next_payment
          }
          results.newRep.rep_next_payment_amount = results.userDataToUpdate.rep_next_payment_amount if results.userDataToUpdate.rep_next_payment_amount
          results.updateUser = true
          return next null, results

      ], (err, results) ->
        if err
          console.error "processUserUpdates on purchase failed with error: ", err
          return cb err
        if results?.updateUser
          results.userDataToUpdate._id = results.user._id
          console.log "processUserUpdates User.upsert() userData", results.userDataToUpdate
          User.upsert results.userDataToUpdate, {upsert: false}, (err, userRsp) ->
            return cb err if err
            userRsp.newMember = results.newMember if results.newMember
            userRsp.newRep = results.newRep if results.newRep
            return cb null, userRsp
        else
          return cb null, results

    addToRBOPurchase: (user, purchase, cb) ->
      if user.tenantId.toString() is OSSTenantId
        ossTenantId = OSSTenantId
        rboTenantId = RollingBonesTenantId
        defaultParentId = "5e1dfc1a01d227bd8e0c3ebd" #ClientId: RBOSS
      else if user.tenantId.toString() is OSSTestTenantId
        ossTenantId = OSSTestTenantId
        rboTenantId = RollingBonesTestTenantId
        defaultParentId = "5e1dfe2608e99f9bec256a00" #ClientId: RBOSS
      else
        return cb "purchase user tenant id is not the OSS Tenant: tenantId: #{user.tenantId}, userId: #{user._id}"

      findRBOParent = (referredBy, rboTenantId, cb) ->
        return cb null, null unless referredBy?.length
        User.byClientId referredBy.trim().toUpperCase(), rboTenantId, (err, userMatch) ->
          return cb err, userMatch

      OSS_COMMISSION_PERCENT = .138888888888889  # $250 on $1800 sale.  Outdoor Software Solutions Commissions
      OSS_SPECIALIST_BONUS = 0
      async.waterfall [
        #First create a RBO user for this OSS purchase
        (next) =>
          rbo_oss_client_id = "RB#{user.clientId}"
          User.byClientId rbo_oss_client_id, rboTenantId, (err, rboUser) =>
            return next err if err
            return next err, rboUser if rboUser #Found the user already
            #Create a user in RBO for this OSS tenant purchase
            User.findByEmail user.email, rboTenantId, {}, (err, alreadyExistsUser) =>
              return next err if err
              return next err, alreadyExistsUser if alreadyExistsUser
              #return next "Could not create RBO user, email already exists for: #{user.email}" if alreadyExistsUser
              newUserData = {
                clientId: rbo_oss_client_id
                tenantId: rboTenantId
                type: 'local'
                active: true
                email: user.email
                password: user.password
                first_name: user.first_name
                last_name: user.last_name
                name: user.name
                parentId: defaultParentId
              }
              findRBOParent user.referredBy, rboTenantId, (err, parent) =>
                return next err if err
                newUserData.parentId = parent._id if parent
                User.upsert newUserData, {internal: false, upsert: true}, (err, rboUser) ->
                  return next "Failed to create a new user!" unless rboUser
                  return next err, rboUser

        #Now create a hunt catalog entry for this OSS Purchase (just include total commissions as the RBO commissions)
        (rboUser, next) ->
          return next "Error: missing hunt catalog copy on purchase" unless purchase.huntCatalogCopy?.length
          huntCatalogData = _.clone(purchase.huntCatalogCopy[0])
          delete huntCatalogData._id
          delete huntCatalogData.__v
          huntCatalogData.tenantId = rboTenantId
          huntCatalogData.outfitter_userId = defaultParentId
          huntCatalogData.outfitter_name = "Outdoor Software Solutions"
          huntCatalogData.type = "oss"
          huntCatalogData.rbo_reps_commission = ((purchase.basePrice * OSS_COMMISSION_PERCENT) + OSS_SPECIALIST_BONUS).toFixed(0)
          huntCatalogData.rbo_commission = huntCatalogData.rbo_reps_commission
          HuntCatalog.upsert huntCatalogData, (err, huntCatalogItem) ->
            return next err, rboUser, huntCatalogItem

        #Now create a purchase entry for this OSS Purchase
        (rboUser, huntCatalogItem, next) ->
          newPurchaseData = _.clone(purchase)
          newPurchaseData.huntCatalogCopy = []
          newPurchaseData.huntCatalogCopy.push huntCatalogItem
          delete newPurchaseData._id
          delete newPurchaseData.__v
          delete newPurchaseData.userSnapShot
          delete newPurchaseData.user_payment_customerProfileId
          delete newPurchaseData.user_payment_paymentProfileId
          newPurchaseData.tenantId = rboTenantId
          newPurchaseData.userId = rboUser._id
          newPurchaseData.userParentId = rboUser.parentId
          newPurchaseData.options = []
          for option in purchase.options
            newPurchaseData.options.push option
          newPurchaseData.orderNumber = "RBI#{purchase.orderNumber}"
          newPurchaseData.invoiceNumber = "RBI#{purchase.invoiceNumber}"
          newPurchaseData.commissionPercent = (OSS_COMMISSION_PERCENT*100).toFixed(2)
          newPurchaseData.rbo_reps_commission = ((purchase.basePrice * OSS_COMMISSION_PERCENT) + OSS_SPECIALIST_BONUS).toFixed(0)
          newPurchaseData.commission = newPurchaseData.rbo_reps_commission #RBO Commission
          newPurchaseData.rbo_margin = newPurchaseData.commission - newPurchaseData.rbo_reps_commission
          newPurchaseData.rbo_reps_bonus_type = "oss"
          newPurchaseData.rbo_reps_bonus = OSS_SPECIALIST_BONUS
          Purchase.upsert newPurchaseData, {}, (err, newPurchaseItem) ->
            return next err, rboUser, newPurchaseItem

        # Calculate and Save Commissions
        (rboUser, newPurchaseItem, next) =>
          outfitter = {
            commission: 0
          }
          @calculateCommissions rboUser, outfitter, newPurchaseItem, newPurchaseItem.basePrice, (err, commResults) ->
            console.log "Error processing commissions for this OSS purchase: ", err if err
            return next err, newPurchaseItem

      ], (err, newPurchaseItem) ->
          if err
            console.error "addToRBOPurchase failed with error: ", err
            return cb err
          else
            return cb null, newPurchaseItem

    createServiceRequest: (user, reqTenantId, purchase, cb) ->
      huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?.length
      requestData = {}
      requestData.tenantId = reqTenantId
      requestData.external_id = purchase._id
      requestData.memberId = user.memberId
      requestData.userId = user._id
      requestData.clientId = user.clientId
      requestData.type = "Purchase"
      requestData.source = "Internal"
      requestData.first_name = user.first_name
      requestData.last_name = user.last_name
      requestData.address = user.mail_address
      requestData.city = user.mail_city
      requestData.country = user.mail_country
      requestData.postal = user.mail_postal
      requestData.state = user.mail_state
      requestData.email = user.email
      requestData.phone = user.phone_cell
      requestData.phone = user.phone_home unless user.phone_cell
      requestData.species = huntCatalogCopy.species
      requestData.location = huntCatalogCopy.state
      requestData.weapon = huntCatalogCopy.weapon
      requestData.budget = purchase.amount
      requestData.external_date_created = new Date()
      requestData.message = "Hunt Catalog Purchase: #{huntCatalogCopy.huntNumber}, #{huntCatalogCopy.title}"
      requestData.purchase = {
        purchaseId: purchase._id
        huntCatalogId: huntCatalogCopy._id
        huntCatalogNumber: huntCatalogCopy.huntNumber
        huntCatalogTitle: huntCatalogCopy.title
        huntCatalogType: huntCatalogCopy.type
        purchaseNotes: purchase.purchaseNotes
        paymentMethod: purchase.paymentMethod
      }
      if purchase.paymentMethod is "cc"
        requestData.purchase_hunt = {
          depositReceived: new Date()
        }

      ServiceRequest.upsert requestData, (err, serviceRequest) ->
        return cb err if err
        #console.log "successfully imported serviceRequest: ", serviceRequest
        return cb null, serviceRequest


    calculateCommissions: (user, outfitter, purchase, price, cb) ->
      try
        purchaseData = {
          _id: purchase._id
        }
        huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy
        #Default commissions to rbo and $ to reps to zero.
        purchaseData.commission = 0
        purchaseData.commissionPercent = 0
        purchaseData.rbo_reps_commission = 0

        if purchase.commission?
          purchaseData.commission = purchase.commission
        else if huntCatalogCopy?.rbo_commission or huntCatalogCopy?.rbo_commission is 0
          purchaseData.commission = huntCatalogCopy.rbo_commission #Actual RBO comm in $ specified in hunt catalog

        #Backward compatible from old GMT when commissions were based on percentage not explicitly set
        if price? and price > 0
          purchaseData.commissionPercent = (100 * (purchaseData.commission / price)).toFixed(2) #calculate commission to rbo % of the full purchase amount

        if purchase.rbo_reps_commission?
          purchaseData.rbo_reps_commission = purchase.rbo_reps_commission
        else if huntCatalogCopy?.rbo_reps_commission or huntCatalogCopy?.rbo_reps_commission is 0
          purchaseData.rbo_reps_commission = huntCatalogCopy.rbo_reps_commission #Actual total rep comm in $ specified in hunt catalog

        if purchase.fee_processing?
          purchaseData.fee_processing = purchase.fee_processing
        else if huntCatalogCopy?.fee_processing
          purchaseData.fee_processing = huntCatalogCopy.fee_processing

      catch err
        console.log "ERROR: calculateCommissions error: ", err
        return cb null, "let commissions run and save async"

      if !purchaseData.commission?
          console.log "ERROR, SKIPPING COMMISSIONS CALCULATION missing rbo_commission on the hunt catalog item: ", purchaseData
          return cb null, "let commissions run and save async"

      async.waterfall [
        (next) ->
          #The old code was always updating the purchase with the calculated commission, commissionPercent, or rbo_reps_commission above
          #Note sure why, maybe cases were the purchase in the db didn't already have these set.  Updating to optionally do it.
          need_to_update_purchase = false
          need_to_update_purchase = true if purchaseData.commission != purchase.commission
          need_to_update_purchase = true if purchaseData.commissionPercent != purchase.commissionPercent
          need_to_update_purchase = true if purchaseData.rbo_reps_commission != purchase.rbo_reps_commission
          need_to_update_purchase = true if purchaseData.fee_processing != purchase.fee_processing
          if need_to_update_purchase
            console.log "Alert: Purchase.upsert with data: ", purchaseData
            Purchase.upsert purchaseData, {upsert: false}, (err, purchase) =>
              console.log "calculateCommissions save Purchase error: ", err if err
              return next err, purchase
          else
            return next null, purchase

        (purchase, next) =>
          #check if this is a payment for an original purchase
          original_purchase = null
          return next null, purchase, original_purchase unless purchase.applyTo_purchaseId
          Purchase.byId purchase.applyTo_purchaseId, purchase.tenantId, (err, original_purchase) ->
            return next err, purchase, original_purchase

        (purchase, original_purchase, next) =>
          if purchase.tenantId?.toString() is "5684a2fc68e9aa863e7bf182" or purchase.tenantId?.toString() is "5bd75eec2ee0370c43bc3ec7" #if RBO or Test RBO Tenants Only
            User.findById user.parentId, {internal: false}, (err, parent) =>
              if parent?.repType is "Outdoor Software Solutions Partner"
                isOSSPDirectSale = true
              else
                isOSSPDirectSale = false
              safteyCheck = 1 #just to make sure don't have infinite recursion by accident
              @calculateCommissions_RBO("R0", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R1", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R2", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R3", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R4", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R5", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R6", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("R7", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              @calculateCommissions_RBO("RBO", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)  #RBO Overrides BBN
              @calculateCommissions_RBO("RBO_MARGIN", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale) if !purchaseData.rbo_margin  #Commission from outfitter - reps - overrides
              @calculateCommissions_RBO("OSSP", user, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)
              return next null, "let commissions run and save async"
          else
            return next null, "not RBO base tenant. Skip calculating split rep commissions"

      ], (err, results) ->
        console.log "ERROR: calculateCommissions error2: ", err if err
        return cb null, "let commissions run and save async"


    calculateCommissions_RBO: (commType, user, outfitter, purchase, original_purchase, safteyCheck, isOSSPDirectSale) ->
      if safteyCheck and safteyCheck > 500 #just to make sure don't have infinite recursion by accident
        return

      savePurchase = (purchaseData) ->
        Purchase.upsert purchaseData, {upsert: false}, (err, purchase) ->
          console.log "calculateCommissions_RBO save Purchase error: ", err if err
          #console.log "calculateCommissions_RBO Successful saved Purchase."

      calcCommission = (commType, purchase, huntCatalogType) ->
        validCommTypes = ["R0","R1","R2","R3","R4","R5","R6","R7","OSSP","Override1","Override2","Override3","rbo","RBO_MARGIN"]
        if validCommTypes.indexOf(commType) < 0
          console.log "Error calculateCommissions_RBO calcCommission invalid commType encountered: ", commType
          return 0

        amount = 0
        if purchase.rbo_reps_commission  #Override of commission-able amount to go to reps
          rbo_reps_commission = purchase.rbo_reps_commission
        else
          rbo_reps_commission = 0

        #if purchase.rbo_reps_bonus has a value, then take it out of the overall rep commission amount to later apply
        if purchase.rbo_reps_bonus > 0
          rbo_reps_commission = rbo_reps_commission - purchase.rbo_reps_bonus

        #Take 2% for RBO MAIN for everything but subscriptions.  8/29 Scott: Took 2% RBO slice of commissions out.
        if huntCatalogType is "membership" or huntCatalogType is "group_membership"
          RBO_MAIN = 0
        else
          #RBO_MAIN = (rbo_reps_commission * (2 / 100)).toFixed(2)   8/29 Scott: Took 2% RBO slice of commissions out.
          RBO_MAIN = 0
          rbo_reps_commission = rbo_reps_commission - RBO_MAIN

        #General rule:  Of the commissions left to Reps, split as follows:
        # R0 35%, R1 35%, R2 5%, R3 5%, R4 5%, R5 5%, R6 5%, R7 5%, (OSSP 65%, which is not part of the comp levels, just it's own contract.  They do not get overrides)
        #2/22/2022 R0 0%, R1 50%, R2 10%, R3 10%, R4 5%, R5 5%, R6 5%, R7 5%, (OSSP 65%, which is not part of the comp levels, just it's own contract.  They do not get overrides)
        r0 = (rbo_reps_commission * (0 / 100)).toFixed(2) #AAA      Ambassader:  get 10%
        r1 = (rbo_reps_commission * (50 / 100)).toFixed(2)  #AA
        r2 = (rbo_reps_commission * (10 / 100)).toFixed(2)  #SAA
        r3 = (rbo_reps_commission * (10 / 100)).toFixed(2) #RAA
        r4 = (rbo_reps_commission * (15 / 100)).toFixed(2) #AM
        r5 = (rbo_reps_commission * (5 / 100)).toFixed(2) #SAM
        r6 = (rbo_reps_commission * (5 / 100)).toFixed(2) #EAM
        r7 = (rbo_reps_commission * (5 / 100)).toFixed(2) #SEAM

        if isOSSPDirectSale
          ossp = (rbo_reps_commission * (65 / 100)).toFixed(2) #OSSP
          r0 = (rbo_reps_commission * (0 / 100)).toFixed(2) #AAA, no overrides for OSSP's
          r1 = (rbo_reps_commission * (5 / 100)).toFixed(2)  #AA  AA over the OSSP gets 5% override
        else
          ossp = (rbo_reps_commission * (0 / 100)).toFixed(2) #OSSP level is not applicable

        #General rule:  Of the amount the outfitter is giving RBO, keep 2% for overrides, unless we make less than 10%, then keep 1%.
        if !purchase.commission or !purchase.basePrice
          overrides = 0
        else if ( (purchase.commission - rbo_reps_commission) <= 0)
          overrides = 0
        else if ( (purchase.commission / purchase.basePrice) >= .15)
          overrides = (purchase.basePrice * (2 / 100)).toFixed(2) #2% of the full price
        else if ( (purchase.commission / purchase.basePrice) >= .10)
          overrides = (purchase.basePrice * (1 / 100)).toFixed(2) #1% of the full price
        else if ( (purchase.commission / purchase.basePrice) >= .5)
          overrides = (purchase.basePrice * (.5 / 100)).toFixed(2) #.5% of the full price
        else
          overrides = 0
        if huntCatalogType is "product" and overrides > 0
          overrides = (purchase.basePrice * (1 / 100)).toFixed(2) #1% of the full price

        if purchase.rbo_reps_bonus_type is "oss"
          overrides = 0

        if huntCatalogType is "oss" or huntCatalogType is "renewal_oss"
          overrides = 0

        override1 = (overrides * (62 / 100)).toFixed(2) #Brian
        override2 = (overrides * (33 / 100)).toFixed(2) #Brad
        override3 = (overrides * (5 / 100)).toFixed(2)  #Noel

        #RBO Margin = Comm to RBO - Reps Amount - Overrides
        rbo_margin = (purchase.commission - r0 - r1 - r2 - r3 - r4 - r5 - r6 - r7 - ossp - RBO_MAIN - override1 - override2 - override3).toFixed(2)

        switch huntCatalogType
          when "specialist"
            switch commType
              when "R0" then amount = 0
              when "R1" then amount = 0
              when "R2" then amount = 0
              when "R3" then amount = 0
              when "R4" then amount = 0
              when "R5" then amount = 0
              when "R6" then amount = 0
              when "R7" then amount = 0
              when "OSSP" then amount = 0
              when "rbo" then amount = 0
              when "Override1" then amount = 0
              when "Override2" then amount = 0
              when "Override3" then amount = 0
              when "RBO_MARGIN" then amount = (purchase.commission).toFixed(2)
              else amount = 0
          when "rep"
            switch commType
              when "R0" then amount = 0
              when "R1" then amount = 0
              when "R2" then amount = 0
              when "R3" then amount = 0
              when "R4" then amount = 0
              when "R5" then amount = 0
              when "R6" then amount = 0
              when "R7" then amount = 0
              when "OSSP" then amount = 0
              when "rbo" then amount = 0
              when "Override1" then amount = 0
              when "Override2" then amount = 0
              when "Override3" then amount = 0
              when "RBO_MARGIN" then amount = (purchase.commission).toFixed(2)
              else amount = 0
          when "renewal_rep"
            switch commType
              when "R0" then amount = 0
              when "R1" then amount = 0
              when "R2" then amount = 0
              when "R3" then amount = 0
              when "R4" then amount = 0
              when "R5" then amount = 0
              when "R6" then amount = 0
              when "R7" then amount = 0
              when "OSSP" then amount = 0
              when "rbo" then amount = 0
              when "Override1" then amount = 0
              when "Override2" then amount = 0
              when "Override3" then amount = 0
              when "RBO_MARGIN" then amount = (purchase.commission).toFixed(2)
              else amount = 0
          when "renewal_membership"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "renewal_membership_silver"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "renewal_membership_platinum"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "group_membership"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "membership"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "rifle"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "hunt"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "product"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "course"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "advertising"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "oss"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          when "renewal_oss"
            switch commType
              when "R0" then amount = r0
              when "R1" then amount = r1
              when "R2" then amount = r2
              when "R3" then amount = r3
              when "R4" then amount = r4
              when "R5" then amount = r5
              when "R6" then amount = r6
              when "R7" then amount = r7
              when "OSSP" then amount = ossp
              when "rbo" then amount = RBO_MAIN
              when "Override1" then amount = override1
              when "Override2" then amount = override2
              when "Override3" then amount = override3
              when "RBO_MARGIN" then amount = rbo_margin
              else amount = 0
          else
            console.log "Error calculateCommissions_RBO calcCommission invalid huntCatalogType encountered: ", huntCatalogType
            amount = 0

        #check if a bonus should be applied from the bonus amount pulled out of the rep comm amount
        applyBonus = () ->
          if user.isOSSCertified and purchase.rbo_reps_bonus_type is "oss"
            return false #TODO: This won't work because it would apply to every rep in the chain if they are oss certified.
            #TODO: Do we want to auto assign the bonus?  or make a place just on the purchase_edit page (replace RBO4 house acct with BONUS and repid and amount)???
          else
            return false
        if purchase.rbo_reps_bonus > 0 and applyBonus()
          amount = amount + purchase.rbo_reps_bonus
        return amount

      checkCommission = (huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase) =>
        purchaseData = {
          _id: purchase._id
        }
        repTypeMatchArray = repTypeMatch.split(",")
        for rType in repTypeMatchArray
          rType = rType.trim()

        receiveCommissionOnPersonalSales = true
        #Now check to see if this user shouldn't yet qualify for receiving commissions on their own purchases yet
        if huntCatalogType is "oss" or huntCatalogType is "renewal_oss"
          purchase_date = moment(purchase.createdAt)
          purchase_date = moment(original_purchase.createdAt) if original_purchase?.createdAt
          user_rep_started = moment(user.repStarted)
          if purchase.userId.toString() is user._id.toString() and user.isRep and user_rep_started
            qualify_date = purchase_date.subtract(12,'months')
            #console.log "Alert: #{commType}, rep user: #{user.name}, user_rep_started: #{user_rep_started.format('MM/DD/YYYY')}, qualify_date: #{qualify_date.format('MM/DD/YYYY')}, user_rep_started.isAfter(qualify_date): #{user_rep_started.isAfter(qualify_date)}"
            if user_rep_started.isAfter(qualify_date)
              receiveCommissionOnPersonalSales = false
        #Special override needed: receiveCommissionOnPersonalSales, Always allow Brian Mehmen as root user to resolve commissions
        if purchase.userId.toString() is "570419ee2ef94ac9688392b0"
          receiveCommissionOnPersonalSales = true

        if repTypeMatch is "RBO"
          #console.log "checkCommission found match: ", repTypeMatch, user.name, user._id
          amount = calcCommission(commType, purchase, huntCatalogType)
          if commType is "Override1"
            purchaseData[repField] = "570419ee2ef94ac9688392b0" #Brian
          else if commType is "Override2"
            purchaseData[repField] = "570419ab2ef94ac9688392af" #Brad
          else if commType is "Override3"
            purchaseData[repField] = "5684b5e5769bca1267868a07" #Noel
          else if commType is "rbo"
            purchaseData[repField] = "5b3ecb1cfdf2b81949debe04"
          purchaseData[commField] = amount
          savePurchase(purchaseData)
          return
        else if repTypeMatch is "RBO_MARGIN"
          #console.log "checkCommission found match: ", repTypeMatch, user.name, user._id
          amount = calcCommission(commType, purchase, huntCatalogType)
          purchaseData[commField] = amount
          savePurchase(purchaseData)
        else if user.isRep and repTypeMatchArray.indexOf(user.repType) > -1 and receiveCommissionOnPersonalSales
          #console.log "checkCommission found match: user.repType: #{user.repType}, #{user.name}, #{user._id}, repTypeMatch: #{repTypeMatch}"
          amount = calcCommission(commType, purchase, huntCatalogType)
          purchaseData[repField] = user._id
          purchaseData[commField] = amount
          savePurchase(purchaseData)
          return
        else if user.isRep and repTypeMatchArray.indexOf(user.repType) > -1 and !receiveCommissionOnPersonalSales and user._id.toString() != purchase.userId.toString()
          #console.log "checkCommission found match: user.repType: #{user.repType}, #{user.name}, #{user._id}, repTypeMatch: #{repTypeMatch}"
          amount = calcCommission(commType, purchase, huntCatalogType)
          purchaseData[repField] = user._id
          purchaseData[commField] = amount
          savePurchase(purchaseData)
          return
        else
          #Go up the parent chain and try again
          if !user.parentId or user.parentId?.toString() is user._id?.toString()
            console.log "calculateCommissions_RBO: reached end of parent chain without finding #{commType}"
            return
          User.findById user.parentId, {internal: false}, (err, parent) =>
            console.log "Error calculateCommissions_RBO, error finding user parent for userId: ", user._id if err
            console.log "Error calculateCommissions_RBO, parent not found for userId: ", user._id unless parent
            return unless parent
            #console.log "call-recurring calculateCommissions_RBO:", commType
            @calculateCommissions_RBO(commType, parent, outfitter, purchase, original_purchase, ++safteyCheck, isOSSPDirectSale)


      try
        huntCatalogType = purchase.huntCatalogCopy[0].type if purchase.huntCatalogCopy?.length
        switch commType
          when "R0"
            repTypeMatch = "Associate Adventure Advisor,Adventure Advisor,Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep0"
            commField = "rbo_commission_rep0"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R1"
            repTypeMatch = "Adventure Advisor,Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep1"
            commField = "rbo_commission_rep1"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R2"
            repTypeMatch = "Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep2"
            commField = "rbo_commission_rep2"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R3"
            repTypeMatch = "Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep3"
            commField = "rbo_commission_rep3"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R4"
            repTypeMatch = "Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep4"
            commField = "rbo_commission_rep4"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R5"
            repTypeMatch = "Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep5"
            commField = "rbo_commission_rep5"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R6"
            repTypeMatch = "Executive Agency Manager,Senior Executive Agency Manager"
            repField = "rbo_rep6"
            commField = "rbo_commission_rep6"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "R7"
            repTypeMatch = "Senior Executive Agency Manager"
            repField = "rbo_rep7"
            commField = "rbo_commission_rep7"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "OSSP"
            repTypeMatch = "Outdoor Software Solutions Partner"
            repField = "rbo_repOSSP"
            commField = "rbo_commission_repOSSP"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)
          when "RBO" #Rolling Bones overrides
            repTypeMatch = "RBO"
            checkCommission(huntCatalogType, "Override1", repTypeMatch, "rbo_rbo1", "rbo_commission_rbo1", user, outfitter, purchase, original_purchase)
            checkCommission(huntCatalogType, "Override2", repTypeMatch, "rbo_rbo2", "rbo_commission_rbo2", user, outfitter, purchase, original_purchase)
            checkCommission(huntCatalogType, "Override3", repTypeMatch, "rbo_rbo3", "rbo_commission_rbo3", user, outfitter, purchase, original_purchase)
            checkCommission(huntCatalogType, "rbo", repTypeMatch, "rbo_rbo4", "rbo_commission_rbo4", user, outfitter, purchase, original_purchase)
          when "RBO_MARGIN"
            repTypeMatch = "RBO_MARGIN"
            repField = "rbo_margin"
            commField = "rbo_margin"
            checkCommission(huntCatalogType, commType, repTypeMatch, repField, commField, user, outfitter, purchase, original_purchase)

          else
            console.log "Error calculateCommissions_RBO invalid type encountered: ", type
      catch err
        console.log "calculateCommissions_RBO error: ", err

      return


    purchase3: (user, cart, cb) ->
      if cart.inStorePurchase
        tenantId = cart.current_sub_tenant_nrads_id
      else
        tenantId = user.tenantId

      purchaseResponse = null

      processCartEntry = (cart_entry, done) =>
        async.waterfall [
          #Determine if this is a subscription request
          (next) ->
            if cart_entry.purchaseItem.auto_renew is true
              isSubscription = true
            else
              isSubscription = false
            return next null, isSubscription

          # Retrieve the Outfitter info
          (isSubscription, next) ->
            return next null, isSubscription, null unless cart_entry.huntCatalog.outfitter_userId
            User.findById cart_entry.huntCatalog.outfitter_userId, internal: false, (err, outfitter) ->
              return next err, isSubscription, outfitter

          # Save the Purchase
          (isSubscription, outfitter, next) ->
            purchaseData = cart_entry.purchaseItem
            purchaseData.orderNumber = cart.orderNumber
            purchaseData.tenantId = tenantId
            purchaseData.userId = user._id
            purchaseData.userParentId = user.parentId
            purchaseData.price_non_commissionable = cart_entry.huntCatalog.price_non_commissionable if cart_entry.huntCatalog.price_non_commissionable
            purchaseData.huntCatalogId = cart_entry.huntCatalog._id
            purchaseData.huntCatalogCopy = [_.omit(cart_entry.huntCatalog,['__v', 'media'])]
            purchaseData.amount = cart_entry.purchaseItem.todays_payment
            purchaseData.amountPaid = cart_entry.purchaseItem.todays_payment
            purchaseData.start_hunt_date = cart_entry.purchaseItem.start_hunt_date
            purchaseData.user_payment_customerProfileId = user.payment_customerProfileId
            purchaseData.user_payment_paymentProfileId = user.user_payment_paymentProfileId
            purchaseData.isSubscription = isSubscription
            purchaseData.cc_subscriptionId = purchaseResponse.subscriptionId if purchaseResponse.subscriptionId
            purchaseData.cc_transId = purchaseResponse.cc_transId if purchaseResponse.cc_transId
            purchaseData.cc_responseCode = purchaseResponse.cc_responseCode if purchaseResponse.cc_responseCode
            purchaseData.cc_messageCode = purchaseResponse.cc_messageCode if purchaseResponse.cc_messageCode
            purchaseData.cc_description = purchaseResponse.cc_description if purchaseResponse.cc_description
            purchaseData.cc_accountNum = purchaseResponse.cc_accountNum if purchaseResponse.cc_accountNum
            if isSubscription and cart_entry.purchaseItem.auto_renew
              #TODO: HAVE TO SET THESE IF IT"S A SUBSCRIPTION
              purchaseData.next_payment_amount = cart_entry.purchaseItem.todays_payment
              now = moment()
              now_date = now.date()
              now_month = now.month()+1
              now_year = now.year()
              if purchaseData.status is 'auto-pay-monthly'
                now_month = now_month + 1
                now_month = 1 if now_month is 13
                purchaseData.next_payment_date = "#{now_year}-#{now_month}-#{now_date}"
              else if purchaseData.status is 'auto-pay-yearly'
                now_year = now_year + 1
                purchaseData.next_payment_date = "#{now_year}-#{now_month}-#{now_date}"

            #basePrice will be handed to us and was the member price, non price, or deal price whichever was correct on the purchase
            Purchase.upsert purchaseData, {}, (err, purchase) ->
              return next err, outfitter, purchase

          # Calculate and Save Commissions
          (outfitter, purchase, next) =>
            @calculateCommissions user, outfitter, purchase, purchase.basePrice, (err, commResults) ->
              console.log "Error processing commissions for this purchase: ", err if err
              #Ignore the error and move on
              return next null, user, outfitter, purchase

          # Send Purchase email notifications
          (user, outfitter, purchase, next) =>
            if cart.do_not_send_email
              return next null, user, outfitter, purchase
            huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?
            emailParams = null
            emailParams = cart.emailParams if cart.emailParams?
            emailParams.inStorePurchase = cart.inStorePurchase if cart.inStorePurchase
            if cart.send_email_sync or huntCatalogCopy.title?.toLowerCase().indexOf("renewal") > -1 or purchase.status?.toLowerCase().indexOf("auto") > -1
              #todo: the conditons after the original cart.send_email_sync can be removed.  They are only there for backaward compatibility until the membership renewal script is updated to pass send_email_sync
              @sendEmailPurchaseNotifications_PerCartEntry user, outfitter, huntCatalogCopy, purchase._id, purchase.tenantId, emailParams, (err, result) ->
                #renewals run from a cronned process script, and must wait sync for email to send.
                #Note always ignore the email errors as the purchase needs to continue.
                return next null, user, outfitter, purchase
            else
              #Don't wait for emails to send. Move on.
              #Note always ignore the email errors as the purchase needs to continue.
              @sendEmailPurchaseNotifications_PerCartEntry user, outfitter, huntCatalogCopy, purchase._id, purchase.tenantId, emailParams
              return next null, user, outfitter, purchase

          # Create a Service Request
          (user, outfitter, purchase, next) =>
            huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?
            return next null, user, outfitter, purchase if huntCatalogCopy?.type is "hunt"
            #Skip hunts, create service requests "purchase" items for the rest
            @createServiceRequest user, tenantId, purchase, (err, serviceRequest) ->
              console.log "Error creating service request for this purchase: ", err if err
              #Ignore the error and let the purchase finish successfully.
              return next null, user, outfitter, purchase

          # Process User Updates
          (user, outfitter, purchase, next) =>
            @processUserUpdates purchase, (err, userUpdateRsp) ->
              console.log "Error processing user updates for this purchase: ", err if err
              #Ignore the error and let the purchase finish successfully.
              return next null, user, outfitter, purchase, userUpdateRsp

          # Special check if OSS purchase and need to give RBO commissions for it
          (user, outfitter, purchase, userUpdateRsp, next) =>
            return next null, user, outfitter, purchase, userUpdateRsp
            #no long needed.  OSS sales are disabled for now.
            # return next null, user, outfitter, purchase, userUpdateRsp unless purchase.tenantId.toString() is OSSTenantId or purchase.tenantId.toString() is OSSTestTenantId
            @addToRBOPurchase user, purchase, (err, addToRBOPurchaseRsp) ->
              console.log "Error adding RBO copy of this purchase for commissions: ", err if err
              #Ignore the error and let the purchase finish successfully.
              return next null, user, outfitter, purchase, userUpdateRsp

        ], (err, user, outfitter, purchase, userUpdateRsp) ->
          results = {}
          results.purchaseId = purchase._id if purchase
          results.newMember = userUpdateRsp.newMember if userUpdateRsp?.newMember
          results.newRep = userUpdateRsp.newRep if userUpdateRsp?.newRep
          results.purchaseResponse = purchaseResponse
          return done err, results

      #Get Order Number (shared with all purchases)
      Tenant.getNextInvoiceNumber tenantId, (err, orderNumber) =>
        return cb err if err
        cart.orderNumber = orderNumber

        #Now get individual invoiceNumbers for each line item for tracking POS and Quickbooks
        assignInvoiceNumbers = (cart_entry, done) ->
          Tenant.getNextInvoiceNumber tenantId, (err, invoiceNumber) ->
            return done err if err
            cart_entry.purchaseItem.invoiceNumber = invoiceNumber
            return done null, cart_entry

        async.mapSeries cart.cart_entries, assignInvoiceNumbers, (err, results) ->
          return cb err if err
          cart.orderNumber = cart.cart_entries[0].purchaseItem.invoiceNumber #Lynley request make cart order # be the same as the invoice # as the first item in the cart.
          cart.cart_entries = results

          #Now make the authorized purchase
          authorizenetapi.purchaseOneTimeCart user, cart.payment_method, cart, (err, tPurchaseResponse) =>
            console.log "Alert: returning from purchaseOneTimeCart with err: ", err if err
            return cb err if err
            purchaseResponse = tPurchaseResponse
            console.log "Authorize.net Response (from potc): err, purchaseResponse: ", err, purchaseResponse
            #Now save each item in the cart to NRADS
            async.mapSeries cart.cart_entries, processCartEntry, (err, results) ->
              console.log err if err
              return cb err, results

    #Copy of purchase3(), modified to not call authorize.net but to assume the cart items are already successfully purchased via Nexio in RRADS
    #Note: this method is 90% the same code as purchase3() but out of an abundance of caution, don't modify the original method for backward compatibility
    record_rrads_purchase: (user, cart, purchaseResponse, cb) ->
      if cart.inStorePurchase
        tenantId = cart.current_sub_tenant_nrads_id
      else
        tenantId = user.tenantId

      processCartEntry = (cart_entry, done) =>
        async.waterfall [
          #Determine if this is a subscription request
          (next) ->
            if cart_entry.purchaseItem.auto_renew is true
              isSubscription = true
            else
              isSubscription = false
            return next null, isSubscription

          # Retrieve the Outfitter info
          (isSubscription, next) ->
            return next null, isSubscription, null unless cart_entry.huntCatalog.outfitter_userId
            User.findById cart_entry.huntCatalog.outfitter_userId, internal: false, (err, outfitter) ->
              return next err, isSubscription, outfitter

          # Save the Purchase
          (isSubscription, outfitter, next) ->
            purchaseData = cart_entry.purchaseItem
            purchaseData.orderNumber = cart.orderNumber
            purchaseData.tenantId = tenantId
            purchaseData.userId = user._id
            purchaseData.userParentId = user.parentId
            purchaseData.price_non_commissionable = cart_entry.huntCatalog.price_non_commissionable if cart_entry.huntCatalog.price_non_commissionable
            purchaseData.huntCatalogId = cart_entry.huntCatalog._id
            purchaseData.huntCatalogCopy = [_.omit(cart_entry.huntCatalog,['__v', 'media'])]
            purchaseData.amount = cart_entry.purchaseItem.todays_payment
            purchaseData.amountPaid = cart_entry.purchaseItem.todays_payment
            purchaseData.start_hunt_date = cart_entry.purchaseItem.start_hunt_date
            purchaseData.user_payment_customerProfileId = user.payment_customerProfileId
            purchaseData.user_payment_paymentProfileId = user.user_payment_paymentProfileId
            purchaseData.isSubscription = isSubscription
            purchaseData.cc_subscriptionId = purchaseResponse.subscriptionId if purchaseResponse.subscriptionId
            purchaseData.cc_transId = purchaseResponse.cc_transId if purchaseResponse.cc_transId
            purchaseData.cc_responseCode = purchaseResponse.cc_responseCode if purchaseResponse.cc_responseCode
            purchaseData.cc_messageCode = purchaseResponse.cc_messageCode if purchaseResponse.cc_messageCode
            purchaseData.cc_description = purchaseResponse.cc_description if purchaseResponse.cc_description
            purchaseData.cc_accountNum = purchaseResponse.cc_accountNum if purchaseResponse.cc_accountNum
            if isSubscription and cart_entry.purchaseItem.auto_renew
              #TODO: HAVE TO SET THESE IF IT"S A SUBSCRIPTION
              purchaseData.next_payment_amount = cart_entry.purchaseItem.todays_payment
              now = moment()
              now_date = now.date()
              now_month = now.month()+1
              now_year = now.year()
              if purchaseData.status is 'auto-pay-monthly'
                now_month = now_month + 1
                now_month = 1 if now_month is 13
                purchaseData.next_payment_date = "#{now_year}-#{now_month}-#{now_date}"
              else if purchaseData.status is 'auto-pay-yearly'
                now_year = now_year + 1
                purchaseData.next_payment_date = "#{now_year}-#{now_month}-#{now_date}"

            #basePrice will be handed to us and was the member price, non price, or deal price whichever was correct on the purchase
            Purchase.upsert purchaseData, {}, (err, purchase) ->
              return next err, outfitter, purchase

          # Calculate and Save Commissions
          (outfitter, purchase, next) =>
            @calculateCommissions user, outfitter, purchase, purchase.basePrice, (err, commResults) ->
              console.log "Error processing commissions for this purchase: ", err if err
              #Ignore the error and move on
              return next null, user, outfitter, purchase

          # Send Purchase email notifications
          (user, outfitter, purchase, next) =>
            if cart.do_not_send_email
              return next null, user, outfitter, purchase
            huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?
            emailParams = null
            emailParams = cart.emailParams if cart.emailParams?
            emailParams.inStorePurchase = cart.inStorePurchase if cart.inStorePurchase
            if cart.send_email_sync or huntCatalogCopy.title?.toLowerCase().indexOf("renewal") > -1 or purchase.status?.toLowerCase().indexOf("auto") > -1
              #todo: the conditons after the original cart.send_email_sync can be removed.  They are only there for backaward compatibility until the membership renewal script is updated to pass send_email_sync
              @sendEmailPurchaseNotifications_PerCartEntry user, outfitter, huntCatalogCopy, purchase._id, purchase.tenantId, emailParams, (err, result) ->
                #renewals run from a cronned process script, and must wait sync for email to send.
                #Note always ignore the email errors as the purchase needs to continue.
                return next null, user, outfitter, purchase
            else
              #Don't wait for emails to send. Move on.
              #Note always ignore the email errors as the purchase needs to continue.
              @sendEmailPurchaseNotifications_PerCartEntry user, outfitter, huntCatalogCopy, purchase._id, purchase.tenantId, emailParams
              return next null, user, outfitter, purchase

          # Create a Service Request
          (user, outfitter, purchase, next) =>
            return next null, user, outfitter, purchase
            #DEBUG SKIP SENDING SERVICE REQUEST
            huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?
            return next null, user, outfitter, purchase if huntCatalogCopy?.type is "hunt"
            #Skip hunts, create service requests "purchase" items for the rest
            @createServiceRequest user, tenantId, purchase, (err, serviceRequest) ->
              console.log "Error creating service request for this purchase: ", err if err
              #Ignore the error and let the purchase finish successfully.
              return next null, user, outfitter, purchase

          # Process User Updates
          (user, outfitter, purchase, next) =>
            @processUserUpdates purchase, (err, userUpdateRsp) ->
              console.log "Error processing user updates for this purchase: ", err if err
              #Ignore the error and let the purchase finish successfully.
              return next null, user, outfitter, purchase, userUpdateRsp

          # Special check if OSS purchase and need to give RBO commissions for it
          (user, outfitter, purchase, userUpdateRsp, next) =>
            return next null, user, outfitter, purchase, userUpdateRsp
            #no long needed.  OSS sales are disabled for now.
            # return next null, user, outfitter, purchase, userUpdateRsp unless purchase.tenantId.toString() is OSSTenantId or purchase.tenantId.toString() is OSSTestTenantId
            @addToRBOPurchase user, purchase, (err, addToRBOPurchaseRsp) ->
              console.log "Error adding RBO copy of this purchase for commissions: ", err if err
              #Ignore the error and let the purchase finish successfully.
              return next null, user, outfitter, purchase, userUpdateRsp

        ], (err, user, outfitter, purchase, userUpdateRsp) ->
          results = {}
          results.purchaseId = purchase._id if purchase
          results.newMember = userUpdateRsp.newMember if userUpdateRsp?.newMember
          results.newRep = userUpdateRsp.newRep if userUpdateRsp?.newRep
          results.purchaseResponse = purchaseResponse
          return done err, results

      #Get Order Number (shared with all purchases)
      Tenant.getNextInvoiceNumber tenantId, (err, orderNumber) =>
        return cb err if err
        cart.orderNumber = orderNumber

        #Now get individual invoiceNumbers for each line item for tracking POS and Quickbooks
        assignInvoiceNumbers = (cart_entry, done) ->
          Tenant.getNextInvoiceNumber tenantId, (err, invoiceNumber) ->
            return done err if err
            cart_entry.purchaseItem.invoiceNumber = invoiceNumber
            return done null, cart_entry

        async.mapSeries cart.cart_entries, assignInvoiceNumbers, (err, results) ->
          return cb err if err
          cart.orderNumber = cart.cart_entries[0].purchaseItem.invoiceNumber #Lynley request make cart order # be the same as the invoice # as the first item in the cart.
          cart.cart_entries = results

        #Now save each item in the cart to NRADS
        async.mapSeries cart.cart_entries, processCartEntry, (err, results) ->
          console.log err if err
          return cb err, results

    isRBO: (user) ->
      tenantId = user.tenantId.toString()
      RBO = "5684a2fc68e9aa863e7bf182"
      GMT = "53a28a303f1e0cc459000127"
      NGROK_LOCAL = "5bd75eec2ee0370c43bc3ec7"
      if tenantId is RBO
        return true
      else if tenantId is GMT
        return true
      else if tenantId is NGROK_LOCAL
        return true
        #return false
      else
        return false


  }

  _.bindAll.apply _, [HuntCatalogs].concat(_.functions(HuntCatalogs))
  return HuntCatalogs
