_ = require "underscore"
async = require "async"
moment = require "moment"

AuthorizeNet  = require 'authorizenet'
AuthContracts = AuthorizeNet.APIContracts
AuthControllers = AuthorizeNet.APIControllers
AuthConstants = AuthorizeNet.Constants


module.exports = (TENANT_IDS, CreditCardClients, User) ->

  authorizenetapi = {

    logRequest: (apictrl, request) ->
      logReq = true #debug
      if logReq
        console.log "Calling Authorize.net API #{apictrl} with data: "
        console.log JSON.stringify(request.getJSON(), null, 2)

    get_CC_Client: (tenantId) ->
      tenantId = tenantId.toString() if tenantId
      #Get the correct Credit Card gateway account
      pGateway = {}
      if tenantId is TENANT_IDS.RollingBonesTest or tenantId is TENANT_IDS.OSSTest
        ProductionEnvironment = false
        ccClient = CreditCardClients.ccc_rbo_sandbox
        PubKey = CreditCardClients.ccc_rbo_sandbox_public_client_key
      else if tenantId is TENANT_IDS.RollingBones or tenantId is TENANT_IDS.OSS
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_rbo
        PubKey = CreditCardClients.ccc_rbo_public_client_key
      else if tenantId is TENANT_IDS.OSSDemo
        ProductionEnvironment = false
        ccClient = CreditCardClients.ccc_rbo_sandbox
        PubKey = CreditCardClients.ccc_rbo_sandbox_public_client_key
      else if tenantId is TENANT_IDS.RiverNRidge
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_rivernridge
        PubKey = CreditCardClients.ccc_rivernridge_public_client_key
      else if tenantId is TENANT_IDS.AnglersHaven
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_angler_haven
        PubKey = CreditCardClients.ccc_angler_haven_public_client_key
      else if tenantId is TENANT_IDS.XtremeXpeditions
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_xtremexpeditions
        PubKey = CreditCardClients.ccc_xtremexpeditions_public_client_key
      else if tenantId is TENANT_IDS.CharitonRiver
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_chariton_river
        PubKey = CreditCardClients.ccc_chariton_river_public_client_key
      else if tenantId is TENANT_IDS.DeerMeadows
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_deer_meadows
        PubKey = CreditCardClients.ccc_deer_meadows_public_client_key
      else if tenantId is TENANT_IDS.FullScope
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_full_scope
        PubKey = CreditCardClients.ccc_full_scope_public_client_key
      else if tenantId is TENANT_IDS.GoingDark
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_going_dark
        PubKey = CreditCardClients.ccc_going_dark_public_client_key
      else if tenantId is TENANT_IDS.PoncaCreek
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_ponca_creek
        PubKey = CreditCardClients.ccc_ponca_creek_public_client_key
      else if tenantId is TENANT_IDS.TwilightTines
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_twilight_tines
        PubKey = CreditCardClients.ccc_twilight_tines_public_client_key
      else if tenantId is TENANT_IDS.PhireCreek
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_phire_creek
        PubKey = CreditCardClients.ccc_phire_creek_public_client_key
      else if tenantId is TENANT_IDS.MesquiteMountain
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_mesquite_mtn
        PubKey = CreditCardClients.ccc_mesquite_mtn_public_client_key
      else if tenantId is TENANT_IDS.HaymakerLodge
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_haymaker_lodge
        PubKey = CreditCardClients.ccc_haymaker_lodge_public_client_key
      else if tenantId is TENANT_IDS.CrusaderOutdoors
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_crusader_outdoors
        PubKey = CreditCardClients.ccc_crusader_outdoors_public_client_key
      else if tenantId is TENANT_IDS.ORG
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_org
        PubKey = CreditCardClients.ccc_org_public_client_key
      else if tenantId is TENANT_IDS.FergTaxidermy
        ProductionEnvironment = true
        ccClient = CreditCardClients.ccc_ferg_taxidermy
        PubKey = CreditCardClients.ccc_ferg_taxidermy_public_client_key
      else
        pGateway = null
        console.log "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you."

      if pGateway
        pGateway.ProductionEnvironment = ProductionEnvironment
        pGateway.ccClient = ccClient
        pGateway.PubKey = PubKey

      return pGateway

    #Create/Update Authorize.net Customer Profile
    upsertCustomerProfile: (user, cb) ->
      #Check if customer profile already exists
      if user.payment_customerProfileId
        @updateCustomerProfile user, (err, authnet_customer) =>
          return cb err if err
          return cb "Authorize.net update customer profile failed to return a successful response." unless authnet_customer
          #THERE ISNT ACTUALLY ANYTHING RETURNED FROM AUTH.NET FOR US TO UPDATE ON THE CUSTOMER IN RADS.
          return cb err, user
#         @updateUser user, authnet_customer, (err, user) ->
#           return cb err, user
      else
        #Create Customer Profile (if doesn't exists)
        @createCustomerProfile user, (err, authnet_customer) =>
          if err?.message?.toLowerCase().indexOf("a duplicate record with id") > -1
            msgArray = err.message.split(" ")
            customerProfileId = msgArray[5] if msgArray?.length > 5
            if !isNaN(customerProfileId)
              authnet_customer = {
                customerProfileId: customerProfileId
              }
          else if err
            return cb err if err
          return cb "Authorize.net create customer profile failed to return a successful response." unless authnet_customer
          @updateUser user, authnet_customer, (err, user) ->
            return cb err, user


    #Create/Update Authorize.net Customer's Payment Profile
    upsertPaymentProfile: (user, paymentInfo, recurring, cb) ->
      if not cb
        cb = recurring
        recurring = false

      previousPaymentProfileId = user.payment_paymentProfileId
      payment_recurring_paymentProfileId = ""
      payment_recurring_paymentProfileId = user.payment_recurring_paymentProfileId if user.payment_recurring_paymentProfileId
      async.waterfall [
        #Create NEW Customer Payment Profile
        (next) =>
          @createPaymentProfile user, paymentInfo, (err, paymentProfile) ->
            return next err if err
            return next "Failed to create new authorize.net payment profile." unless paymentProfile?.paymentProfileId
            return next err, paymentProfile

        #Validate the new customer payment profile
        (paymentProfile, next) =>
          skip = true #Validation is an optional flag we are setting when creating the payment profile so it's already done and doesn't need to be called explicitly.
          return next null, paymentProfile if skip
          @validatePaymentProfile user.tenantId, paymentProfile, paymentInfo, (err, validated) ->
            return next err if err
            return next "Payment validation failed. Please validate your credit card or bank information and try again." unless validated
            return next err, paymentProfile

        #Delete the "previous" customer payment profile (if new one is valid)
        (paymentProfile, next) =>
          #return next null, paymentProfile #LEAVE PREVIOUS PAYMENT METHODS THERE FOR NOW AS AUDIT TRAIL
          if previousPaymentProfileId and paymentProfile?.paymentProfileId and previousPaymentProfileId isnt paymentProfile.paymentProfileId and previousPaymentProfileId isnt payment_recurring_paymentProfileId
            @deletePaymentProfile user.tenantId, user.payment_customerProfileId, previousPaymentProfileId, (err, results) ->
              console.log "Failed to delete authorize.net payment profile with error: ", err if err
              return next null, paymentProfile
          else
            return next null, paymentProfile

        #Save the new auth.net customer payment profile id with the user in RADS.
        (paymentProfile, next) =>
          return next "Missing payment profile id for user: ", user._id unless paymentProfile?.paymentProfileId
          authnet_customer = {
            payment_paymentProfileId: paymentProfile.paymentProfileId
          }
          authnet_customer.payment_recurring_paymentProfileId = paymentProfile.paymentProfileId if recurring
          @updateUser user, authnet_customer, (err, user) ->
            return next err, user
      ], (err, results) ->
        return cb err, results


    getCustomerProfile: (user, cb) ->
      return cb "NOT IMPLEMENTED"
      return cb null, results


    createCustomerProfile: (user, cb) ->
      pGateway = @get_CC_Client(user.tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient
      if user.clientId
        clientId = user.clientId
      else
        clientId = user._id unless user.clientId
      customerProfileType = new (AuthContracts.CustomerProfileType)
      customerProfileType.setMerchantCustomerId clientId
      customerProfileType.setDescription "Profile created from clientId #{clientId}"
      customerProfileType.setEmail user.email
      createRequest = new (AuthContracts.CreateCustomerProfileRequest)
      createRequest.setProfile customerProfileType
      createRequest.setMerchantAuthentication ccClient
      @logRequest("CreateCustomerProfileController", createRequest)
      ctrl = new (AuthControllers.CreateCustomerProfileController)(createRequest.getJSON())
      ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
      console.log "AuthorizeNet.ProductionEnviroment: ", pGateway.ProductionEnvironment
      ctrl.execute () =>
        apiResponse = ctrl.getResponse()
        response = new AuthContracts.CreateCustomerProfileResponse(apiResponse)
        @handleAuthNetResponse response, (err, response) ->
          return cb err if err
          authnet_customer = {}
          authnet_customer.customerProfileId = response.getCustomerProfileId()
          return cb err, authnet_customer


    updateCustomerProfile: (user, cb) ->
      pGateway = @get_CC_Client(user.tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient
      if user.clientId
        clientId = user.clientId
      else
        clientId = user._id unless user.clientId
      customerDataForUpdate = new (AuthContracts.CustomerProfileExType)
      customerDataForUpdate.setCustomerProfileId user.payment_customerProfileId
      customerDataForUpdate.setMerchantCustomerId clientId
      customerDataForUpdate.setDescription "Profile created from clientId #{clientId}"
      customerDataForUpdate.setEmail user.email
      updateRequest = new (AuthContracts.UpdateCustomerProfileRequest)
      updateRequest.setProfile customerDataForUpdate
      updateRequest.setMerchantAuthentication ccClient
      @logRequest("UpdateCustomerProfileController", updateRequest)
      ctrl = new (AuthControllers.UpdateCustomerProfileController)(updateRequest.getJSON())
      ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
      console.log "AuthorizeNet.ProductionEnviroment: ", pGateway.ProductionEnvironment
      ctrl.execute () =>
        apiResponse = ctrl.getResponse()
        response = new AuthContracts.CreateCustomerProfileResponse(apiResponse)
        @handleAuthNetResponse response, (err, response) ->
          return cb err if err
          authnet_customer = {}
          authnet_customer.customerProfileId = response.getCustomerProfileId()
          return cb err, authnet_customer


    createPaymentProfile: (user, paymentInfo, cb) ->
      pGateway = @get_CC_Client(user.tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient
      ccPubKey = pGateway.PubKey
      return cb "Cannot create payment profile, missing payment_customerProfileId on user: #{user._id}" unless user.payment_customerProfileId
      paymentType = new (AuthContracts.PaymentType)
      if paymentInfo.authorize_net_data_descriptor
        paymentData = new (AuthContracts.OpaqueDataType)
        paymentData.dataDescriptor = paymentInfo.authorize_net_data_descriptor
        paymentData.dataValue = paymentInfo.authorize_net_data_value
        paymentData.dataKey = ccPubKey
        paymentType.setOpaqueData paymentData
      else
        card = paymentInfo
        creditCard = new (AuthContracts.CreditCardType)
        creditCard.setCardNumber card.number
        creditCard.setExpirationDate "#{card.month}#{card.year.substr(-2)}" if card.month and card.year
        creditCard.setCardCode card.code
        paymentType.setCreditCard creditCard

      if paymentInfo.first_name
        billTo = new (AuthContracts.CustomerAddressType)
        billTo.setFirstName paymentInfo.first_name if paymentInfo.first_name
        billTo.setLastName paymentInfo.last_name if paymentInfo.last_name
        billTo.setAddress paymentInfo.address if paymentInfo.address
        billTo.setCity paymentInfo.city if paymentInfo.city
        billTo.setState paymentInfo.state if paymentInfo.state
        billTo.setZip paymentInfo.postal if paymentInfo.postal
        billTo.setCountry paymentInfo.country if paymentInfo.country

      profile = new AuthContracts.CustomerPaymentProfileType()
      profile.setBillTo billTo
      profile.setPayment paymentType
      profile.setDefaultPaymentProfile true

      createRequest = new (AuthContracts.CreateCustomerPaymentProfileRequest)
      createRequest.setPaymentProfile profile
      createRequest.setCustomerProfileId user.payment_customerProfileId
      createRequest.setMerchantAuthentication ccClient
      createRequest.setValidationMode(AuthContracts.ValidationModeEnum.LIVEMODE);

      @logRequest("CreateCustomerPaymentProfileController", createRequest)
      ctrl = new (AuthControllers.CreateCustomerPaymentProfileController)(createRequest.getJSON())
      ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
      console.log "AuthorizeNet.ProductionEnviroment: ", pGateway.ProductionEnvironment
      ctrl.execute () =>
        apiResponse = ctrl.getResponse()
        response = new AuthContracts.CreateCustomerPaymentProfileResponse(apiResponse)
        @handleAuthNetResponse response, (err, response) ->
          if err
            #check if duplicate payment profile already exists and use it
            if err.customerProfileId and err.customerPaymentProfileId
              paymentProfile = {}
              paymentProfile.paymentProfileId = err.customerPaymentProfileId
              paymentProfile.customerProfileId = err.customerProfileId
              err = null
            else
              return cb err if err
          paymentProfile = {}
          paymentProfile.paymentProfileId = response.getCustomerPaymentProfileId()
          paymentProfile.customerProfileId = user.payment_customerProfileId
          return cb err, paymentProfile


    updatePaymentProfile: (user, cb) ->
      return cb "NOT IMPLEMENTED, current workflow is to create and validate a new profile, and delete the previous one."
      return cb null, results

    getPaymentProfile: (user, cb) ->
      return cb "Payment profile does not yet exist for user #{user.clientId}" unless user.payment_customerProfileId and user.payment_paymentProfileId
      pGateway = @get_CC_Client(user.tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient
      request = new (AuthContracts.GetCustomerPaymentProfileRequest)
      request.setMerchantAuthentication ccClient
      request.setCustomerProfileId user.payment_customerProfileId
      request.setCustomerPaymentProfileId user.payment_paymentProfileId
      @logRequest("GetCustomerProfileController", request)
      ctrl = new (AuthControllers.GetCustomerProfileController)(request.getJSON())
      ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
      console.log "AuthorizeNet.ProductionEnviroment: ", pGateway.ProductionEnvironment
      ctrl.execute () =>
        apiResponse = ctrl.getResponse()
        response = new AuthContracts.GetCustomerPaymentProfileResponse(apiResponse)
        @handleAuthNetResponse response, (err, response) ->
          return cb err if err
          resp_paymentProfile = response.getPaymentProfile()
          resp_billTo = resp_paymentProfile.getBillTo() if resp_paymentProfile
          resp_paymentInfo = resp_paymentProfile.getPayment() if resp_paymentProfile
          resp_card = resp_paymentInfo.getCreditCard() if resp_paymentInfo
          resp_bankacct = resp_paymentInfo.getBankAccount() if resp_paymentInfo
          customerProfileId = resp_paymentProfile.getCustomerPaymentProfileId()
          customerPaymentProfileId = resp_paymentProfile.getCustomerProfileId()
          if resp_billTo
            first_name = resp_billTo.getFirstName()
            last_name = resp_billTo.getLastName()
            zip = resp_billTo.getZip()

          if resp_card
            cc_last4 = resp_card.getCardNumber()
          if resp_bankacct
            accountType = resp_bankacct.getAccountType()
            routingNumber = resp_bankacct.getRoutingNumber()
            accountNumber = resp_bankacct.getAccountNumber()
            nameOnAccount = resp_bankacct.getNameOnAccount()
            echeckType = resp_bankacct.getEcheckType()
          payment_info = {}
          payment_info.billing_zip = zip if zip
          payment_info.cc_name = "#{first_name} #{last_name}" if first_name and last_name
          payment_info.cc_last4 = cc_last4 if cc_last4
          payment_info.accountType = accountType if accountType
          payment_info.routingNumber = routingNumber if routingNumber
          payment_info.accountNumber = accountNumber if accountNumber
          payment_info.nameOnAccount = nameOnAccount if nameOnAccount
          payment_info.echeckType = echeckType if echeckType
          return cb err, payment_info

    validatePaymentProfile: (tenantId, paymentProfile, paymentInfo, cb) ->
      pGateway = @get_CC_Client(tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient
      validateRequest = new (AuthContracts.ValidateCustomerPaymentProfileRequest)
      validateRequest.setMerchantAuthentication ccClient
      validateRequest.setCustomerProfileId paymentProfile.customerProfileId
      validateRequest.setCustomerPaymentProfileId paymentProfile.paymentProfileId
      validateRequest.setValidationMode(AuthContracts.ValidationModeEnum.LIVEMODE);
      validateRequest.setCardCode paymentInfo.code if paymentInfo.code #If its a cc card this is required
      @logRequest("ValidateCustomerPaymentProfileController", validateRequest)
      ctrl = new (AuthControllers.ValidateCustomerPaymentProfileController)(validateRequest.getJSON())
      ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
      console.log "AuthorizeNet.ProductionEnviroment: ", pGateway.ProductionEnvironment
      ctrl.execute () =>
        apiResponse = ctrl.getResponse()
        response = new AuthContracts.ValidateCustomerPaymentProfileResponse(apiResponse)
        @handleAuthNetResponse response, (err, response) ->
          return cb err if err
          validated = true
          return cb err, validated


    deletePaymentProfile: (tenantId, customerProfileId, paymentProfileId, cb) ->
      pGateway = @get_CC_Client(tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient
      deleteRequest = new (AuthContracts.DeleteCustomerPaymentProfileRequest)
      deleteRequest.setMerchantAuthentication ccClient
      deleteRequest.setCustomerProfileId customerProfileId
      deleteRequest.setCustomerPaymentProfileId paymentProfileId
      @logRequest("DeleteCustomerPaymentProfileController", deleteRequest)
      ctrl = new (AuthControllers.DeleteCustomerPaymentProfileController)(deleteRequest.getJSON())
      ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
      console.log "AuthorizeNet.ProductionEnviroment: ", pGateway.ProductionEnvironment
      ctrl.execute () =>
        apiResponse = ctrl.getResponse()
        response = new AuthContracts.DeleteCustomerPaymentProfileResponse(apiResponse)
        @handleAuthNetResponse response, (err, response) ->
          return cb err if err
          deleted = true
          return cb err, deleted

    #Will be obselete once new RRADS shopping cart is live.  KEEP for reference
    purchaseOneTime: (user, huntCatalog, purchaseItem, cb) ->
      pGateway = @get_CC_Client(user.tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient

      customerProfileIdType = new AuthContracts.CustomerProfileIdType()
      customerProfileIdType.setCustomerProfileId user.payment_customerProfileId

      profileToCharge = new AuthContracts.CustomerProfilePaymentType()
      profileToCharge.setCustomerProfileId(user.payment_customerProfileId)
      paymentProfile = new AuthContracts.PaymentProfile()
      paymentProfile.setPaymentProfileId user.payment_paymentProfileId
      profileToCharge.setPaymentProfile(paymentProfile);

      orderDetails = new (AuthContracts.OrderType)
      orderDetails.setDescription "#{huntCatalog.huntNumber}: #{huntCatalog.title}"
      orderDetails.setInvoiceNumber purchaseItem.invoiceNumber if purchaseItem.invoiceNumber

      if purchaseItem.sales_tax
        tax = new (AuthContracts.ExtendedAmountType)
        tax.setAmount purchaseItem.sales_tax
        tax.setName 'Sales Tax'
        tax.setDescription 'Sales Tax'

      if purchaseItem.shipping
        shipping = new (AuthContracts.ExtendedAmountType)
        shipping.setAmount purchaseItem.shipping
        shipping.setName 'Shipping'
        shipping.setDescription 'Shipping'

      userFieldList = []
      userField = new (AuthContracts.UserField)
      userField.setName 'Hunt Catalog Number'
      userField.setValue huntCatalog.huntNumber
      userFieldList.push userField
      userFields = new (AuthContracts.TransactionRequestType.UserFields)
      userFields.setUserField userFieldList

      if huntCatalog.pricingNotes
        huntCatalog.pricingNotes = huntCatalog.pricingNotes.replace(/&/g, "and")
        userField = new (AuthContracts.UserField)
        userField.setName 'Pricing Options'
        userField.setValue huntCatalog.pricingNotes
        userFieldList.push userField

      if purchaseItem.notes
        userField = new (AuthContracts.UserField)
        userField.setName 'Purchase Notes'
        userField.setValue purchaseItem.notes
        userFieldList.push userField

      if user.clientId
        userField = new (AuthContracts.UserField)
        userField.setName 'Client Id'
        userField.setValue user.clientId
        userFieldList.push userField

      transactionRequestType = new (AuthContracts.TransactionRequestType)
      #transactionRequestType.setTransactionType AuthContracts.TransactionTypeEnum.AUTHONLYTRANSACTION
      transactionRequestType.setTransactionType AuthContracts.TransactionTypeEnum.AUTHCAPTURETRANSACTION
      transactionRequestType.setAmount purchaseItem.todays_payment
      transactionRequestType.setProfile profileToCharge
      transactionRequestType.setUserFields userFields
      transactionRequestType.setOrder orderDetails
      transactionRequestType.setTax tax if tax
      transactionRequestType.setShipping shipping if shipping
      #transactionRequestType.setTransactionSettings transactionSettings
      #transactionRequestType.setLineItems lineItems
      #transactionRequestType.setSurcharge surcharge if surcharge
      #transactionRequestType.setDuty duty if duty

      purchaseRequest = new AuthContracts.CreateTransactionRequest()
      purchaseRequest.setMerchantAuthentication ccClient
      purchaseRequest.setTransactionRequest transactionRequestType

      attempts = 0
      sendToAuthNet = (purchaseRequest, attempts, done) =>
        attempts = attempts + 1
        @logRequest("CreateTransactionController", purchaseRequest)
        ctrl = new AuthControllers.CreateTransactionController(purchaseRequest.getJSON())
        ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
        console.log "pGateway.ProductionEnvironment: ", pGateway.ProductionEnvironment
        console.log "Attempt: #{attempts}" if attempts > 1
        ctrl.execute ()=>
          apiResponse = ctrl.getResponse()
          response = new AuthContracts.CreateTransactionResponse(apiResponse)
          @handleAuthNetResponse response, (err, response) ->
            if attempts < 6 and err?.result_code is "Error" and err?.code is "E00040"
              setTimeout ->
                console.log "Trying again after 5 seconds.................."
                sendToAuthNet(purchaseRequest, attempts, done)
              , 5000
            else
              return done err if err
              return done "Authorize request failed without valid response." unless response

              auth_transactionResponse = response.getTransactionResponse()
              tranResponse = {}
              if auth_transactionResponse
                tranResponse.cc_transId = auth_transactionResponse.getTransId()
                tranResponse.cc_responseCode = auth_transactionResponse.getResponseCode()
                tranResponse.cc_messageCode = auth_transactionResponse.getMessages().getMessage()[0].getCode()
                tranResponse.cc_description = auth_transactionResponse.getMessages().getMessage()[0].getDescription()
                tranResponse.cc_accountNum = auth_transactionResponse.accountNumber
              else
                err = "Failed to get a valid response from the Payment gateway."
              return done err, tranResponse

      sendToAuthNet purchaseRequest, attempts, (err, response) ->
        return cb err, response


    purchaseOneTimeCart: (user, paymentMethod, cart, cb) ->
      return cb "Missing Order Number" unless cart.cart_entries[0]?.listing?.catalog_id?.length
      return cb "Missing Cart Price Today's Payment" unless cart.price_todays_payment?

      console.log "Processing Cart Order Number orderNumber: ", cart.orderNumber
      console.log "Payment Method: ", paymentMethod

      if paymentMethod is "check"
        console.log "Pay by check, skipping authorize.net gateway setup. #{paymentMethod}"
      else
        pGateway = @get_CC_Client(user.tenantId)
        return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
        ccClient = pGateway.ccClient if pGateway?.ccClient

      #BYPASS AUTH.NET CALL
      tranResponse = {}
      tranResponse.cc_transId = "12345"
      tranResponse.cc_responseCode = "TEST"
      tranResponse.cc_messageCode = "TEST"
      tranResponse.cc_description = "SKIP AUTH.NET CART PURCHASE"
      tranResponse.cc_accountNum = "888888"
      #return cb null, tranResponse

      #BYPASS AUTH.NET CALL
      min = 1000
      max = 100000000000
      randomTransId = Math.floor(Math.random() * (max - min) + min)
      if cart.price_total == 0
        tranResponse = {}
        tranResponse.cc_transId = randomTransId
        tranResponse.cc_responseCode = "ZERO"
        tranResponse.cc_messageCode = "ZERO"
        tranResponse.cc_description = "Zero Dollar Item Purchase"
        tranResponse.cc_accountNum = "N/A"
        return cb null, tranResponse
      else if paymentMethod is "check"
        purchaseItem = cart.cart_entries[0].purchaseItem if cart?.cart_entries?.length
        tranResponse = {}
        tranResponse.cc_transId = randomTransId
        tranResponse.cc_responseCode = paymentMethod
        tranResponse.cc_messageCode = paymentMethod
        tranResponse.cc_description = paymentMethod + " purchase"
        tranResponse.cc_accountNum = "N/A"
        tranResponse.cc_accountNum = "check# #{purchaseItem.check_number}" if purchaseItem?.check_number
        return cb null, tranResponse
      else if paymentMethod is "cash"
        tranResponse = {}
        tranResponse.cc_transId = randomTransId
        tranResponse.cc_responseCode = paymentMethod
        tranResponse.cc_messageCode = paymentMethod
        tranResponse.cc_description = paymentMethod + " purchase"
        tranResponse.cc_accountNum = "N/A"
        return cb null, tranResponse

      customerProfileIdType = new AuthContracts.CustomerProfileIdType()
      customerProfileIdType.setCustomerProfileId user.payment_customerProfileId

      profileToCharge = new AuthContracts.CustomerProfilePaymentType()
      profileToCharge.setCustomerProfileId(user.payment_customerProfileId)
      paymentProfile = new AuthContracts.PaymentProfile()
      if cart.renewal_only or cart.auto_payment
        paymentProfile.setPaymentProfileId user.payment_recurring_paymentProfileId
      else
        paymentProfile.setPaymentProfileId user.payment_paymentProfileId
      profileToCharge.setPaymentProfile(paymentProfile);

      #Top level Order details
      orderDetails = new (AuthContracts.OrderType)
      orderDetails.setInvoiceNumber cart.orderNumber if cart.orderNumber #poNumber
      orderDescription = "#{user.clientId}: #{cart.cart_entries[0].listing.catalog_id}"

      #Total Sales Tax if any
      taxExempt = true
      if cart.price_sales_tax? and cart.price_sales_tax > 0
        tax = new (AuthContracts.ExtendedAmountType)
        tax.setAmount cart.price_sales_tax.toFixed(2)
        tax.setName 'Sales Tax'
        tax.setDescription 'Sales Tax'
        taxExempt = false

      #Total Shipping if any
      if cart.price_shipping? and cart.price_shipping > 0
        shipping = new (AuthContracts.ExtendedAmountType)
        shipping.setAmount cart.price_shipping.toFixed(2)
        shipping.setName 'Shipping'
        shipping.setDescription 'Shipping'

      userFieldList = []
      if user.clientId
        userField = new (AuthContracts.UserField)
        userField.setName 'Client Id'
        userField.setValue user.clientId
        userFieldList.push userField

      lineItemsAuth = new (AuthContracts.ArrayOfLineItem) #one or more up to 30
      lineItems = []
      for cart_entry in cart.cart_entries
        huntCatalog = cart_entry.huntCatalog
        listing = cart_entry.listing
        purchaseItem = cart_entry.purchaseItem
        pricing_info = cart_entry.pricing_info
        orderDescription = "#{orderDescription}, #{cart_entry.listing.catalog_id}"
        lineItemPrice = pricing_info.price_todays_payment
        lineItemPrice = lineItemPrice - pricing_info.sales_tax if pricing_info.sales_tax
        lineItemPrice = lineItemPrice - pricing_info.price_shipping if pricing_info.price_shipping
        lineItemPrice = lineItemPrice.toFixed(2) if lineItemPrice

        #Create Line Item
        lineItem = new (AuthContracts.LineItemType)
        lineItem.setItemId purchaseItem.invoiceNumber
        lineItem.setName listing.catalog_id.substr(0,30)
        lineItem.setDescription listing.title.replace(/&/g, "and")
        lineItem.setQuantity 1 #Items are broken
        lineItem.setUnitPrice lineItemPrice #excluding tax and shipping
        if cart_entry.pricing_info.sales_tax? and cart_entry.pricing_info.sales_tax > 0
          lineItem.setTaxable true
        else
          lineItem.setTaxable false
        lineItems.push lineItem
      #END CART ENTRY FOR LOOP

      lineItemsAuth.setLineItem lineItems
      orderDetails.setDescription orderDescription.substr(0,255)

      transactionRequestType = new (AuthContracts.TransactionRequestType)
      #transactionRequestType.setTransactionType AuthContracts.TransactionTypeEnum.AUTHONLYTRANSACTION
      transactionRequestType.setTransactionType AuthContracts.TransactionTypeEnum.AUTHCAPTURETRANSACTION
      transactionRequestType.setAmount cart.price_todays_payment.toFixed(2) if cart.price_todays_payment
      transactionRequestType.setProfile profileToCharge
      #transactionRequestType.setUserFields userFieldList if userFieldList?.length
      transactionRequestType.setOrder orderDetails
      transactionRequestType.setTax tax if tax
      transactionRequestType.setTaxExempt taxExempt
      transactionRequestType.setShipping shipping if shipping
      transactionRequestType.setLineItems lineItemsAuth
      #transactionRequestType.setTransactionSettings transactionSettings

      purchaseRequest = new AuthContracts.CreateTransactionRequest()
      purchaseRequest.setMerchantAuthentication ccClient
      purchaseRequest.setTransactionRequest transactionRequestType

      attempts = 0
      sendToAuthNet = (purchaseRequest, attempts, done) =>
        attempts = attempts + 1
        @logRequest("CreateTransactionController", purchaseRequest)
        ctrl = new AuthControllers.CreateTransactionController(purchaseRequest.getJSON())
        ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
        console.log "pGateway.ProductionEnvironment: ", pGateway.ProductionEnvironment
        console.log "Attempt: #{attempts}" if attempts > 1
        ctrl.execute ()=>
          apiResponse = ctrl.getResponse()
          response = new AuthContracts.CreateTransactionResponse(apiResponse)
          @handleAuthNetResponse response, (err, response) ->
            if attempts < 6 and err?.result_code is "Error" and err?.code is "E00040"
              setTimeout ->
                console.log "Trying again after 5 seconds.................."
                sendToAuthNet(purchaseRequest, attempts, done)
              , 5000
            else
              console.log "Error: should be returning an error: ", err if err
              return done err if err
              return done "Authorize request failed without valid response." unless response

              auth_transactionResponse = response.getTransactionResponse()
              tranResponse = {}
              if auth_transactionResponse
                tranResponse.cc_transId = auth_transactionResponse.getTransId()
                tranResponse.cc_responseCode = auth_transactionResponse.getResponseCode()
                tranResponse.cc_messageCode = auth_transactionResponse.getMessages().getMessage()[0].getCode()
                tranResponse.cc_description = auth_transactionResponse.getMessages().getMessage()[0].getDescription()
                tranResponse.cc_accountNum = auth_transactionResponse.accountNumber
              else
                err = "Failed to get a valid response from the Payment gateway."
              return done err, tranResponse

      sendToAuthNet purchaseRequest, attempts, (err, response) ->
        return cb err, response

    #Will be obselete once new RRADS shopping cart is live. KEEP for reference
    purchase_cc_reacurring: (user, intervalUnit, totalOccurrences, huntCatalog, purchaseItem, cb) ->
      pGateway = @get_CC_Client(user.tenantId)
      return cb "ERROR: Credit Card vendor is not setup for this Tenant.  Please contact OSS to request using this feature.  Thank you." unless pGateway?.ccClient
      ccClient = pGateway.ccClient

      customerProfileIdType = new AuthContracts.CustomerProfileIdType()
      customerProfileIdType.setCustomerProfileId user.payment_customerProfileId
      customerProfileIdType.setCustomerPaymentProfileId user.payment_paymentProfileId

      startDate = moment().format('YYYY-MM-DD') #today
      interval = new (AuthContracts.PaymentScheduleType.Interval)
      interval.setUnit(AuthContracts.ARBSubscriptionUnitEnum.MONTHS)
      if intervalUnit is "months"
        interval.setLength(1)
      else if intervalUnit is "years"
        interval.setLength(12)
      else
        cb "Invalid interval unit: " + intervalUnit
      paymentScheduleType = new (AuthContracts.PaymentScheduleType)
      paymentScheduleType.setInterval(interval)
      paymentScheduleType.setStartDate(startDate)
      paymentScheduleType.setTotalOccurrences(totalOccurrences)
      paymentScheduleType.setTrialOccurrences(0)

      userFieldList = []
      userField = new (AuthContracts.UserField)
      userField.setName 'Hunt Catalog ID'
      userField.setValue huntCatalog._id
      userFieldList.push userField
      userFields = new (AuthContracts.TransactionRequestType.UserFields)
      userFields.setUserField userFieldList

      orderDetails = new (AuthContracts.OrderType)
      orderDetails.setDescription "#{huntCatalog.huntNumber}: #{huntCatalog.title}"
      orderDetails.setInvoiceNumber purchaseItem.invoiceNumber if purchaseItem.invoiceNumber

      subscriptionRequestType = new (AuthContracts.ARBSubscriptionType)
      subscriptionRequestType.setName huntCatalog.title
      subscriptionRequestType.setPaymentSchedule paymentScheduleType
      subscriptionRequestType.setAmount purchaseItem.todays_payment
      subscriptionRequestType.setTrialAmount 0
      subscriptionRequestType.setProfile customerProfileIdType
      subscriptionRequestType.setOrder orderDetails
      #subscriptionRequestType.setUserFields userFields   not available for subscriptions
      #subscriptionRequestType.setTax tax
      #subscriptionRequestType.setShipping shipping

      request = new AuthContracts.ARBCreateSubscriptionRequest()
      #request = new AuthContracts.ARBCreateSubscriptionRequest({clientId: "xxx", refId: "xxxx"})
      request.setMerchantAuthentication ccClient
      request.setSubscription subscriptionRequestType

      attempts = 0
      sendToAuthNet = (request, attempts, done) =>
        attempts = attempts + 1
        @logRequest("ARBCreateSubscriptionController", request)
        ctrl = new AuthControllers.ARBCreateSubscriptionController(request.getJSON())
        ctrl.setEnvironment(AuthConstants.endpoint.production) if pGateway.ProductionEnvironment
        console.log "pGateway.ProductionEnvironment: ", pGateway.ProductionEnvironment
        console.log "Attempt: #{attempts}" if attempts > 1
        ctrl.execute () =>
          apiResponse = ctrl.getResponse()
          response = new AuthContracts.ARBCreateSubscriptionResponse(apiResponse)
          @handleAuthNetResponse response, (err, response) ->
            #None Auth.net bug: https://community.developer.authorize.net/t5/Integration-and-Testing/E00040-when-Creating-Subscription-from-Customer-Profile/m-p/59597#M34176
            if attempts < 6 and err?.result_code is "Error" and err?.code is "E00040"
            #if attempts < 6
              #retry up to 30 seconds before failing.
              setTimeout ->
                console.log "Trying again after 5 seconds.................."
                sendToAuthNet(request, attempts, done)
              , 5000
            else
              return done err if err
              return done "Authorize request failed without valid response." unless response
              response = {
                subscriptionId: response.getSubscriptionId()
                cc_transId: response.getSubscriptionId()
                cc_messageCode: response.getMessages().getMessage()[0].getCode()
                cc_description: response.getMessages().getMessage()[0].getText()
                cc_accountNum: response.accountNumber
              }
              return done err, response
      sendToAuthNet request, attempts, (err, response) ->
        return cb err, response

    handleAuthNetResponse: (response, cb) ->
      error = null
      success = false
      #pretty print response
      console.log "Authorize.net response: "
      console.log JSON.stringify(response, null, 2)

      checkKnownErrors = (errorMsg) ->
        tErrors = errorMsg.split('has invalid child element')
        tErrors = errorMsg.split('has incomplete content') if tErrors.length < 2
        if tErrors.length > 1
          tErrors = tErrors[1].split("'")
          if tErrors.length > 1
            errorMsg = "Missing valid '#{tErrors[1]}'"
        return errorMsg


      if response
        if response.getMessages().getResultCode() == AuthContracts.MessageTypeEnum.OK
          if typeof response.getTransactionResponse is "function" and response.getTransactionResponse()?.getErrors()
            error = {}
            authError = response.getTransactionResponse().getErrors().getError()[0]
            error.result_code = authError.getErrorCode() if authError
            error.code = authError.getErrorCode() if authError
            error.message = authError.getErrorText() if authError
            error.customerProfileId = response.getCustomerProfileId() if response.customerProfileId
            error.customerPaymentProfileId = response.getCustomerPaymentProfileId() if response.customerPaymentProfileId
            error.message = checkKnownErrors(error.message)
          else
            success = true
        else
          error = {}
          messages = response.getMessages()
          error.result_code = messages.getResultCode() if messages
          error.code = messages.getMessage()[0].getCode() if messages
          error.message = messages.getMessage()[0].getText() if messages
          error.customerProfileId = response.getCustomerProfileId() if response.customerProfileId
          error.customerPaymentProfileId = response.getCustomerPaymentProfileId() if response.customerPaymentProfileId
      else
        error = {}
        error.code = "0"
        error.message = "Failed to get a response from the Payment gateway."
      return cb error, response


    updateUser: (user, authnet_customer, cb) ->
      #Save the new auth.net customer profile id with the user in RADS
      userData = {
        _id: user._id
      }
      userData.payment_customerProfileId = authnet_customer.customerProfileId if authnet_customer.customerProfileId
      userData.payment_paymentProfileId = authnet_customer.payment_paymentProfileId if authnet_customer.payment_paymentProfileId
      userData.payment_recurring_paymentProfileId = authnet_customer.payment_recurring_paymentProfileId if authnet_customer.payment_recurring_paymentProfileId
      User.upsert userData, (err, user) ->
        return cb err, user

  }

  _.bindAll.apply _, [authorizenetapi].concat(_.functions(authorizenetapi))
  return authorizenetapi
