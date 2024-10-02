_ = require "underscore"
async = require "async"
crypto = require "crypto"
moment = require "moment"

module.exports = (Purchase, User, APITOKEN, RBO_EMAIL_FROM_NAME, RBO_EMAIL_FROM, mailchimpapi, api_rbo) ->

  Purchases = {

    adminIndex: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Unauthorized'}, 400 unless req?.user?.isAdmin

      Purchase.byTenant req.tenant._id, (err, purchases) ->
        return res.json err, 500 if err

        addPurchase = (purchase, done) ->
          purchase.huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?.length
          User.byId purchase.userId, {}, (err, user) ->
            purchase.user = user
            return done err if err
            return done err, purchase unless purchase.userParentId
            User.byId purchase.userParentId, {}, (err, parent) ->
              purchase.parent = parent
              return done err, purchase

        async.mapSeries purchases, addPurchase, (err, purchases) ->
          return res.json err, 500 if err
          tPurchases = []
          for purchase in purchases
            tPurchases.push purchase if purchase
          res.json tPurchases


    byUserId: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'User Id required'}, 400 unless req.param('userId')

      userId = req.param('userId')

      Purchase.byUserId userId, req.tenant._id, (err, purchases) ->
        return res.json err, 500 if err

        addPurchase = (purchase, done) ->
          purchase.huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?.length
          User.byId purchase.userId, {}, (err, user) ->
            purchase.user = user
            return done err if err
            return done err, purchase unless purchase.userParentId
            User.byId purchase.userParentId, {}, (err, parent) ->
              purchase.parent = parent
              return done err, purchase

        async.mapSeries purchases, addPurchase, (err, purchases) ->
          return res.json err, 500 if err
          tPurchases = []
          for purchase in purchases
            tPurchases.push purchase if purchase
          res.json tPurchases


    read: (req, res) ->
      purchaseId = req.param('id')
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Purchase id required'}, 400 unless purchaseId
      Purchase.byId purchaseId, req.tenant._id, (err, purchase) ->
        return res.json err, 500 if err
        return res.json {error: 'Purchase not found.'}, 400 unless purchase
        return res.json {error: 'This user is unauthorized to retrieve this receipt.'}, 400 unless req.user._id.toString() is purchase.userId?.toString() or req.user._id.toString() is purchase.userParentId?.toString() or req.user.isAdmin or req.user.userType is "tenant_manager" or req.user.isOutfitter or req.user.isVendor
        return res.json purchase

    byInvoiceNumberPublic: (req, res) ->
      invoiceNumber = req.param('invoiceNumber')
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Invoice Number required'}, 400 unless invoiceNumber
      Purchase.byInvoiceNumber invoiceNumber, req.tenant._id, (err, purchase_full) ->
        return res.json err, 500 if err
        return res.json {error: 'Purchase not found.'}, 400 unless purchase_full
        return res.json {error: 'This user is unauthorized to retrieve this receipt.'}, 400 unless req.user._id.toString() is purchase_full.userId?.toString() or req.user._id.toString() is purchase_full.userParentId?.toString() or req.user.isAdmin or req.user.userType is "tenant_manager" or req.user.isOutfitter or req.user.isVendor
        purchase = _.pick(purchase_full, '_id', 'userId', 'amountTotal', 'amountPaid', 'invoiceNumber', 'purchaseNotes', 'createdAt', 'payments')
        huntCatalog = purchase_full.huntCatalogCopy[0]
        outfitter_name = ""
        if huntCatalog.outfitter_name
          outfitter_name = huntCatalog.outfitter_name
          outfitter_name_first_half = outfitter_name.substr(0, outfitter_name.length/2).trim()
          outfitter_name_second_half = outfitter_name.substr(outfitter_name.length/2, outfitter_name.length).trim()
          if outfitter_name_first_half is outfitter_name_second_half
            outfitter_name = outfitter_name_first_half
        purchase.huntCatalog_outfitter = outfitter_name
        purchase.huntCatalog_outfitter_id = huntCatalog.outfitter_userId
        purchase.huntCatalog_title = huntCatalog.title
        purchase.huntCatalog_number = huntCatalog.huntNumber
        User.byId purchase.userId, {}, (err, user) ->
          return res.json {error: err}, 500 if err
          return res.json {error: "User not found for invoice number: #{invoiceNumber}"}, 500 unless user
          #This is for showing minimal info on a public page so only return the name and ids.
          purchase.user = _.pick(user, '_id', 'name', 'clientId', 'tenantId', 'email')
          return res.json purchase

    adminCommissionsMarkAsPaid: (req, res) ->
      return res.json {error: 'Unauthorized'}, 400 unless req?.user?.isAdmin
      paidDate = req.body.paidDate
      purchaseIds = req.body.purchaseIds
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'paidDate required'}, 400 unless paidDate
      return res.json {error: 'list of purchases required'}, 400 unless purchaseIds

      paidDate = new Date(paidDate)
      paidDate = moment(paidDate)
      if purchaseIds?.length and purchaseIds?.length > 0
        Purchase.updateCommPaidDate req.tenant._id, paidDate, purchaseIds, (err, purchases) ->
          return res.json err, 500 if err
          return res.json {status: "success", numUpdated: purchases.length, paidDate: paidDate}
      else
        return res.json {status: "success", numUpdated: 0, paidDate: paidDate}

    recordPayment: (req, res) ->
      #Check if res is a web app.coffee req/rsp, or if it was called directly as a method with a cb.
      cb = res if !res.json?

      if !cb
        return res.json {error: 'Unauthorized'}, 400 unless req?.user?.isAdmin

      user = req.body.user
      originalPurchase = req.body.originalPurchase
      payment = req.body.payment

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'user required'} unless user
        return cb {error: 'original payload required'} unless originalPurchase
        return cb {error: 'payment payload required'} unless payment
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'user required'}, 400 unless user
        return res.json {error: 'original payload required'}, 400 unless originalPurchase
        return res.json {error: 'payment payload required'}, 400 unless payment

      tenantId = req.tenant._id
      async.waterfall [

        #retrieve original purchase object
        (next) ->
          return next "Missing original purchase id" unless originalPurchase._id
          Purchase.byId originalPurchase._id, tenantId, (err, purchase) ->
            return next err if err
            return next "Could not find original purchase for purchaseId: #{originalPurchase._id}, and tenantId: #{tenantId}" unless purchase
            return next null, purchase

        #process the payment and create new purchase entry for this payment
        (purchase, next) ->
          payload = {}
          payload.tenantId = tenantId
          payload.clientId = user.clientId
          payload.fullName = payment.name
          payload.nameOnAccount = payment.name
          payload.payment_method = payment.specific_type
          payload.check_number = payment.referenceNumber
          payload.check_name = payment.name
          payload.applyTo_invoiceNumber = originalPurchase.invoiceNumber
          payload.applyTo_purchaseId = originalPurchase._id
          payload.authorize_net_data_descriptor = payment.authorize_net_data_descriptor if payment.authorize_net_data_descriptor
          payload.authorize_net_data_value = payment.authorize_net_data_value if payment.authorize_net_data_value
          payload.address1 = payment.address1 if payment.address1
          payload.zip = payment.zip if payment.zip
          payload.city = payment.city if payment.city
          payload.state = payment.state if payment.state
          payload.country = payment.country if payment.country
          payload.cart = {
            'price_todays_payment': payment.amount
            'price_total': payment.amount,
            'price_processing_fee': 0
            'price_shipping': 0
            'price_tags_licenses': 0
            'price_options': 0
            'price_sales_tax': 0
            shopping_cart_entries: []
          }
          payload.cart.send_email_sync = true if req.body.send_email_sync
          payload.cart.do_not_send_email = true if req.body.do_not_send_email
          pricing_info = {
            base_price: payment.amount
            price_options: 0
            total_price: payment.amount
            minimum_payment: payment.amount
            price_todays_payment: payment.amount
            price_shipping: 0
            price_processing_fee: 0
            price_sales_tax: 0
            sales_tax_percentage: 0
            price_tags_licenses: 0
            months_count: 0
          }
          payload.cart.pricing_info = pricing_info
          original_listing_type = originalPurchase.huntCatalog_type if originalPurchase?.huntCatalog_type
          original_listing_type = purchase.huntCatalogCopy[0].type if purchase.huntCatalogCopy[0].type
          if purchase.invoiceNumber.indexOf('RBIOSS') > -1
            original_listing_type = "oss"

          type_suffix = "payment"
          type_suffix = "renewal" if purchase.isSubscription

          if original_listing_type
            listing_type = "#{type_suffix}_#{original_listing_type}"
          else
            listing_type = "#{type_suffix}"

          if purchase.isSubscription
            title = "#{originalPurchase.huntCatalog_title} Renewal"
          else
            title = "Payment for Invoice #: #{originalPurchase.invoiceNumber}, #{originalPurchase.huntCatalog_title}"

          listing = {
            class_name: listing_type
            type: listing_type
            catalog_id: "PMT"
            title: title
            status: "available"
            run_special: false
            price_total: payment.amount
            price_non_commissionable: 0
            price_member: payment.amount
            price_non_member: payment.amount
            price_processing_fee: 0
            commission_rbo: 0
            commission_rep: 0
            price_description: ""
            description: "Payment for Original Purchase Invoice #: #{originalPurchase.invoiceNumber}, #{originalPurchase.huntCatalog_title}"
            created_at: new Date()
            updated_at: new Date()
          }
          listing.outfitter = {
            mongo_id: originalPurchase.huntCatalog_outfitter_id #Just assign it to the original invoice outfitter
          }
          payload.cart.listing = listing
          cartEntry = {
            'price_todays_payment': payment.amount
            'price_total': payment.amount,
            'price_processing_fee': 0
            'price_shipping': 0
            'price_tags_licenses': 0
            'price_options': 0
            'price_sales_tax': 0
            notes: payment.notes
            shopping_cart_entry_options: []
            quantity: 1
            pricing_info_hash: pricing_info
            listing: listing
          }
          cartEntry.notes = "" unless cartEntry.notes
          if !purchase.isSubscription
            additionalNote = "This is a payment for the invoice of total price: $#{originalPurchase.amountTotal}, total payments to date: $#{(originalPurchase.amountPaid + payment.amount).toFixed(2)}, amount owed: $#{(originalPurchase.amountTotal - originalPurchase.amountPaid - payment.amount).toFixed(2)}"
            if cartEntry?.notes?.length
              cartEntry.notes = "#{additionalNote}.    #{cartEntry.notes}"
            else
              cartEntry.notes = additionalNote

          payload.cart.shopping_cart_entries.push cartEntry
          payload.user = {
            email: user.email
            phone_number: ""
            _id: user._id
            clientId: user.clientId
          }

          payload.cart.auto_payment = payment.auto_payment if payment.auto_payment

          api_rbo.purchase_create3_direct payload, (err, results) =>
            return next err, purchase

        #add payment, and amountPaid and update the original purchase object
        (purchase, next) ->
          return next "Missing payment createdAt " unless payment.createdAt
          return next "Missing payment specific_type " unless payment.specific_type
          return next "Missing payment name " unless payment.name
          return next "Missing payment amount " unless payment.amount
          return next "Missing payment paidOn " unless payment.paidOn
          return next "Missing payment referenceNumber " if payment.specific_type is "check" and !payment.referenceNumber
          purchase.payments = [] unless purchase.payments?.length
          purchase.payments.push payment

          #If the purchase is on a payment plan
          if !purchase.isSubscription
            purchase.amountPaid = purchase.amountPaid + payment.amount
            #TODO:  Get TOTAL_PRICE to be saved as a field in the db Purchase object, set on create or purchase edit.  This is being calculated all over in different places and probably not consistently.
            options_total = 0
            for option in purchase.options
              options_total += option.price
            TOTAL_PRICE = purchase.basePrice
            TOTAL_PRICE += options_total
            TOTAL_PRICE += purchase.tags_licenses if purchase.tags_licenses
            TOTAL_PRICE += purchase.shipping if purchase.shipping
            TOTAL_PRICE += purchase.fee_processing if purchase.fee_processing
            TOTAL_PRICE += purchase.sales_tax if purchase.sales_tax

            #check if paid in full
            if parseFloat(purchase.amountPaid.toFixed(2)) >= parseFloat(TOTAL_PRICE.toFixed(2))
              purchase.status = 'paid-in-full'
              purchase.next_payment_date = null
              purchase.next_payment_amount = null
            else if purchase.next_payment_date?
              #check if it's an auto payment we need to calc the next payment date
              payment_date = moment(purchase.next_payment_date)
              if purchase.status is 'auto-pay-monthly' or purchase.status is 'auto-pay-monthly-retry'
                if purchase.status is 'auto-pay-monthly-retry'
                  newPaymentDate = payment_date.add(2,'months')
                else
                  newPaymentDate = payment_date.add(1,'months')
                newPaymentDate = newPaymentDate.date(payment_date.date())
                purchase.next_payment_date = newPaymentDate.format('YYYY-MM-DD')
                purchase.status = 'auto-pay-monthly'
              if purchase.status is 'auto-pay-yearly' or purchase.status is 'auto-pay-yearly-retry'
                newPaymentDate = payment_date.add(1,'years')
                newPaymentDate = newPaymentDate.date(payment_date.date())
                purchase.next_payment_date = newPaymentDate.format('YYYY-MM-DD')
                purchase.status = 'auto-pay-yearly'

            if ( (purchase.amountPaid + purchase.next_payment_amount) > TOTAL_PRICE )
              purchase.next_payment_amount = (TOTAL_PRICE - purchase.amountPaid).toFixed(2)

          #Purhcase is a subscription, and has a next payment date
          else if purchase.isSubscription is true and purchase.next_payment_date?
            payment_date = moment(purchase.next_payment_date)
            if purchase.status is 'auto-pay-monthly' or purchase.status is 'auto-pay-monthly-retry'
              if purchase.status is 'auto-pay-monthly-retry'
                newPaymentDate = payment_date.add(2,'months')
              else
                newPaymentDate = payment_date.add(1,'months')

              newPaymentDate = newPaymentDate.date(payment_date.date())
              purchase.next_payment_date = "#{newPaymentDate.format('YYYY-MM-DD')}T06:00:00.000Z"
              purchase.status = 'auto-pay-monthly'
            if purchase.status is 'auto-pay-yearly' or purchase.status is 'auto-pay-yearly-retry'
              purchase.next_payment_date = payment_date.add(1,'years').format('YYYY-MM-DD')
              purchase.status = 'auto-pay-yearly'

          delete purchase.__v
          Purchase.upsert purchase, {}, (err, purchase) ->
            return next err, purchase

      ], (err, purchase) ->
        if cb
          return cb err if err
          return cb null, {status: "success", purchase: purchase}
        else
          return res.json err, 500 if err
          return res.json {status: "success"}


    adminPaypal: (req, res) ->
      return res.json {error: 'Unauthorized'}, 400 unless req?.user?.isAdmin
      purchaseIds = req.body.purchaseIds
      endDate = req.body.endDate

      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'list of purchases required'}, 400 unless purchaseIds
      return res.json {error: 'endDate required'}, 400 unless endDate

      endDate = new Date(endDate)
      endDate = moment(endDate)
      endDateStr = endDate.format("MM/DD/YYYY")

      Purchase.byIdsTenant purchaseIds, req.tenant._id, (err, purchases) =>
        return res.json err, 500 if err
        return res.json "No purchases found", 500 unless purchases?.length

        User.findByTenant req.tenant._id, {internal: false}, (err, users) =>
          return res.json err, 500 if err
          userIndex = {}
          for user in users
            userIndex[user._id.toString()] = user

          getUser = (userId) ->
            return null unless userId
            foundUser = userIndex[userId.toString()]
            if foundUser
              return foundUser
            else
              console.log "adminPaypal error, user not found for userId: ", userId
              return {
                email: "rollingbonesoutfitters_unknown"
                clientId: "rbo_unknown"
                name: "USER NOT FOUND"
              }

          userCommissions = {}
          total_rep_commissions = 0
          total_overrides = 0
          for purchase in purchases
            purchase.rbo_rep0 = "Missing AAA" unless purchase.rbo_rep0
            purchase.rbo_rep1 = "Missing AA" unless purchase.rbo_rep1
            purchase.rbo_rep2 = "Missing SAA" unless purchase.rbo_rep2
            purchase.rbo_rep3 = "Missing RAA" unless purchase.rbo_rep3
            purchase.rbo_rep4 = "Missing AM" unless purchase.rbo_rep4
            purchase.rbo_rep5 = "Missing SAM" unless purchase.rbo_rep5
            purchase.rbo_rep6 = "Missing EAM" unless purchase.rbo_rep6
            purchase.rbo_rep7 = "Missing SEAM" unless purchase.rbo_rep7
            purchase.rbo_repOSSP = "Missing OSSP" unless purchase.rbo_repOSSP
            purchase.rbo_rbo1 = "Missing BM" unless purchase.rbo_rbo1
            purchase.rbo_rbo2 = "Missing BD" unless purchase.rbo_rbo2
            purchase.rbo_rbo3 = "Missing NE" unless purchase.rbo_rbo3
            purchase.rbo_rbo4 = "Missing RBO" unless purchase.rbo_rbo4

            total_rep_commissions += purchase.rbo_commission_rep0 if !isNaN(purchase.rbo_commission_rep0)
            total_rep_commissions += purchase.rbo_commission_rep1 if !isNaN(purchase.rbo_commission_rep1)
            total_rep_commissions += purchase.rbo_commission_rep2 if !isNaN(purchase.rbo_commission_rep2)
            total_rep_commissions += purchase.rbo_commission_rep3 if !isNaN(purchase.rbo_commission_rep3)
            total_rep_commissions += purchase.rbo_commission_rep4 if !isNaN(purchase.rbo_commission_rep4)
            total_rep_commissions += purchase.rbo_commission_rep5 if !isNaN(purchase.rbo_commission_rep5)
            total_rep_commissions += purchase.rbo_commission_rep6 if !isNaN(purchase.rbo_commission_rep6)
            total_rep_commissions += purchase.rbo_commission_rep7 if !isNaN(purchase.rbo_commission_rep7)
            total_rep_commissions += purchase.rbo_commission_repOSSP if !isNaN(purchase.rbo_commission_repOSSP)
            total_overrides += purchase.rbo_commission_rbo1 if !isNaN(purchase.rbo_commission_rbo1)
            total_overrides += purchase.rbo_commission_rbo2 if !isNaN(purchase.rbo_commission_rbo2)
            total_overrides += purchase.rbo_commission_rbo3 if !isNaN(purchase.rbo_commission_rbo3)
            total_overrides += purchase.rbo_commission_rbo4 if !isNaN(purchase.rbo_commission_rbo4)

            emptyTotals = {
              r0Total: 0
              r1Total: 0
              r2Total: 0
              r3Total: 0
              r4Total: 0
              r5Total: 0
              r6Total: 0
              r7Total: 0
              rOSSPTotal: 0
              brian: 0
              brad: 0
              noel: 0
              rboMain: 0
            }

            if !userCommissions[purchase.rbo_rep0]
              user = getUser purchase.rbo_rep0
              userCommissions[purchase.rbo_rep0] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep0].email = user.email if user?.email
              userCommissions[purchase.rbo_rep0].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep0].name = user.name if user?.name
            userCommissions[purchase.rbo_rep0].r0Total += purchase.rbo_commission_rep0 if purchase.rbo_commission_rep0

            if !userCommissions[purchase.rbo_rep1]
              user = getUser purchase.rbo_rep1
              userCommissions[purchase.rbo_rep1] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep1].email = user.email if user?.email
              userCommissions[purchase.rbo_rep1].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep1].name = user.name if user?.name
            userCommissions[purchase.rbo_rep1].r1Total += purchase.rbo_commission_rep1 if purchase.rbo_commission_rep1

            if !userCommissions[purchase.rbo_rep2]
              user = getUser purchase.rbo_rep2
              userCommissions[purchase.rbo_rep2] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep2].email = user.email if user?.email
              userCommissions[purchase.rbo_rep2].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep2].name = user.name if user?.name
            userCommissions[purchase.rbo_rep2].r2Total += purchase.rbo_commission_rep2 if purchase.rbo_commission_rep2

            if !userCommissions[purchase.rbo_rep3]
              user = getUser purchase.rbo_rep3
              userCommissions[purchase.rbo_rep3] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep3].email = user.email if user?.email
              userCommissions[purchase.rbo_rep3].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep3].name = user.name if user?.name
            userCommissions[purchase.rbo_rep3].r3Total += purchase.rbo_commission_rep3 if purchase.rbo_commission_rep3

            if !userCommissions[purchase.rbo_rep4]
              user = getUser purchase.rbo_rep4
              userCommissions[purchase.rbo_rep4] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep4].email = user.email if user?.email
              userCommissions[purchase.rbo_rep4].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep4].name = user.name if user?.name
            userCommissions[purchase.rbo_rep4].r4Total += purchase.rbo_commission_rep4 if purchase.rbo_commission_rep4

            if !userCommissions[purchase.rbo_rep5]
              user = getUser purchase.rbo_rep5
              userCommissions[purchase.rbo_rep5] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep5].email = user.email if user?.email
              userCommissions[purchase.rbo_rep5].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep5].name = user.name if user?.name
            userCommissions[purchase.rbo_rep5].r5Total += purchase.rbo_commission_rep5 if purchase.rbo_commission_rep5

            if !userCommissions[purchase.rbo_rep6]
              user = getUser purchase.rbo_rep6
              userCommissions[purchase.rbo_rep6] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep6].email = user.email if user?.email
              userCommissions[purchase.rbo_rep6].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep6].name = user.name if user?.name
            userCommissions[purchase.rbo_rep6].r6Total += purchase.rbo_commission_rep6 if purchase.rbo_commission_rep6

            if !userCommissions[purchase.rbo_rep7]
              user = getUser purchase.rbo_rep7
              userCommissions[purchase.rbo_rep7] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rep7].email = user.email if user?.email
              userCommissions[purchase.rbo_rep7].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rep7].name = user.name if user?.name
            userCommissions[purchase.rbo_rep7].r7Total += purchase.rbo_commission_rep7 if purchase.rbo_commission_rep7

            if !userCommissions[purchase.rbo_repOSSP]
              user = getUser purchase.rbo_repOSSP
              userCommissions[purchase.rbo_repOSSP] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_repOSSP].email = user.email if user?.email
              userCommissions[purchase.rbo_repOSSP].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_repOSSP].name = user.name if user?.name
            userCommissions[purchase.rbo_repOSSP].rOSSPTotal += purchase.rbo_commission_repOSSP if purchase.rbo_commission_repOSSP

            #Brian
            if !userCommissions[purchase.rbo_rbo1]
              user = getUser purchase.rbo_rbo1
              userCommissions[purchase.rbo_rbo1] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rbo1].email = user.email if user?.email
              userCommissions[purchase.rbo_rbo1].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rbo1].name = user.name if user?.name
            userCommissions[purchase.rbo_rbo1].brian += purchase.rbo_commission_rbo1 if purchase.rbo_commission_rbo1

            #Brad
            if !userCommissions[purchase.rbo_rbo2]
              user = getUser purchase.rbo_rbo2
              userCommissions[purchase.rbo_rbo2] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rbo2].email = user.email if user?.email
              userCommissions[purchase.rbo_rbo2].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rbo2].name = user.name if user?.name
            userCommissions[purchase.rbo_rbo2].brad += purchase.rbo_commission_rbo2 if purchase.rbo_commission_rbo2

            #Noel
            if !userCommissions[purchase.rbo_rbo3]
              user = getUser purchase.rbo_rbo3
              userCommissions[purchase.rbo_rbo3] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rbo3].email = user.email if user?.email
              userCommissions[purchase.rbo_rbo3].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rbo3].name = user.name if user?.name
            userCommissions[purchase.rbo_rbo3].noel += purchase.rbo_commission_rbo3 if purchase.rbo_commission_rbo3

            #RBO
            if !userCommissions[purchase.rbo_rbo4]
              user = getUser purchase.rbo_rbo4
              userCommissions[purchase.rbo_rbo4] = _.clone(emptyTotals)
              userCommissions[purchase.rbo_rbo4].email = user.email if user?.email
              userCommissions[purchase.rbo_rbo4].clientId = user.clientId if user?.clientId
              userCommissions[purchase.rbo_rbo4].name = user.name if user?.name
            userCommissions[purchase.rbo_rbo4].rboMain += purchase.rbo_commission_rbo4 if purchase.rbo_commission_rbo4


          #Now Build the Paypal File:
          #rvpneils@gmail.com,540.9,USD,RB8,Brandon Neil This is your agency manager commission payment current  up to 03/01/2018
          #GWB ACH Import file format:
          #1592.67,RB8,brandon@rbohome.com,Brandon Neil Total commissions paid through 7/31/2020
          paypal = []
          gwb_ach = []
          total = 0
          repTotal = 0
          for key, value of userCommissions
            repTotal += value.r0Total + value.r1Total + value.r2Total + value.r3Total + value.r4Total + value.r5Total + value.r6Total + value.r7Total + value.rOSSPTotal + value.brian + value.brad + value.noel + value.rboMain
            total += repTotal
            value.r0 = parseFloat(value.r0Total).toFixed(2)
            value.r1 = parseFloat(value.r1Total).toFixed(2)
            value.r2 = parseFloat(value.r2Total).toFixed(2)
            value.r3 = parseFloat(value.r3Total).toFixed(2)
            value.r4 = parseFloat(value.r4Total).toFixed(2)
            value.r5 = parseFloat(value.r5Total).toFixed(2)
            value.r6 = parseFloat(value.r6Total).toFixed(2)
            value.r7 = parseFloat(value.r7Total).toFixed(2)
            value.rOSSP = parseFloat(value.rOSSPTotal).toFixed(2)
            value.brian = parseFloat(value.brian).toFixed(2)
            value.brad = parseFloat(value.brad).toFixed(2)
            value.noel = parseFloat(value.noel).toFixed(2)
            value.rboMain = parseFloat(value.rboMain).toFixed(2)
            totalOnly = true #Used for ACH and 1099 report and other reports as needed.
            if totalOnly
              gwb_ach.push "#{parseFloat(repTotal).toFixed(2)},#{value.name},#{value.clientId},#{value.email},#{value.name} total commissions paid through #{endDateStr}" if parseFloat(repTotal) > 0
              paypal.push "#{value.email},#{parseFloat(repTotal).toFixed(2)},#{value.name},#{value.clientId},#{value.name} This is the total commissions paid from #{''} to #{endDateStr}" if parseFloat(repTotal) > 0
            else
              #PAYPAL UPLOAD FILE FORMAT
              paypal.push "#{value.email},#{value.r0Total},USD,#{value.clientId},#{value.name} This is your Associate Adventure Advisor commission payment current up to #{endDateStr}" if parseFloat(value.r0Total) > 0
              paypal.push "#{value.email},#{value.r1Total},USD,#{value.clientId},#{value.name} This is your Adventure Advisor commission payment current up to #{endDateStr}" if parseFloat(value.r1Total) > 0
              paypal.push "#{value.email},#{value.r2Total},USD,#{value.clientId},#{value.name} This is your Senior Adventure Advisor commission payment current up to #{endDateStr}" if parseFloat(value.r2Total) > 0
              paypal.push "#{value.email},#{value.r3Total},USD,#{value.clientId},#{value.name} This is your Regional Adventure Advisor commission payment current up to #{endDateStr}" if parseFloat(value.r3Total) > 0
              paypal.push "#{value.email},#{value.r4Total},USD,#{value.clientId},#{value.name} This is your Agency Manager commission payment current up to #{endDateStr}" if parseFloat(value.r4Total) > 0
              paypal.push "#{value.email},#{value.r5Total},USD,#{value.clientId},#{value.name} This is your Senior Agency Manager commission payment current up to #{endDateStr}" if parseFloat(value.r5Total) > 0
              paypal.push "#{value.email},#{value.r6Total},USD,#{value.clientId},#{value.name} This is your Executive Agency Manager payment current up to #{endDateStr}" if parseFloat(value.r6Total) > 0
              paypal.push "#{value.email},#{value.r7Total},USD,#{value.clientId},#{value.name} This is your Senior Executive Agency Manager commission payment current up to #{endDateStr}" if parseFloat(value.r7Total) > 0
              paypal.push "#{value.email},#{value.rOSSPTotal},USD,#{value.clientId},#{value.name} This is your Outdoor Software Solutions Partner commission payment current up to #{endDateStr}" if parseFloat(value.rOSSPTotal) > 0
              paypal.push "#{value.email},#{value.brian},USD,#{value.clientId},#{value.name} This is your override % payment current up to #{endDateStr}" if parseFloat(value.brian) > 0
              paypal.push "#{value.email},#{value.brad},USD,#{value.clientId},#{value.name} This is your override % payment current up to #{endDateStr}" if parseFloat(value.brad) > 0
              paypal.push "#{value.email},#{value.noel},USD,#{value.clientId},#{value.name} This is your override % payment current up to #{endDateStr}" if parseFloat(value.noel) > 0
              paypal.push "#{value.email},#{value.rboMain},USD,#{value.clientId},#{value.name} This is your RBO Split % or Bonus payment current up to #{endDateStr}" if parseFloat(value.rboMain) > 0
            repTotal = 0
          paypal.push "TOTAL: #{total.toFixed(2)}"
          gwb_ach.push "TOTAL: #{total.toFixed(2)}"
          USE_GWB_ACH = true
          if USE_GWB_ACH
            res.json gwb_ach
          else
            res.json paypal

    sanitizeUserFields: (user) ->
      tUser = {
        _id: user._id
        clientId: user.clientId
        name: user.name
        email: user.email
      }
      return tUser


    fileAdd: (req, res) ->
      try
        token = req.param('token')
        return res.json "Unauthorized", 500 unless token is APITOKEN
        purchaseId = req.param('id')
        console.log "fileAdd req.files", req.files

