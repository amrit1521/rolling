APP = window.APP
APP.Controllers.controller('PurchaseEdit', ['$scope', '$rootScope', '$routeParams', '$sce', '$modal', 'Storage', 'User', 'Purchase', 'KendoFiles', ($scope, $rootScope, $routeParams, $sce, $modal, Storage, User, Purchase, KendoFiles) ->

  $scope.init = ->
    $scope.tenantId = window.tenant._id
    $scope.tenantName = window.tenant.name
    $scope.isRBO = $scope.tenantId is "5684a2fc68e9aa863e7bf182" or $scope.tenantId is "5bd75eec2ee0370c43bc3ec7" or $scope.tenantId is "53a28a303f1e0cc459000127" #Toggle: GMT
    $scope.user = Storage.get 'user'
    $scope.full = $scope.checkUser('sadmin')
    $scope.tenantAdmin = $scope.checkUser('tadmin')
    $scope.purchase = null
    $scope.huntCatalog = null
    $scope.needInitUI = true
    $scope.outfitter_vendor_title = "Outfitter"

    $scope.payment_statuses = [
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


    $scope.loadPurchase($routeParams.id)

  $scope.loadPurchase = (purchaseId) ->
    setPurchase = (results) ->
      $scope.purchase = results
      $scope.initUI($scope.purchase) if $scope.needInitUI
      $scope.needInitUI = false
      $scope.purchase.fee_processing = 0 if !$scope.purchase.fee_processing

      #Calc Options
      $scope.purchase.options_rbo_commissions_total = 0 unless $scope.purchase.options_rbo_commissions_total? > 0
      $scope.purchase.options_total = 0
      if $scope.purchase.options?.length
        hasOptionAddOns = true
        inc = 0
        for option in $scope.purchase.options
          $scope.purchase.options_total += option.price
          $scope.purchase.options_rbo_commissions_total += option.commission if option.commission
          #option_desc = "#{option.title}: #{option.specific_type}"
          option_desc = "#{option.title}: $#{$scope.formatMoneyStr(option.price)} #{option.specific_type}"
          if inc is 0
            options_descriptions = "#{option_desc}"
          else
            options_descriptions = "#{options_descriptions}, \r\n\r\n #{option_desc}"
          inc++
      $scope.purchase.options_totalToOutfitter = $scope.purchase.options_total - $scope.purchase.options_rbo_commissions_total
      $scope.purchase.options_descriptions = options_descriptions if options_descriptions

      #Calculate TOTAL PRICE
      $scope.purchase.TOTAL_PRICE = $scope.purchase.basePrice
      $scope.purchase.TOTAL_PRICE += $scope.purchase.options_total if $scope.purchase.options_total
      $scope.purchase.TOTAL_PRICE += $scope.purchase.tags_licenses if $scope.purchase.tags_licenses
      $scope.purchase.TOTAL_PRICE += $scope.purchase.shipping if $scope.purchase.shipping
      $scope.purchase.TOTAL_PRICE += $scope.purchase.fee_processing if $scope.purchase.fee_processing
      $scope.purchase.TOTAL_PRICE += $scope.purchase.sales_tax if $scope.purchase.sales_tax

      $scope.purchase.ccFee = 0
      if $scope.purchase.paymentUsed is "card"
        $scope.purchase.ccFee = $scope.purchase.amount * .03

      $scope.purchase.totalToOutfitter = $scope.purchase.basePrice
      $scope.purchase.totalToOutfitter += $scope.purchase.options_total if $scope.purchase.options_total
      $scope.purchase.totalToOutfitter += $scope.purchase.tags_licenses if $scope.purchase.tags_licenses
      $scope.purchase.totalToOutfitter += $scope.purchase.shipping if $scope.purchase.shipping
      $scope.purchase.totalToOutfitter -= $scope.purchase.commission if $scope.purchase.commission
      $scope.purchase.totalToOutfitter -= $scope.purchase.options_rbo_commissions_total if $scope.purchase.options_rbo_commissions_total

      $scope.purchase.remainingDepositToSend = $scope.purchase.amount
      $scope.purchase.remainingDepositToSend -= $scope.purchase.commission if $scope.purchase.commission
      $scope.purchase.remainingDepositToSend -= $scope.purchase.fee_processing if $scope.purchase.fee_processing
      $scope.purchase.remainingDepositToSend -= $scope.purchase.sales_tax if $scope.purchase.sales_tax
      $scope.purchase.remainingDepositToSend -= $scope.purchase.options_rbo_commissions_total if $scope.purchase.options_rbo_commissions_total

      $scope.purchase.clientOwes = $scope.purchase.TOTAL_PRICE - $scope.purchase.amountPaid

      $scope.purchase.percentPaid =  (($scope.purchase.amountPaid / $scope.purchase.TOTAL_PRICE)*100).toFixed(2)
      $scope.purchase.percentActualComm =  (($scope.purchase.commission / $scope.purchase.basePrice)*100).toFixed(2)

      if !$scope.purchase.rbo_reps_commission
        $scope.purchase.rbo_reps_commission = 0
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep0 if $scope.purchase.rbo_commission_rep0
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep1 if $scope.purchase.rbo_commission_rep1
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep2 if $scope.purchase.rbo_commission_rep2
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep3 if $scope.purchase.rbo_commission_rep3
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep4 if $scope.purchase.rbo_commission_rep4
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep5 if $scope.purchase.rbo_commission_rep5
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep6 if $scope.purchase.rbo_commission_rep6
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_rep7 if $scope.purchase.rbo_commission_rep7
        $scope.purchase.rbo_reps_commission += $scope.purchase.rbo_commission_repOSSP if $scope.purchase.rbo_commission_repOSSP
      $scope.addRepTotal(null, $scope.purchase)
      $scope.purchase.commissionsPaid = new Date($scope.purchase.commissionsPaid) if $scope.purchase.commissionsPaid

      $scope.purchase.qb_expense_payment_paid_date = new Date($scope.purchase.qb_expense_payment_paid_date) if $scope.purchase.qb_expense_payment_paid_date
      $scope.purchase.purchase_confirmed_by_client = new Date($scope.purchase.purchase_confirmed_by_client) if $scope.purchase.purchase_confirmed_by_client
      $scope.purchase.end_hunt_date = new Date($scope.purchase.end_hunt_date) if $scope.purchase.end_hunt_date
      $scope.purchase.start_hunt_date = new Date($scope.purchase.start_hunt_date) if $scope.purchase.start_hunt_date
      $scope.purchase.confirmation_sent_client = new Date($scope.purchase.confirmation_sent_client) if $scope.purchase.confirmation_sent_client
      $scope.purchase.purchase_confirmed_by_outfitter = new Date($scope.purchase.purchase_confirmed_by_outfitter) if $scope.purchase.purchase_confirmed_by_outfitter
      $scope.purchase.confirmation_sent_outfitter = new Date($scope.purchase.confirmation_sent_outfitter) if $scope.purchase.confirmation_sent_outfitter
      $scope.purchase.next_payment_date = new Date($scope.purchase.next_payment_date) if $scope.purchase.next_payment_date
      $scope.purchase.purchase_cancelled = new Date($scope.purchase.purchase_cancelled) if $scope.purchase.purchase_cancelled

      if $scope.purchase?.huntCatalogCopy?[0]
        $scope.huntCatalog = $scope.purchase.huntCatalogCopy[0] if $scope.purchase?.huntCatalogCopy?.length
        if $scope.huntCatalog.type != "hunt" and $scope.huntCatalog.type != "course"
          $scope.outfitter_vendor_title = "Vendor"
        $scope.huntCatalog.startDate = new Date($scope.huntCatalog.startDate) if $scope.huntCatalog.startDate
        $scope.huntCatalog.endDate = new Date($scope.huntCatalog.endDate) if $scope.huntCatalog.endDate
        if $scope.huntCatalog.pricingNotes
          $scope.huntCatalog.pricingNotesAsHTML = $scope.huntCatalog.pricingNotes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.huntCatalog.pricingNotesAsHTML = $sce.trustAsHtml($scope.huntCatalog.pricingNotesAsHTML);
        if $scope.purchase.purchaseNotes
          $scope.purchase.purchaseNotesAsHTML = $scope.purchase.purchaseNotes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.purchase.purchaseNotesAsHTML = $sce.trustAsHtml($scope.purchase.purchaseNotesAsHTML);

        User.get {id: $scope.purchase.userId}, (results) ->
          $scope.purchase.user = results
          $scope.refreshUserFromRRADS($scope.purchase.user)
          if $scope.purchase.user.parentId
            User.get {id: $scope.purchase.user.parentId}, (currentUserParent) ->
              $scope.purchase.user.parent = currentUserParent
        , (err) ->
          console.log "Error retrieving hunt catalog user: ", err

        User.get {id: $scope.huntCatalog.outfitter_userId}, (results) ->
          $scope.huntCatalog.outfitter = results
          #remove when name is duplicated
          outfitter_name_first_half = $scope.huntCatalog.outfitter_name.substr(0, $scope.huntCatalog.outfitter_name.length/2).trim()
          outfitter_name_second_half = $scope.huntCatalog.outfitter_name.substr($scope.huntCatalog.outfitter_name.length/2, $scope.huntCatalog.outfitter_name.length).trim()
          if outfitter_name_first_half is outfitter_name_second_half
            $scope.huntCatalog.outfitter_name = outfitter_name_first_half
        , (err) ->
          console.log "Error retrieving hunt catalog outfitter: ", err

        if $scope.purchase.userParentId
          User.get {id: $scope.purchase.userParentId}, (parent) ->
            $scope.purchase.userParent = parent
          , (err) ->
            console.log "Error retrieving user parent: ", err


        if $scope.isRBO
          $scope.addRepTotal(null, $scope.purchase)

          if $scope.purchase.rbo_rep0
            User.get {id: $scope.purchase.rbo_rep0}, (r0) ->
              $scope.rep0 = r0
            , (err) ->
              console.log "Error retrieving r0: ", err
          if $scope.purchase.rbo_rep1
            User.get {id: $scope.purchase.rbo_rep1}, (r1) ->
              $scope.rep1 = r1
            , (err) ->
              console.log "Error retrieving r1: ", err
          if $scope.purchase.rbo_rep2
            User.get {id: $scope.purchase.rbo_rep2}, (r2) ->
              $scope.rep2 = r2
            , (err) ->
              console.log "Error retrieving r2: ", err
          if $scope.purchase.rbo_rep3
            User.get {id: $scope.purchase.rbo_rep3}, (r3) ->
              $scope.rep3 = r3
            , (err) ->
              console.log "Error retrieving r3: ", err
          if $scope.purchase.rbo_rep4
            User.get {id: $scope.purchase.rbo_rep4}, (r4) ->
              $scope.rep4 = r4
            , (err) ->
              console.log "Error retrieving r4: ", err
          if $scope.purchase.rbo_rep5
            User.get {id: $scope.purchase.rbo_rep5}, (r5) ->
              $scope.rep5 = r5
            , (err) ->
              console.log "Error retrieving r5: ", err
          if $scope.purchase.rbo_rep6
            User.get {id: $scope.purchase.rbo_rep6}, (r6) ->
              $scope.rep6 = r6
            , (err) ->
              console.log "Error retrieving r6: ", err
          if $scope.purchase.rbo_rep7
            User.get {id: $scope.purchase.rbo_rep7}, (r7) ->
              $scope.rep7 = r7
            , (err) ->
              console.log "Error retrieving r7: ", err
          if $scope.purchase.rbo_repOSSP
            User.get {id: $scope.purchase.rbo_repOSSP}, (ossp) ->
              $scope.repOSSP = ossp
            , (err) ->
              console.log "Error retrieving ossp: ", err
          if $scope.purchase.rbo_rbo1
            User.get {id: $scope.purchase.rbo_rbo1}, (rbo1) ->
              $scope.rbo1 = rbo1
            , (err) ->
              console.log "Error retrieving rbo1: ", err
          if $scope.purchase.rbo_rbo2
            User.get {id: $scope.purchase.rbo_rbo2}, (rbo2) ->
              $scope.rbo2 = rbo2
            , (err) ->
              console.log "Error retrieving rbo2: ", err
          if $scope.purchase.rbo_rbo3
            User.get {id: $scope.purchase.rbo_rbo3}, (rbo3) ->
              $scope.rbo3 = rbo3
            , (err) ->
              console.log "Error retrieving rbo3: ", err
          if $scope.purchase.rbo_rbo4
            User.get {id: $scope.purchase.rbo_rbo4}, (rbo4) ->
              $scope.rbo4 = rbo4
            , (err) ->
              console.log "Error retrieving rbo4: ", err

        #console.log "$scope.purchase", $scope.purchase
      else
        console.log "results: ", results
        alert "Could not retrieve purchase."
        window.location = "#!/admin/reports/commissions"

    Purchase.read {id: purchaseId}, (results) ->
      setPurchase(results)
    , (err) ->
      errMsg = "Error retrieving purchase"
      errMsg = "#{errMsg}, #{err.data.error}" if err?.data?.error
      alert errMsg
      console.log "Error retrieving purchase:", err
      $scope.cancel()

  $scope.refreshUserFromRRADS = (tUser) ->
    User.user_refresh_from_rrads {clientId: tUser.clientId, tenantId: tUser.tenantId}, (results) ->
      noop = ""
    , (err) ->
      console.log "Error refreshUserFromRRADS:", err

  $scope.initUI = (purchase) ->
    purchaseId = purchase._id if purchase
    kFilesId = '#purchase_files'
    tk = "xxx"
    saveUrl = "admin/purchase/fileAdd/#{purchaseId}/#{tk}"
    removeUrl = "admin/purchase/fileRemove/#{purchaseId}/#{tk}"
    #kendoFiles = KendoFiles.init kFilesId, purchase.files, saveUrl, removeUrl, null, null

  $scope.cancel = ($event) ->
    $event.preventDefault() if $event
    if $scope.full
      window.location = "#!/admin/reports/commissions"
    else if $scope.user.isOutfitter
      window.location = "#!/admin/outfitters/purchases"
    else if $scope.user.isAdmin
      window.location = "#!/admin/reports/purchases"

  $scope.formatMoneyStr = (number) ->
    number = number.toFixed(2) if number
    return number unless number?.toString()
    numberAsMoneyStr = number.toString()
    mpStrArry = numberAsMoneyStr.split(".")
    if mpStrArry?.length > 0 and mpStrArry[1]?.length == 1
      numberAsMoneyStr = "#{number}0"
    else
      numberAsMoneyStr = "#{number}"
    return numberAsMoneyStr

  $scope.showReps = () ->
    if $scope.tenantId is "5684a2fc68e9aa863e7bf182" or $scope.tenantId is "5bd75eec2ee0370c43bc3ec7" #Toggle: GMT
      return true
    else
      return false

  $scope.numbersChanged = ($event, purchase) ->

    #Totals
    $scope.purchase.TOTAL_PRICE = $scope.purchase.basePrice
    $scope.purchase.TOTAL_PRICE += $scope.purchase.options_total if $scope.purchase.options_total
    $scope.purchase.TOTAL_PRICE += $scope.purchase.tags_licenses if $scope.purchase.tags_licenses
    $scope.purchase.TOTAL_PRICE += $scope.purchase.shipping if $scope.purchase.shipping
    $scope.purchase.TOTAL_PRICE += $scope.purchase.fee_processing if $scope.purchase.fee_processing
    $scope.purchase.TOTAL_PRICE += $scope.purchase.sales_tax if $scope.purchase.sales_tax

    $scope.purchase.totalToOutfitter = $scope.purchase.basePrice
    $scope.purchase.totalToOutfitter += $scope.purchase.options_total if $scope.purchase.options_total
    $scope.purchase.totalToOutfitter += $scope.purchase.tags_licenses if $scope.purchase.tags_licenses
    $scope.purchase.totalToOutfitter += $scope.purchase.shipping if $scope.purchase.shipping
    $scope.purchase.totalToOutfitter -= $scope.purchase.commission if $scope.purchase.commission
    $scope.purchase.totalToOutfitter -= $scope.purchase.options_rbo_commissions_total if $scope.purchase.options_rbo_commissions_total

    $scope.purchase.remainingDepositToSend = $scope.purchase.amount
    $scope.purchase.remainingDepositToSend -= $scope.purchase.commission if $scope.purchase.commission
    $scope.purchase.remainingDepositToSend -= $scope.purchase.fee_processing if $scope.purchase.fee_processing
    $scope.purchase.remainingDepositToSend -= $scope.purchase.sales_tax if $scope.purchase.sales_tax
    $scope.purchase.remainingDepositToSend -= $scope.purchase.options_rbo_commissions_total if $scope.purchase.options_rbo_commissions_total

    $scope.purchase.clientOwes = $scope.purchase.TOTAL_PRICE - $scope.purchase.amountPaid

    $scope.purchase.percentPaid =  (($scope.purchase.amountPaid / $scope.purchase.TOTAL_PRICE)*100).toFixed(2)
    $scope.purchase.percentActualComm =  (($scope.purchase.commission / $scope.purchase.basePrice)*100).toFixed(2)


  #Reset Rep totals
    $scope.addRepTotal($event, purchase)

    #Calculate the RBO Margin as: Commission to RBO - Amount to Reps - Overrides
    if purchase.commission
      $scope.purchase.rbo_margin = purchase.commission - $scope.purchase.rbo_repTotal - $scope.purchase.overrides
    else
      $scope.purchase.rbo_margin = 0

    $scope.redraw()

  $scope.amountPaidChange = ($event, purchase) ->
    $scope.purchase.percentPaid = ((purchase.amountPaid / purchase.TOTAL_PRICE)*100).toFixed(2)

  #reps + overrides
  $scope.addRepTotal = ($event, purchase) ->
    $scope.purchase.rbo_repTotal = 0
    $scope.purchase.overrides = 0
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep0 if purchase.rbo_commission_rep0
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep1 if purchase.rbo_commission_rep1
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep2 if purchase.rbo_commission_rep2
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep3 if purchase.rbo_commission_rep3
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep4 if purchase.rbo_commission_rep4
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep5 if purchase.rbo_commission_rep5
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep6 if purchase.rbo_commission_rep6
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rep7 if purchase.rbo_commission_rep7
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_repOSSP if purchase.rbo_commission_repOSSP
    $scope.purchase.rbo_repTotal += purchase.rbo_commission_rbo4 if purchase.rbo_commission_rbo4 #count out of reps commission amount
    $scope.purchase.overrides += purchase.rbo_commission_rbo1 if purchase.rbo_commission_rbo1
    $scope.purchase.overrides += purchase.rbo_commission_rbo2 if purchase.rbo_commission_rbo2
    $scope.purchase.overrides += purchase.rbo_commission_rbo3 if purchase.rbo_commission_rbo3

  $scope.changeRep = ($event, type, clientId) ->
    $event.preventDefault()
    return unless type and clientId
    results = User.getByClientId {clientId: clientId},
      # success
      ->
        return alert "User not found for Client Id: #{clientId}.  Please enter a new Client Id and try again." unless results._id
        if results._id
          if type is "parent"
            $scope.purchase.userParent = results
            $scope.purchase.userParentId = $scope.purchase.userParent._id
          if type is "r0"
            $scope.rep0 = results
            $scope.purchase.rbo_rep0 = results._id
          if type is "r1"
            $scope.rep1 = results
            $scope.purchase.rbo_rep1 = results._id
          if type is "r2"
            $scope.rep2 = results
            $scope.purchase.rbo_rep2 = results._id
          if type is "r3"
            $scope.rep3 = results
            $scope.purchase.rbo_rep3 = results._id
          if type is "r4"
            $scope.rep4 = results
            $scope.purchase.rbo_rep4 = results._id
          if type is "r5"
            $scope.rep5 = results
            $scope.purchase.rbo_rep5 = results._id
          if type is "r6"
            $scope.rep6 = results
            $scope.purchase.rbo_rep6 = results._id
          if type is "r7"
            $scope.rep7 = results
            $scope.purchase.rbo_rep7 = results._id
          if type is "ossp"
            $scope.repOSSP = results
            $scope.purchase.rbo_repOSSP = results._id
        else
          alert "User not found for Client Id: #{clientId}.  Please enter a new Client Id and try again."
      ,
      # err
      (res) ->
        alert(res.data.error) if res?.data?.error


  $scope.update = ($event, purchase, recalcCommissions) ->
    $event.preventDefault() if $event

    if recalcCommissions and purchase.commissionsPaid
      alert "Cannot recalculate.  Commissions have already been paid for this purchase. To recalculate commissions please clear the commissions paid date first and try again."
      return

    if recalcCommissions
      noteOverride = "Recalculated Commissions"
    else
      noteOverride = null

    $scope.promptSaveNote $event, noteOverride, (err, note) ->
      if err
        alert err
        console.log "Save was cancelled"
        return
      else if !note
        alert "In order to save your changes, a note is required."
      else
        purchaseData = {
          _id: purchase._id
          userId: purchase.userId
          tenantId: purchase.tenantId
          huntCatalogId: purchase.huntCatalogId
          userParentId: purchase.userParentId
          outfitter_userId: $scope.huntCatalog.outfitter_userId
          paymentMethod: purchase.paymentMethod
          basePrice: purchase.basePrice
          tags_licenses: purchase.tags_licenses
          shipping: purchase.shipping
          fee_processing: purchase.fee_processing
          sales_tax: purchase.sales_tax
          amount: purchase.amount
          amountPaid: purchase.amountPaid
          purchaseNotes: purchase.purchaseNotes
          check_number: purchase.check_number
          check_name: purchase.check_name
          commission: purchase.commission
          commissionPercent: purchase.commissionPercent
          commissionsPaid: purchase.commissionsPaid
          adminNotes: purchase.adminNotes
          recalcCommissions: recalcCommissions
        }
        if !recalcCommissions
          purchaseData.rbo_rep0 = purchase.rbo_rep0
          purchaseData.rbo_rep1 = purchase.rbo_rep1
          purchaseData.rbo_rep2 = purchase.rbo_rep2
          purchaseData.rbo_rep3 = purchase.rbo_rep3
          purchaseData.rbo_rep4 = purchase.rbo_rep4
          purchaseData.rbo_rep5 = purchase.rbo_rep5
          purchaseData.rbo_rep6 = purchase.rbo_rep6
          purchaseData.rbo_rep7 = purchase.rbo_rep7
          purchaseData.rbo_repOSSP = purchase.rbo_repOSSP
          purchaseData.rbo_rbo1 = purchase.rbo_rbo1
          purchaseData.rbo_rbo2 = purchase.rbo_rbo2
          purchaseData.rbo_rbo3 = purchase.rbo_rbo3
          purchaseData.rbo_rbo4 = purchase.rbo_rbo4
          purchaseData.rbo_commission_rep0 = purchase.rbo_commission_rep0
          purchaseData.rbo_commission_rep1 = purchase.rbo_commission_rep1
          purchaseData.rbo_commission_rep2 = purchase.rbo_commission_rep2
          purchaseData.rbo_commission_rep3 = purchase.rbo_commission_rep3
          purchaseData.rbo_commission_rep4 = purchase.rbo_commission_rep4
          purchaseData.rbo_commission_rep5 = purchase.rbo_commission_rep5
          purchaseData.rbo_commission_rep6 = purchase.rbo_commission_rep6
          purchaseData.rbo_commission_rep7 = purchase.rbo_commission_rep7
          purchaseData.rbo_commission_repOSSP = purchase.rbo_commission_repOSSP
          purchaseData.rbo_commission_rbo1 = purchase.rbo_commission_rbo1
          purchaseData.rbo_commission_rbo2 = purchase.rbo_commission_rbo2
          purchaseData.rbo_commission_rbo3 = purchase.rbo_commission_rbo3
          purchaseData.rbo_commission_rbo4 = purchase.rbo_commission_rbo4
          purchaseData.rbo_margin = purchase.rbo_margin
          purchaseData.rbo_reps_commission = purchase.rbo_reps_commission
          purchaseData.refund_amount = purchase.refund_amount
          purchaseData.next_payment_amount = purchase.next_payment_amount
          purchaseData.status = purchase.status
          purchaseData.qb_invoice_recorded = purchase.qb_invoice_recorded
          purchaseData.qb_expense_bill_recorded = purchase.qb_expense_bill_recorded
          purchaseData.qb_invoice_payment_reconciled = purchase.qb_invoice_payment_reconciled
          purchaseData.qb_expense_payment_paid = purchase.qb_expense_payment_paid
          purchaseData.qb_expense_payment_paid_date = purchase.qb_expense_payment_paid_date
          purchaseData.qb_expense_balance_due = purchase.qb_expense_balance_due
          purchaseData.purchase_confirmed_by_client = purchase.purchase_confirmed_by_client
          purchaseData.purchase_confirmed_by_outfitter = purchase.purchase_confirmed_by_outfitter
          purchaseData.confirmation_sent_outfitter = purchase.confirmation_sent_outfitter
          purchaseData.confirmation_sent_client = purchase.confirmation_sent_client
          purchaseData.start_hunt_date = purchase.start_hunt_date
          purchaseData.end_hunt_date = purchase.end_hunt_date
          purchaseData.next_payment_date = purchase.next_payment_date
          purchaseData.purchase_cancelled = purchase.purchase_cancelled

        results = Purchase.commissions {purchaseData: purchaseData}, (results) ->
          if recalcCommissions
            alert "Purchase Item commissions recalculated and successfully updated."
          else
            alert "Purchase Item successfully updated."
          $scope.loadPurchase purchase._id
        , (err) ->
          errMsg = "Error updating purchase item."
          errMsg = "#{errMsg}, #{err.data.error}" if err?.data?.error
          alert errMsg
          console.log "Error updating purchase item:", err


  $scope.addNote = ($event) ->
    $scope.promptSaveNote $event, null, (err, note) ->
      if err
        alert err
        return
      else
        $scope.redraw()
        return

  $scope.promptSaveNote = ($event, noteOverride, cb) ->
    $event.preventDefault() if $event
    now = $scope.formatDate(new Date())

    UpdateNote = (note, cb) ->
      if $scope.purchase.adminNotes
        $scope.purchase.adminNotes += "\n#{now}, #{$scope.user.name}: #{note}"
      else
        $scope.purchase.adminNotes = "#{now}, #{$scope.user.name}: #{note}"
      return cb null, note

    if noteOverride
      UpdateNote noteOverride, cb
    else
      kendo.prompt("#{$scope.user.name} Note: ", "")
        .then (data) ->
          if !data
            return cb null, data
          note = data
          UpdateNote note, cb
        , () ->
          return cb null, null

  $scope.checkUser = (type) ->
    if $scope.user.userType is "super_admin" and type is 'sadmin'
      return true
    else if type is 'tadmin' and ($scope.user.userType is "tenant_admin" or $scope.user.userType is "super_admin")
      return true
    else
      return false


  $scope.formatDate = (date) ->
    dformat = [date.getMonth()+1,
      date.getDate(),
      date.getFullYear()].join('/')+' '+
      [date.getHours(),
        date.getMinutes(),
        date.getSeconds()].join(':')
    return dformat


  $scope.confirmationLetters = ($event) ->
    $event.preventDefault()
    modalReturned = (results) ->
      if results.status is "sent"
        purchase = results.results
        $scope.purchase.confirmation_sent_outfitter = new Date(purchase.confirmation_sent_outfitter) if purchase?.confirmation_sent_outfitter
        $scope.purchase.confirmation_sent_client = new Date(purchase.confirmation_sent_client) if purchase?.confirmation_sent_client
        $scope.redraw()
      else if (results is "cancel" or results is "backdrop click")
        console.log "modal cancelled"
      else if results.error
        alert("The confirmation letters failed to send successfully. #{results.error}")
      else
        alert("The confirmation letters failed to send successfully.")

    modal = $modal.open
      templateUrl: 'templates/partials/confirmation_letters.html'
      controller: 'ConfirmationLetters'
      resolve: {
        currentUser: -> return $scope.user
        purchaseItem: -> return $scope.purchase
        huntCatalogItem: -> return $scope.huntCatalog
      }
      scope: $scope

    modal.result.then modalReturned, modalReturned

  $scope.init.call(@)
])
