APP = window.APP
APP.Controllers.controller('RecordPayment', ['$scope', '$rootScope', '$routeParams', '$sce', '$modal', 'Storage', 'User', 'Purchase', 'State', ($scope, $rootScope, $routeParams, $sce, $modal, Storage, User, Purchase, State) ->

  $scope.init = ->
    $scope.tenantId = window.tenant._id
    $scope.tenantName = window.tenant.name
    $scope.user = Storage.get 'user'
    $scope.show_saving = false
    $scope.payment = {paidOn: new Date(), card: {}}
    $scope.apply_payment_user = null
    $scope.apply_payment_purchase_object = null
    $scope.paymentTypes = [
      {name: "Check", value: "check"},
      {name: "Cash", value: "cash"}
      {name: "Credit Card", value: "card"}
    ]
    $scope.months = [
      {name: "January", value: "01"},
      {name: "February", value: "02"}
      {name: "March", value: "03"}
      {name: "April", value: "04"}
      {name: "May", value: "05"}
      {name: "June", value: "06"}
      {name: "July", value: "07"}
      {name: "August", value: "08"}
      {name: "September", value: "09"}
      {name: "October", value: "10"}
      {name: "November", value: "11"}
      {name: "December", value: "12"}
    ]
    $scope.years = ["2019","2020","2021","2022","2023","2024","2025","2026","2027","2028","2029","2030","2031","2032","2033","2034","2035","2036","2037"]
    $scope.states = State.stateList
    $scope.countries = User.countryList
    useSandbox = false
    if useSandbox
      $scope.clientKey = '5DCB253CYcg43Uxsw4qtmDKhwNSkxu4RMmqLWY8j3aTSaaBHL97NxUucS3PNA4fD'
      $scope.apiLoginID = '5mgh992BE3'
    else
      $scope.clientKey = '75pW6r8CLNdCeBn4bXR32ZmaX4TURJWRbe35R75k8JfA7DumTQT8E3uBpbea6j5L'
      $scope.apiLoginID = '67ZzR2D5Ed3'

  $scope.findOriginalPurchase = ($event, invoiceNumber) ->
    $event.preventDefault()
    return unless invoiceNumber
    results = Purchase.byInvoiceNumberPublic {invoiceNumber: invoiceNumber},
      # success
      ->
        return alert "Original purchase not found for Invoice #: #{invoiceNumber}.  Please enter a new invoice number and try again." unless results._id
        if results._id
          $scope.apply_payment_purchase_object = results
          $scope.apply_payment_user = results.user if results?.user
        else
          alert "Original purchase not found for Invoice #: #{invoiceNumber}.  Please enter a new invoice number and try again."
    ,
      # err
      (res) ->
        alert(res.data.error) if res?.data?.error

  $scope.validate = (payment) ->
    errors = []
    errors.push ("Original invoice # required") unless $scope.apply_payment_user
    errors.push ("Original invoice # required") unless $scope.apply_payment_purchase_object
    errors.push ("Payment type required") unless payment.specific_type
    errors.push ("Payment amount required") unless payment.amount and payment.amount > 0
    errors.push ("Paid on required") unless payment.paidOn
    if payment.specific_type is 'card'
      errors.push ("Name On Card is required") unless payment.card.name
      errors.push ("Card Number is required") unless payment.card.number
      errors.push ("Card Verification Code is required") unless payment.card.code
      errors.push ("Expiration Month is required") unless payment.card.month
      errors.push ("Expiration Year is required") unless payment.card.year
      errors.push ("Card Holder Zip Code is required") unless payment.card.postal
      errors.push ("Card Holder Address is required") unless payment.card.address1
      errors.push ("Card Holder City is required") unless payment.card.city
      errors.push ("Card Holder State is required") unless payment.card.state
      errors.push ("Card Holder Country Code is required") unless payment.card.country
    else
      errors.push ("Name required") unless payment.name
      errors.push ("Check # required") if payment.specific_type is "check" and !payment.referenceNumber

    return errors

  $scope.update = ($event, payment) ->
    $event.preventDefault() if $event
    payment.createdAt = new Date()
    validateErrors = $scope.validate(payment)
    if validateErrors.length
      alert "Missing required fields.  #{validateErrors.join(",")}"
    else
      results = Purchase.recordPayment {user: $scope.apply_payment_user, originalPurchase: $scope.apply_payment_purchase_object, payment: payment, do_not_send_email: true},
        # success
        (results) ->
          alert "Payment saved successfully."
          window.location = "#!/dashboard"
      ,
      # err
      (res) ->
        alert(res.data.error) if res?.data?.error

  $scope.cancel = ($event) ->
    $event.preventDefault() if $event
    window.location = "#!/dashboard"

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

  $scope.formatDate = (date) ->
    dformat = [date.getMonth()+1,
      date.getDate(),
      date.getFullYear()].join('/')+' '+
      [date.getHours(),
        date.getMinutes(),
        date.getSeconds()].join(':')
    return dformat

  $scope.submitPayment = ($event, payment) ->
    $event.preventDefault() if $event

    validateErrors = $scope.validate(payment)
    if validateErrors.length
      alert "Missing required fields.  #{validateErrors.join(",")}"
    else
      handleAuthNetReponse = (response) ->
        errorMsg = "Payment failed to process."
        if response.messages.resultCode == 'Error'
          i = 0
          while i < response.messages.message.length
            error = response.messages.message[i].code + ': ' + response.messages.message[i].text
            if i is 0
              errorMsg = error
            else
              errorMsg = "#{errorMsg},  #{error}"
            console.log error
            i = i + 1
          console.log errorMsg
          alert errorMsg
          return
        else if response.messages.resultCode == 'Ok' and response.opaqueData?.dataValue?.length
          payment.authorize_net_data_descriptor = response.opaqueData.dataDescriptor
          payment.authorize_net_data_value = response.opaqueData.dataValue
          payment.paidOn = new Date()
          payment.name = payment.card.name
          payment.address1 = payment.card.address1
          payment.country = payment.card.country
          payment.city = payment.card.city
          payment.state = payment.card.state
          payment.zip = payment.card.postal
          $scope.update null, payment
        else
          alert errorMsg
        return

      authData = {}
      authData.clientKey = $scope.clientKey
      authData.apiLoginID = $scope.apiLoginID
      cardData = {}
      cardData.cardNumber = payment.card.number
      cardData.month = payment.card.month
      cardData.year = payment.card.year
      cardData.cardCode = payment.card.code
      secureData = {}
      secureData.authData = authData
      secureData.cardData = cardData
      #Submit card to authorize.net
      Accept.dispatchData secureData, handleAuthNetReponse
      return




  $scope.init.call(@)
])