#        userId = req.param('id')
#
#        User.byId userId, (err, user) ->
#          return res.json err, 500 if err
#          return res.json {error: "user doesn't exist for id: #{userId}"}, 500 if err
#          user.files = [] unless user.files?.length
#
#          if req.files?.uploadedFiles?.length
#            for file in req.files.uploadedFiles
#              ext = ""
#              extArray = file.path.split(".")
#              ext = extArray[extArray.length-1] if extArray.length > 0
#              user.files.push {
#                originalName: file.originalname
#                extension: ".#{ext}"
#                mimetype: file.mimetype
#                url: file.path
#                size: file.size
#                encoding: file.encoding
#              }
#
#            User.upsert user, (err, user) ->
#              return res.json err, 500 if err
#              return res.json user
#          else
#            return res.json {msg: "No files found to upload"}
        return res.json {"DEBUG": "SUCCESS"}

      catch ex
        console.log "fileAdd catch error:", ex
        return res.json {error: "An error occurred trying to update file for purchase: #{purchaseId}"}, 500 if err


    fileRemove: (req, res) ->
      try
        token = req.param('token')
        return res.json "Unauthorized", 500 unless token is APITOKEN

        purchaseId = req.param('id')
        newFileList = []

        console.log "fileRemove req.body.fileNames", req.body?.fileNames

        removeFilename = req.body.fileNames
        return res.json {"DEBUG": "SUCCESS"}


