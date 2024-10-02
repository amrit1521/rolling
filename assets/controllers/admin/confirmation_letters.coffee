APP = window.APP
APP.Controllers.controller('ConfirmationLetters', ['$scope', '$modalInstance','Storage', 'currentUser', 'purchaseItem', 'huntCatalogItem', 'Purchase', ($scope, $modalInstance, Storage, currentUser, purchaseItem, huntCatalogItem, Purchase) ->

  $scope.init = ->

    if huntCatalogItem.outfitter?
      huntCatalogItem.outfitter.business_email = huntCatalogItem.outfitter.email unless huntCatalogItem.outfitter.business_email
      huntCatalogItem.outfitter.business_phone = huntCatalogItem.outfitter.phone_cell unless huntCatalogItem.outfitter.business_phone
    if huntCatalogItem.outfitter?.business_phone?.length is 10
      huntCatalogItem.outfitter.business_phone = "#{huntCatalogItem.outfitter.business_phone.substr(0,3)}-#{huntCatalogItem.outfitter.business_phone.substr(3,3)}-#{huntCatalogItem.outfitter.business_phone.substr(6,4)}"

    $scope.tenant = window.tenant
    $scope.user = currentUser
    $scope.purchase = purchaseItem
    $scope.huntCatalog = huntCatalogItem
    $scope.sending = false

  $scope.submitLetters = ($event, sendType) ->
    $event.preventDefault()
    $scope.sending = true
    $scope.sendType = sendType
    if $scope.validate()
      Purchase.sendConfirmations {purchase: $scope.purchase, huntCatalog: $scope.huntCatalog, sendType: sendType}, (results) ->
        alert "Confirmation letter emails sent successfully."
        $scope.sending = false
        $modalInstance.dismiss({status: "sent", results: results})
      , (err) ->
        console.log "Error sending confirmation letters: ", err
        $scope.sending = false
        $modalInstance.dismiss({status: "failed", error: err, errorMsg: "Error occurred sending confirmation letters."})
    else
      alert "Please try again after entering the missing required information."


  $scope.validate = () ->
    missingFields = []
    missingFields.push "Outfitter Name" unless $scope.huntCatalog.outfitter_name
    missingFields.push "Outfitter Email" unless $scope.huntCatalog.outfitter.email
    #missingFields.push "Outfitter Mailing Address" unless $scope.huntCatalog.outfitter.mail_address
    #missingFields.push "Outfitter Mailing City" unless $scope.huntCatalog.outfitter.mail_city
    #missingFields.push "Outfitter Mailing State" unless $scope.huntCatalog.outfitter.mail_state
    #missingFields.push "Outfitter Mailing Postal" unless $scope.huntCatalog.outfitter.mail_postal
    missingFields.push "Hunt Catalog Title" unless $scope.huntCatalog.title
    missingFields.push "Hunt Catalog Number" unless $scope.huntCatalog.huntNumber
    #missingFields.push "Confirmation Hunt Start Date" unless $scope.purchase.start_hunt_date
    #missingFields.push "Confirmation Hunt End Date" unless $scope.purchase.end_hunt_date
    #missingFields.push "Hunt Dates Confirmed by Outfitter" unless $scope.purchase.purchase_confirmed_by_outfitter
    missingFields.push "Client First Name" unless $scope.purchase.user.first_name
    missingFields.push "Client Last Name" unless $scope.purchase.user.last_name
    missingFields.push "Client Id" unless $scope.purchase.user.clientId
    missingFields.push "Client Email" unless $scope.purchase.user.email
    missingFields.push "Client Phone Cell" unless $scope.purchase.user.phone_cell
    missingFields.push "Client Mailing Address" unless $scope.purchase.user.mail_address or $scope.purchase.user.physical_address
    missingFields.push "Client Mailing City" unless $scope.purchase.user.mail_city or $scope.purchase.user.physical_city
    missingFields.push "Client Mailing State" unless $scope.purchase.user.mail_state or $scope.purchase.user.physical_state
    missingFields.push "Client Mailing Postal" unless $scope.purchase.user.mail_postal or $scope.purchase.user.physical_postal
    missingFields.push "Total Client Price" unless $scope.purchase.TOTAL_PRICE
    missingFields.push "Total to Outfitter" unless $scope.purchase.totalToOutfitter
    missingFields.push "Client Deposit Paid" unless $scope.purchase.amount
    missingFields.push "RBO Commissions Booking Fee" unless $scope.purchase.commission or $scope.purchase.commission is 0
    #missingFields.push "RBO Processing Fee" unless $scope.purchase.fee_processing
    missingFields.push "Remaining Deposit to Send Outfitter" unless $scope.purchase.remainingDepositToSend
    missingFields.push "Client Owes Outfitter" unless $scope.purchase.clientOwes or $scope.purchase.clientOwes is 0
    missingFields.push "Purchase Invoice #" unless $scope.purchase.invoiceNumber



    if missingFields.length > 0
      msg = "The following information is required before confirmation letters can be sent"
      fieldsStr = missingFields.join(",\n")
      alert "#{msg}:\n#{fieldsStr}"
      return false
    else
      return true

  $scope.cancel = ($event) ->
    $event.preventDefault()
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
