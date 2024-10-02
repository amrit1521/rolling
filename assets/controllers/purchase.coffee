APP = window.APP
APP.Controllers.controller('Purchase', ['$scope', '$rootScope', '$routeParams', '$sce', '$modal', 'Storage', 'User', 'HuntCatalog', 'State', 'Tenant', ($scope, $rootScope, $routeParams, $sce, $modal, Storage, User, HuntCatalog, State, Tenant) ->

  $scope.init = ->
    $scope.nomPerent = .10
    $scope.CREDIT_CARD_CAP = 100000
    $scope.PAYMENT_BY_CHECK_INSTRUCTIONS = "To pay by check, please fill out the check and enter the check number below.  The check must be received by #{window.tenant.name} and cleared by the bank within the next 7 business days. Purchases made by check payments that are not received within 7 business days may be cancelled by #{window.tenant.name} without notice."
    $scope.tenantURL = window.tenant.url
    $scope.website = $routeParams.website
    $scope.user = Storage.get 'user'
    $scope.adminUser = Storage.get 'adminUser'
    $scope.topToken = Storage.get('topToken') if Storage.get('topToken')
    $scope.user = {} unless $scope.user
    $scope.userIsMember = $scope.setIsMember()
    $scope.parentUser = null
    $scope.parentClientId = $routeParams.ref
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.cardTypes = ["Visa","American Express","Mastercard"]
    $scope.months = ["01","02","03","04","05","06","07","08","09","10","11","12"]
    $scope.monthNames = ["January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    $scope.today = new Date()
    $scope.years = ["2017","2018","2019","2020","2021","2022","2023","2024","2025","2026","2027","2028","2029","2030","2031","2032","2033","2034","2035","2036","2037"]
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.huntCatalog = null
    $scope.card = {}
    $scope.purchaseItem = {}
    $scope.purchaseAgreementChecked = false
    $scope.useExistingAccount = "true"
    $scope.showOptOut = false
    $scope.allowCheck = $scope.allowChecks()
    $scope.loadHuntCatalog($routeParams.id)
    $scope.prepCard()
    $scope.getParentUser($scope.parentClientId)

  $scope.setIsMember = () ->
    if $scope.user.isMember
      return true
    if $scope.user.memberType?.toLowerCase().indexOf('member') > -1 #or $scope.user.member_id?.toLowerCase().indexOf('specialist')
      return true
    else
      return false

  $scope.prepCard = () ->
    if $scope.user.name
      $scope.card.name = $scope.user.name
    else if $scope.user.first_name or $scope.user.last_name
      $scope.card.name = "#{$scope.user.first_name} #{$scope.user.last_name}".trim()
    $scope.card.email = $scope.user.email if $scope.user.email
    if $scope.user.phone_cell
      $scope.card.phone = $scope.user.phone_cell
    else if $scope.user.phone_day
      $scope.card.phone = $scope.user.phone_day

  $scope.prepPurchase = () ->
    now = new Date()

    #handle payment method
    $scope.purchaseItem.paymentMethod = "cc"

    #handle paymentPlan options
    if $scope.huntCatalog.paymentPlan is "full" or $scope.huntCatalog.paymentPlan is "subscription_monthly" or $scope.huntCatalog.paymentPlan is "subscription_yearly"
      monthDiff = -1
      $scope.purchaseItem.monthlyPaymentNumberMonths = 0
    else if $scope.huntCatalog.paymentPlan is "months" #currently hard coded to be 50% down and rest over 12 months
      $scope.purchaseItem.monthlyPaymentNumberMonths = 0 unless $scope.purchaseItem.monthlyPaymentNumberMonths
      tDate = new Date()
      tDate = new Date((tDate.setMonth(tDate.getMonth() + ($scope.purchaseItem.monthlyPaymentNumberMonths+1))))
      endYear = tDate.getFullYear()
      endMonth = tDate.getMonth() + (endYear * 12)
      startYear = now.getFullYear()
      startMonth = now.getMonth() + (startYear * 12)
      monthDiff = endMonth - startMonth
    else
      endYear = $scope.huntCatalog.startDate.getFullYear()
      endMonth = $scope.huntCatalog.startDate.getMonth() + (endYear * 12)
      startYear = now.getFullYear()
      startMonth = now.getMonth() + (startYear * 12)
      monthDiff = endMonth - startMonth
      $scope.purchaseItem.monthlyPaymentNumberMonths = monthDiff-1

    $scope.monthDiff = monthDiff

    if $scope.userIsMember
      price = $scope.huntCatalog.price_total
    else
      price = $scope.huntCatalog.price_nom

    #Calculate min down payment
    if monthDiff <= 0
      $scope.purchaseItem.minPaymentRequired = price
    else if monthDiff <= 12
      $scope.purchaseItem.minPaymentRequired = price / 2 # %50 down required
    else if monthDiff > 12 and monthDiff <= 18
      $scope.purchaseItem.minPaymentRequired = 1000
    else if monthDiff > 18 and monthDiff <= 36
      $scope.purchaseItem.minPaymentRequired = 200
    else
      alert "This hunt is more than 3 years in the future and is not yet available to be purchased.  Thanks."
      $scope.cancel()

    if price < $scope.purchaseItem.minPaymentRequired
      $scope.purchaseItem.minPaymentRequired = price

    $scope.purchaseItem.amount = $scope.purchaseItem.minPaymentRequired
    $scope.purchaseItem.userIsMember = $scope.userIsMember
    $scope.calcMonthlyPayment($scope.purchaseItem.amount)

  $scope.loadHuntCatalog = (huntCatalogId) ->
    setHuntCatalog = (results) ->
      $scope.huntCatalog = results
      $scope.huntCatalog.startDate = new Date($scope.huntCatalog.startDate)
      $scope.huntCatalog.endDate = new Date($scope.huntCatalog.endDate)
      startDateStr = "#{$scope.huntCatalog.startDate.getMonth()+1}/#{$scope.huntCatalog.startDate.getDate()}/#{$scope.huntCatalog.startDate.getFullYear()}"
      endDateStr = "#{$scope.huntCatalog.endDate.getMonth()+1}/#{$scope.huntCatalog.endDate.getDate()}/#{$scope.huntCatalog.endDate.getFullYear()}"
      $scope.huntCatalog.dateRange = "#{startDateStr} - #{endDateStr}"
      #$scope.huntCatalog.budgetRange = "$#{$scope.huntCatalog.budgetStart} - $#{$scope.huntCatalog.budgetEnd}"

      #For backwards compatibility
      if !$scope.huntCatalog.fee_processing
        $scope.huntCatalog.fee_processing = 0
      if !$scope.huntCatalog.price_total
        $scope.huntCatalog.price_total = $scope.huntCatalog.price + $scope.huntCatalog.fee_processing
      if !$scope.huntCatalog.price_nom
        if $scope.huntCatalog.memberDiscount
          $scope.huntCatalog.price_nom = $scope.huntCatalog.price + ($scope.huntCatalog.price * .10) + $scope.huntCatalog.fee_processing
        else
          $scope.huntCatalog.price_nom = $scope.huntCatalog.price_total

      if $scope.huntCatalog.pricingNotes
        $scope.huntCatalog.pricingNotesAsHTML = $scope.huntCatalog.pricingNotes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
        $scope.huntCatalog.pricingNotesAsHTML = $sce.trustAsHtml($scope.huntCatalog.pricingNotesAsHTML);
      $scope.prepPurchase()
      $scope.enableReps($scope.huntCatalog)
      $scope.showOptOut = true if $scope.huntCatalog.paymentPlan == 'subscription_yearly'

    HuntCatalog.read {id: huntCatalogId}, (results) ->
      setHuntCatalog(results)
    , (err) ->
      alert "Error retrieving item to purchase."
      console.log "Error loading purchase item:", err


  $scope.calcMonthlyPayment = (amount) ->
    if $scope.purchaseItem.userIsMember
      price = $scope.huntCatalog.price_total
    else
      price = $scope.huntCatalog.price_nom

    if price
      if $scope.purchaseItem.monthlyPaymentNumberMonths <=0
        $scope.purchaseItem.amount = price
        amount = price
        monthlyPayment = (price - amount)
      else
        monthlyPayment = (price - amount) / $scope.purchaseItem.monthlyPaymentNumberMonths
        monthlyPayment = (Math.round (monthlyPayment*100)) / 100
      $scope.purchaseItem.monthlyPayment = monthlyPayment
      $scope.purchaseItem.monthlyPaymentStr = $scope.formatMoneyStr($scope.purchaseItem.monthlyPayment)

  $scope.validate = (card, user, huntCatalog, purchaseItem) ->
    valid = true
    messages = []

    #if purchaseItem.amount < $scope.purchaseItem.minPaymentRequired #Temp don't enforce minPayments....
    if purchaseItem.amount < huntCatalog.price_total and purchaseItem.amount < 500
      valid = false
      messages.push "The entered payment amount is below the allowed minimum down payment of $#{$scope.purchaseItem.minPaymentRequired}"

    if purchaseItem.paymentMethod is "cc" and purchaseItem.amount > $scope.CREDIT_CARD_CAP
      valid = false
      messages.push "Credit card payments over $#{$scope.CREDIT_CARD_CAP} must be taken over phone or in person.  Please change the payment method and try again."

    if purchaseItem.paymentMethod is "check"
      messages.push "Check Number is required to pay by check.  Please enter the check number and try again." unless purchaseItem.check_number
      messages.push "Name on check is required to pay by check.  Please enter the check holder's name and try again." unless purchaseItem.check_name

    if purchaseItem.paymentMethod is "check" and huntCatalog.paymentPlan is 'subscription_monthly'
      messages.push "Subscriptions may not be purchased by Bank Check.  Please select a different Payment Method"
    if purchaseItem.paymentMethod is "check" and huntCatalog.paymentPlan is 'subscription_yearly'
      messages.push "Subscriptions may not be purchased by Bank Check.  Please select a different Payment Method"

    if $scope.showRep
      if !$scope.purchaseAgreementChecked
        messages.push "Before you can proceed, please select the checkbox under the Sales Representative Agreement section indicating you have read and agree to the terms of the Sales Representative Agreement."
      if !user.first_name
        messages.push "Account Holder first name is required."
      if !user.last_name
        messages.push "Account Holder last name is required."
      if !user.repAgreement
        messages.push "Sales Representative Agreement is required."
      if !$scope.getAddress(user)
        messages.push "Account Holder address is required."
      if !$scope.getCity(user)
        messages.push "Account Holder city is required."
      if !$scope.getState(user)
        messages.push "Account Holder state is required."
      if !$scope.getZip(user)
        messages.push "Account Holder zip is required."
    valid = false if messages.length

    messageStr = ""
    for message in messages
      messageStr = messageStr + message + "\n"
    alert messageStr unless valid
    return valid

  $scope.continue = ($event, card, user, huntCatalog, purchaseItem) ->
    $event.preventDefault()
    #alert "The online credit card service is temporarily unavailable.  Please contact #{window.tenant.name} to complete this purchase."
    #return;

    if !user._id && $scope.useExistingAccount is "true"
      alert "Before purchasing this item, please login to your account or select to create a new account under the 'Account Holder Information' section above."
      return

    user.repAgreement = document.querySelector('#repAgreement').value if $scope.showRep
    if $scope.validate(card, user, huntCatalog, purchaseItem)
      $scope.saveUser $event, user, (err, user) =>
        if err
          console.log "User error: ", err
          alert "User data invalid."
          return

        purchaseItem.cc_email = card.email if card.email
        purchaseItem.cc_phone = card.phone if card.phone
        modal = $modal.open
          templateUrl: 'templates/partials/purchase_confirm.html'
          controller: 'PurchaseConfirm'
          resolve: {
            card: -> return card
            tHuntCatalog: -> return huntCatalog
            currentUser: -> return $scope.user
            purchaseItem: -> return purchaseItem
          }
          scope: $scope

        modal.result.then (results) ->
          if results.purchaseId and results.status is "success"
            window.location = "#!/purchase_receipt/#{results.purchaseId}"
        , (results) ->
          if results.purchaseId and results.status is "success"
            window.location = "#!/purchase_receipt/#{results.purchaseId}"

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

  $scope.monthDiffDisplay = () ->
    num = $scope.purchaseItem.monthlyPaymentNumberMonths
    if num <= 0
      num = 1
    return num

  $scope.cancel = ($event) ->
    $event.preventDefault() if $event
    if $scope.website
      location = "#!/huntcatalog/#{$scope.huntCatalog._id}?website=#{$scope.website}"
    else
      location = "#!/huntcatalog/#{$scope.huntCatalog._id}"
    if $scope.website and $scope.parentClientId
      location = "#{location}&ref=#{$scope.parentClientId}"
    else if $scope.parentClientId and !$scope.website
      location = "#{location}?ref=#{$scope.parentClientId}"
    window.location = location

  $scope.saveUser = ($event, user, cb) ->

    updateUserErr = (res) ->
      err =
      if res?.data?.error
        err = res.data.error
      else
        err = "An error occurred while updating user data."
      alert(err)
      return cb(err)

    updateUserSuccess = (result) ->
      userId = result._id if result?._id
      userId = result.user._id if result?.user?._id
      return cb("Failed to update user data, missing id.") unless userId
      params = {id: userId}
      params.topToken = $scope.topToken.token if $scope.topToken?.token
      User.get params, (updatedUser) ->
        tUser = _.omit updatedUser, '__v', '$promise', '$resolved'
        $scope.user = tUser
        Storage.set 'user', tUser
        return cb null, tUser
      , (err) ->
        console.log "Failed to update user data: ", err
        return cb(err)

    #User is already logged in, so save the user info that may have changed
    if $scope.user._id
      userData = _.pick(user, '_id', 'first_name', 'last_name', 'email', 'phone_cell', 'phone_home', 'mail_address', 'mail_city', 'mail_state', 'mail_country', 'mail_postal' )
      userData.repAgreement = user.repAgreement if user.repAgreement and $scope.showRep
      result = User.update userData, updateUserSuccess, updateUserErr

    #User is not logged in, and is requesting to create a new user with this purchase
    else if $scope.useExistingAccount == 'false'
      user.email = user.email?.toLowerCase()
      #Try logging in first to see if a user with the same email and password already exist.  If so, just log them in rather than creating a duplicate user.
      $scope.login $event, user, (err, loginUser) =>
        if err
          #Login failed, so create a new user
          if !user.email
            alert "Email address required.  Please enter an email for the account holder and try again."
            return
          if !user.password
            alert "Password is required.  Please enter an email for the account holder and try again."
            return
          if !user.first_name
            alert "First name required.  Please enter an email for the account holder and try again."
            return
          if !user.last_name
            alert "Last name required.  Please enter an email for the account holder and try again."
            return
          if !user.mail_postal
            alert "Zip code is required.  Please enter an email for the account holder and try again."
            return
          user.source = "Dashboard"
          user.needsWelcomeEmail = true
          user.name = "#{user.first_name} #{user.last_name}" if user.first_name or user.last_name
          if user.referredBy?.trim()?.toLowerCase() is $scope.parentUser?.name?.toLowerCase()
            user.parentId = $scope.parentUser._id if $scope.parentUser?._id
            user.parent_clientId = $scope.parentUser.clientId if $scope.parentUser?.clientId
          User.register user, (results) =>
            Storage.set 'token', results.token if results.token
            updateUserSuccess(results.user) if results.user
          , updateUserErr
        else if loginUser
          updateUserSuccess(loginUser)


    #Don't expect to hit this case.
    else
      alert "Before purchasing this item, please login to your account or select to create a new account under the 'Account Holder Information' section above."
      return

  $scope.login = ($event, user, cb) ->
    $event.preventDefault() if $event
    return unless user
    if !user.email
      alert "Email required"
      return
    if !user.password
      alert "Password required"
      return
    user.email = user.email?.toLowerCase()
    result = User.login {email: user.email, password: user.password},
      # success
      (result) =>
        user = result.user
        Storage.set 'user',  result.user
        Storage.set 'token', result.token
        $scope.user = result.user
        $scope.init.call(@) #Need to reset everything (including member pricing) based on logged in user
        $scope.redraw()
        return cb(null, user) if cb
    ,
    # Login Failed
    (res) =>
      if cb
        return cb("Login failed")
      else
        alert "Account not found:  An account was not found for this email and password.  Please try again."

  $scope.allowChecks = () ->
    return true
    if window.tenant._id.toString() is "5684a2fc68e9aa863e7bf182"
      return true
    else
      return false

  $scope.getParentUser = (parentClientId) ->
    return unless parentClientId
    User.getByClientId {clientId: parentClientId}, (user) ->
      $scope.parentUser = user if user
      if !$scope.user.referredBy
        $scope.user.referredBy = $scope.parentUser.name if $scope.parentUser?.name

  $scope.enableReps = (huntCatalog) ->
    $scope.showRep = false
    return unless huntCatalog?.createRep
    repTenants = []
    repTenants.push("5684a2fc68e9aa863e7bf182") #RBO
    repTenants.push("5bd75eec2ee0370c43bc3ec7") #RBO
    if window.tenant._id.toString() is "5684a2fc68e9aa863e7bf182" or window.tenant._id.toString() is "5bd75eec2ee0370c43bc3ec7"
      $scope.isRBO = true
    if window.tenant._id.toString() in repTenants
      $scope.showRep = true
    else
      $scope.showRep = false

  $scope.getAddress = (user) ->
    return user.physical_address if user?.physical_address
    return user.mail_address if user?.mail_address

  $scope.getCity = (user) ->
    return user.physical_city if user?.physical_city
    return user.mail_city if user?.mail_city

  $scope.getState = (user) ->
    return user.physical_state if user?.physical_state
    return user.mail_state if user?.mail_state

  $scope.getZip = (user) ->
    return user.physical_postal if user?.physical_postal
    return user.mail_postal if user?.mail_postal

  $scope.toggleOptOut = (type, opt_out) ->
    if opt_out
      $scope.huntCatalog.paymentPlan = "full"
      $scope.purchaseItem.opt_out_subscription = true
    else if !opt_out and type is "yearly"
      $scope.huntCatalog.paymentPlan = "subscription_yearly"
      delete $scope.purchaseItem.opt_out_subscription
    else if !opt_out and type is "monthly"
      $scope.huntCatalog.paymentPlan = "subscription_monthly"
      delete $scope.purchaseItem.opt_out_subscription

  $scope.init.call(@)
])