#        User.byId userId, (err, user) ->
#          return res.json err, 500 if err
#          return res.json {error: "user doesn't exist for id: #{userId}"}, 500 if err
#          user.files = [] unless user.files?.length
#
#          for file in user.files
#            newFileList.push file unless file.originalName is removeFilename
#
#          user.files = newFileList
#
#          User.upsert user, (err, user) ->
#            return res.json err, 500 if err
#            return res.json user

    sendConfirmations: (req, res) ->
      purchase = req.body.purchase
      huntCatalog = req.body.huntCatalog
      sendType = req.body.sendType

      return res.json {error: "Missing purchase"}, 401 unless purchase?._id
      return res.json {error: "Missing email for outfitter: #{huntCatalog.outfitter_name}"}, 401 unless huntCatalog?.outfitter?.email
      return res.json {error: "Missing email for user: #{purchase.user._id}"}, 401 unless purchase?.user?.email

      formatMoneyStr = (number) ->
        number = number.toFixed(2) if number
        return number unless number?.toString()
        numberAsMoneyStr = number.toString()
        mpStrArry = numberAsMoneyStr.split(".")
        if mpStrArry?.length > 0 and mpStrArry[1]?.length == 1
          numberAsMoneyStr = "#{number}0"
        else
          numberAsMoneyStr = "$#{number}"
        return numberAsMoneyStr

      total_price = formatMoneyStr(purchase.TOTAL_PRICE)
      totalToOutfitter = formatMoneyStr(purchase.totalToOutfitter)
      amount = formatMoneyStr(purchase.amount)
      commission = formatMoneyStr(purchase.commission)
      fee_processing = formatMoneyStr(purchase.fee_processing)
      remainingDepositToSend = formatMoneyStr(purchase.remainingDepositToSend)
      clientOwes = formatMoneyStr(purchase.clientOwes)

      #remove when name is duplicated
      outfitter_name = huntCatalog.outfitter_name
      outfitter_name_first_half = huntCatalog.outfitter_name.substr(0, huntCatalog.outfitter_name.length/2).trim()
      outfitter_name_second_half = huntCatalog.outfitter_name.substr(huntCatalog.outfitter_name.length/2, huntCatalog.outfitter_name.length).trim()
      if outfitter_name_first_half is outfitter_name_second_half
        outfitter_name = outfitter_name_first_half

      if purchase.user.mail_address
        user_address = purchase.user.mail_address
        user_city = purchase.user.mail_city
        user_state = purchase.user.mail_state
        user_postal = purchase.user.mail_postal
      else if purchase.user.physical_address
        user_address = purchase.user.physical_address
        user_city = purchase.user.physical_city
        user_state = purchase.user.physical_state
        user_postal = purchase.user.physical_postal
      else
        user_address = ""
        user_city = ""
        user_state = ""
        user_postal = ""

      huntCatalog.outfitter.business_email = "" unless huntCatalog.outfitter.business_email
      huntCatalog.outfitter.business_phone = "" unless huntCatalog.outfitter.business_phone

      merge_vars = {
        "huntCatalog_outfitter_name": outfitter_name
        "huntCatalog_outfitter_email": huntCatalog.outfitter.business_email
        "huntCatalog_outfitter_business_phone": huntCatalog.outfitter.business_phone
        "huntCatalog_outfitter_mail_address": huntCatalog.outfitter.mail_address
        "huntCatalog_outfitter_mail_city": huntCatalog.outfitter.mail_city
        "huntCatalog_outfitter_mail_state": huntCatalog.outfitter.mail_state
        "huntCatalog_outfitter_mail_postal": huntCatalog.outfitter.mail_postal
        "huntCatalog_title": huntCatalog.title
        "huntCatalog_huntNumber": huntCatalog.huntNumber
        "purchase_start_hunt_date": ""
        "purchase_end_hunt_date": ""
        "purchase_purchase_confirmed_by_outfitter": ""
        "purchase_user_first_name": purchase.user.first_name
        "purchase_user_last_name": purchase.user.last_name
        "purchase_user_clientId": purchase.user.clientId
        "purchase_user_email": purchase.user.email
        "purchase_user_phone_cell": purchase.user.phone_cell
        "purchase_user_mail_address": user_address
        "purchase_user_mail_city": user_city
        "purchase_user_mail_state": user_state
        "purchase_user_mail_postal": user_postal
        "purchase_TOTAL_PRICE": total_price
        "purchase_totalToOutfitter": totalToOutfitter
        "purchase_amount": amount
        "purchase_commission": commission
        "purchase_fee_processing": fee_processing
        "purchase_remainingDepositToSend": remainingDepositToSend
        "purchase_clientOwes": clientOwes
        "purchase_invoiceNumber": purchase.invoiceNumber
        "purchase_purchaseNotes": ""
        "purchase_adminNotes": ""
        "hasConfirmedHuntDates": false
        "hasProcessingFee": false
        "hasPurchaseNotes": false
      }
      "purchase_start_hunt_date": moment(purchase.start_hunt_date).format("L")
      "purchase_end_hunt_date": moment(purchase.end_hunt_date).format("L")
      "purchase_purchase_confirmed_by_outfitter": purchase.purchase_confirmed_by_outfitter

      if purchase.purchaseNotes
        merge_vars.hasPurchaseNotes = true
        merge_vars.purchase_purchaseNotes = purchase.purchaseNotes
      merge_vars.purchase_adminNotes = purchase.adminNotes if purchase.adminNotes
      merge_vars.purchase_start_hunt_date = moment(purchase.start_hunt_date).format("L") if purchase.start_hunt_date
      merge_vars.purchase_end_hunt_date = moment(purchase.end_hunt_date).format("L") if purchase.end_hunt_date
      merge_vars.purchase_purchase_confirmed_by_outfitter = purchase.purchase_confirmed_by_outfitter if purchase.purchase_confirmed_by_outfitter

      merge_vars.hasConfirmedHuntDates = true if purchase.start_hunt_date and purchase.end_hunt_date and purchase.purchase_confirmed_by_outfitter
      merge_vars.hasProcessingFee = true if purchase.fee_processing? and purchase.fee_processing > 0

      useTestValues = false
      hardCodedEmailTest = "scott@rollingbonesoutfitters.com"
      hardCodedEmailName = "Scott Wallace"

      async.waterfall [

        #Email confirmation letter to the outfitter, copy info@rbo, and bcc the user who hit the send button
        (next) ->
          return next null, null unless sendType is "both" or sendType is "outfitter"
          subject = "Hunt Confirmation"
          to_users = []
          to_user = {
            email: huntCatalog.outfitter.email
            name: huntCatalog.outfitter_name
            type: "to"
          }
          to_user.email = hardCodedEmailTest if useTestValues
          to_user.name = hardCodedEmailName if useTestValues
          to_users.push to_user

          to_user = {
            email: "info@rollingbonesoutfitters.com"
            name: "RBO Concierge Services"
            type: "cc"
          }
          to_users.push to_user

          if req?.user?.email and req?.user?.name?.length
            to_user = {
              email: req.user.email
              name: req.user.name
              type: "bcc"
            }
            to_users.push to_user

          to_user = {
            email: "scott@rollingbonesoutfitters.com"
            name: "Scott Wallace"
            type: "bcc"
          }
          to_users.push to_user

          template_name = "Outfitter Confirmation Letter"
          mailchimpapi.sendEmail null, template_name, subject, to_users, merge_vars, null, null, false, true, (err, results) ->
            return next err, results

        #Email confirmation letter to Accounting
        (results, next) ->
          return next null, null unless sendType is "both" or sendType is "outfitter"
          to_users = []
          subject = "Hunt Confirmation RBO Accounting"
          #to_user = {
          #  email: "Ali@KTLLP.com"
          #  name: "Ali Eddy"
          #}
          if false
            to_user = {
              type: "to"
            }
            to_user.email = hardCodedEmailTest if useTestValues
            to_user.name = hardCodedEmailName if useTestValues
            to_users.push to_user
          else
            to_user = {
              email: "scott@rbohome.com"
              name: "Scott Wallace"
              type: "to"
            }
            to_users.push to_user
            to_user = {
              email: "brian@rbohome.com"
              name: "Brian Mehmen"
              type: "to"
            }
            to_users.push to_user
            to_user = {
              email: "lynley@rbohome.com"
              name: "Lynley Mehmen"
              type: "to"
            }
            to_users.push to_user

          template_name = "Outfitter Confirmation Letter Accounting"
          mailchimpapi.sendEmail null, template_name, subject, to_users, merge_vars, null, null, false, true, (err, results) ->
            return next err, results

        #Email confirmation letter to the client, copy info@rbo, and bcc the user who hit the send button
        (results, next) ->
          return next null, null unless sendType is "both" or sendType is "client"
          to_users = []
          subject = "Hunt Confirmation"
          to_user = {
            email: purchase.user.email
            name: purchase.user.name
          }
          to_user.email = hardCodedEmailTest if useTestValues
          to_user.name = hardCodedEmailName if useTestValues
          to_users.push to_user

          to_user = {
            email: "info@rollingbonesoutfitters.com"
            name: "RBO Concierge Services"
            type: "cc"
          }
          to_users.push to_user

          if req?.user?.email and req?.user?.name?.length
            to_user = {
              email: req.user.email
              name: req.user.name
              type: "bcc"
            }
            to_users.push to_user

          to_user = {
            email: "scott@rollingbonesoutfitters.com"
            name: "Scott Wallace"
            type: "bcc"
          }
          to_users.push to_user

          template_name = "Outfitter Confirmation Letter Client"
          mailchimpapi.sendEmail null, template_name, subject, to_users, merge_vars, null, null, false, true, (err, results) ->
            return next err, results


      ], (err, results) ->
        return res.json {error: err}, 500 if err
        now = new Date()
        purchaseData = {
          _id: purchase._id
        }
        purchaseData.confirmation_sent_outfitter = now if sendType is "both" or sendType is "outfitter"
        purchaseData.confirmation_sent_client = now if sendType is "both" or sendType is "client"
        Purchase.upsert purchaseData, {upsert: false}, (err, purchase) ->
          return res.json {error: err, errorMsg: "Successfully sent emails but failed to update purchase data confirmation dates"}, 500 if err
          return res.json purchase



  }
  _.bindAll.apply _, [Purchases].concat(_.functions(Purchases))
  return Purchases
