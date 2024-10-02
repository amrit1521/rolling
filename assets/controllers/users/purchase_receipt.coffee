APP = window.APP
APP.Controllers.controller('PurchaseReceipt', ['$scope', '$rootScope', '$routeParams', '$sce', '$modal', 'Storage', 'User', 'Purchase', ($scope, $rootScope, $routeParams, $sce, $modal, Storage, User, Purchase) ->

  $scope.init = ->
    $scope.PAYMENT_BY_CHECK_INSTRUCTIONS = "The check must be received by #{window.tenant.name} and cleared by the bank within the next 7 business days. Purchases made by check payments that are not received within 7 business days may be cancelled by #{window.tenant.name} without notice."
    $scope.user = Storage.get 'user'
    $scope.tenantURL = window.tenant.url
    $scope.purchase = null
    $scope.huntCatalog = null
    $scope.foundReceipt = false
    $scope.congratsText = null
    $scope.nextStepText = null
    $scope.loadPurchase($routeParams.id)

  $scope.loadPurchase = (purchaseId) ->
    setPurchase = (results) ->
      $scope.purchase = results
      $scope.userIsMember = $scope.purchase.userIsMember

      $scope.huntCatalog = $scope.purchase.huntCatalogCopy[0] if $scope.purchase?.huntCatalogCopy?[0]

      #Calc total amount
      $scope.purchase.totalPrice = $scope.purchase.basePrice #total cost to the user
      $scope.purchase.totalPrice = $scope.huntCatalog.price_total if $scope.huntCatalog?.price_total
      $scope.totalAmount = $scope.purchase.amount #total paid
      #Backward compatible, now any additional fees or sales tax charged will be in amountTotal
      if $scope.purchase.amountTotal
        $scope.totalAmount = $scope.purchase.amountTotal

      if $scope.huntCatalog
        $scope.huntCatalog = $scope.purchase.huntCatalogCopy[0] if $scope.purchase?.huntCatalogCopy?[0]
        $scope.huntCatalog.startDate = new Date($scope.huntCatalog.startDate)
        $scope.huntCatalog.endDate = new Date($scope.huntCatalog.endDate)
        startDateStr = "#{$scope.huntCatalog.startDate.getMonth()+1}/#{$scope.huntCatalog.startDate.getDate()}/#{$scope.huntCatalog.startDate.getFullYear()}"
        endDateStr = "#{$scope.huntCatalog.endDate.getMonth()+1}/#{$scope.huntCatalog.endDate.getDate()}/#{$scope.huntCatalog.endDate.getFullYear()}"
        $scope.huntCatalog.dateRange = "#{startDateStr} - #{endDateStr}"
        #$scope.huntCatalog.budgetRange = "$#{$scope.huntCatalog.budgetStart} - $#{$scope.huntCatalog.budgetEnd}"
        if $scope.huntCatalog.pricingNotes
          $scope.huntCatalog.pricingNotesAsHTML = $scope.huntCatalog.pricingNotes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.huntCatalog.pricingNotesAsHTML = $sce.trustAsHtml($scope.huntCatalog.pricingNotesAsHTML);
        if $scope.purchase.purchaseNotes
          $scope.purchase.purchaseNotesAsHTML = $scope.purchase.purchaseNotes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.purchase.purchaseNotesAsHTML = $sce.trustAsHtml($scope.purchase.purchaseNotesAsHTML);

        if $scope.purchase.monthlyPayment
          #Display as currency adding a .00 if needed.
          mpStrArry = $scope.purchase.monthlyPayment.toString().split(".")
          if mpStrArry?.length > 0 and mpStrArry[1]?.length == 1
            $scope.purchase.monthlyPaymentStr = "#{$scope.purchase.monthlyPayment}0"
          else
            $scope.purchase.monthlyPaymentStr = "#{$scope.purchase.monthlyPayment}"


        if $scope.huntCatalog.type is "hunt"
          $scope.congratsText = "Your payment to reserve this hunt has been accepted and the hunt and your requested dates have been confirmed and held."
          $scope.nextStepText = "The hunt reservation and dates will be finalized upon completion of your final agreement with your #{window.tenant.name} Concierge Specialist and the Outfitter or Guide."
        else if $scope.huntCatalog.type is "course"
          $scope.congratsText = "Your payment to reserve a spot in the course has been confirmed and held."
          $scope.nextStepText = "The reservation will be finalized upon completion of your final agreement with your #{window.tenant.name} Concierge Specialist and #{window.tenant.name} Course instructor."
        else
          $scope.congratsText = "Your payment has been accepted."
          $scope.nextStepText = "You will be contacted within the next 2 business days to finalize the order and delivery details."

        User.get {id: $scope.purchase.userId}, (results) ->
          $scope.purchase.user = results
        , (err) ->
          console.log "Error retrieving hunt catalog user: ", err

        $scope.foundReceipt = true
        #console.log "$scope.purchase", $scope.purchase
      else
        console.log "results: ", results
        alert "Could not retrieve receipt."
        window.location = "#!/huntcatalogs"

    Purchase.read {id: purchaseId}, (results) ->
      setPurchase(results)
    , (err) ->
      errMsg = "Error retrieving receipt"
      errMsg = "#{errMsg}, #{err.data.error}" if err?.data?.error
      alert errMsg
      console.log "Error retrieving purchase receipt:", err
      $scope.return()

  $scope.return = ($event, target) ->
    $event.preventDefault() if $event
    if target is "huntcatalogs"
      window.location = "#!/huntcatalogs"
    else if target is "purchases"
      window.location = "#!/purchases"
    else
      window.location = "#!/huntcatalogs"

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


  $scope.init.call(@)
])
