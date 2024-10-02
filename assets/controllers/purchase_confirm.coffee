APP = window.APP
APP.Controllers.controller('PurchaseConfirm', ['$scope', '$modalInstance', '$sce', 'Storage', 'tHuntCatalog', 'currentUser', 'card', 'purchaseItem', 'User', 'HuntCatalog', ($scope, $modalInstance, $sce, Storage, tHuntCatalog, currentUser, card, purchaseItem, User, HuntCatalog) ->

  $scope.init = ->
    $scope.huntCatalog = tHuntCatalog
    $scope.user = currentUser
    $scope.card = card
    $scope.purchaseItem = purchaseItem
    $scope.submittingPayment = false
    $scope.PAYMENT_BY_CHECK_INSTRUCTIONS = "Please validate the name, check number, and check amount below.  Incorrect data may result in the purchase being delayed or cancelled.  The check must be received by #{window.tenant.name} and cleared by the bank within the next 7 business days. Purchases made by check payments that are not received within 7 business days may be cancelled by #{window.tenant.name} without notice."
    $scope.tenantURL = window.tenant.url
    $scope.prepPage()

    #$modalInstance.dismiss('ok')
    #$modalInstance.dismiss(err)

  $scope.prepPage = () ->
    if $scope.purchaseItem.notes
      $scope.purchaseItem.notesAsHTML = $scope.purchaseItem.notes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
      $scope.purchaseItem.notesAsHTML = $sce.trustAsHtml($scope.purchaseItem.notesAsHTML);
    $scope.totalAmount = $scope.purchaseItem.amount

  $scope.submitPayment = ($event) ->
    $event.preventDefault()
    $scope.submittingPayment = true

    purchaseData = {
      id: $scope.huntCatalog._id
      huntCatalog: $scope.huntCatalog
      userId: $scope.user._id
      card: $scope.card
      purchaseItem: $scope.purchaseItem
    }

    HuntCatalog.purchase purchaseData, (results) ->
      if results?.results?.newMember
        #update user member info for the browser
        $scope.userIsMember = true
        $scope.user.isMember = true
        $scope.user.memberId = results.results.newMember.memberId if results.results.newMember.memberId
        $scope.user.memberType = results.results.newMember.memberType if results.results.newMember.memberType
        $scope.user.memberStatus = results.results.newMember.memberStatus if results.results.newMember.memberStatus
        $scope.user.memberExpires = new Date(results.results.newMember.memberExpires) if results.results.newMember.memberExpires
        Storage.set 'user', $scope.user

      if results?.results?.newRep
        #update user rep info for the browser
        $scope.user.isRep = true
        $scope.user.repType = results.results.newRep.repType if results.results.newRep.repType
        $scope.user.repStatus = results.results.newRep.repStatus if results.results.newRep.repStatus
        $scope.user.repExpires = new Date(results.results.newRep.repExpires) if results.results.newRep.repExpires
        Storage.set 'user', $scope.user

      if purchaseItem.paymentMethod is "cc"
        if results.results.purchaseId
          alert "The credit card transaction completed successfully."
          $scope.submittingPayment = false
          $modalInstance.dismiss({status: "success", results, purchaseId: results.results.purchaseId})
        else
          alert "The credit card transaction failed."
          console.log "Error, missing purchaseId:", results
          $scope.submittingPayment = false
          $modalInstance.dismiss({status: "failed", error: results, errorMsg: "Error, missing purchaseId."})
      else
        if results.results.purchaseId
          alert "The purchase order transaction completed successfully."
          $scope.submittingPayment = false
          $modalInstance.dismiss({status: "success", results, purchaseId: results.results.purchaseId})
        else
          alert "The purchase order transaction failed."
          console.log "Error, missing purchaseId:", results
          $scope.submittingPayment = false
          $modalInstance.dismiss({status: "failed", error: results, errorMsg: "Error, missing purchaseId."})

    , (err) ->
      console.log "purchase hunt catalog error:", err
      if err.data.errorMsg
        alert "The payment failed with error: #{err.data.errorMsg}  Please verify the payment information and try again."
      else if err.data.error
        alert "The payment failed with error: #{err.data.error}  Please verify the payment information and try again."
      else
        alert "The payment failed."
      $scope.submittingPayment = false
      $modalInstance.dismiss({status: "failed", error: err, errorMsg: err.data.errorMsg})


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


  $scope.cancel = ($event) ->
    $event.preventDefault()
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
