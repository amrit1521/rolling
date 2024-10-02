APP = window.APP
APP.Controllers.controller('AdminHuntCatalog', ['$scope', '$rootScope', '$location', '$routeParams', '$sce', 'Storage', 'HuntCatalog', 'State', 'User', '$modal', 'Search', ($scope, $rootScope, $location, $routeParams, $sce, Storage, HuntCatalog, State, User, $modal, Search) ->

  $scope.init = () ->
    $scope.user = Storage.get 'user'
    $scope.huntCatalog = null
    $scope.isNew = false
    $scope.needInitUI = true
    $scope.allowAddMedia = false
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.nomPerent = .10
    $scope.fee_percentage = 0
    $scope.outfitters = null
    $scope.outfitter = null
    $scope.showRep = false
    $scope.enableReps()
    $scope.enableFullCheck()
    $scope.status = [
      { name: "On Hold", value: "hold" }
      { name: "Available", value: "available" }
      { name: "Sold", value: "sold" }
      { name: "Archived", value: "archived" }
      { name: "Need more info", value: "need more info" }
      { name: "Ready for review", value: "ready for review" }
    ]
    $scope.huntCatalogTypes = [
      { name: "Membership", value: "membership" }
      { name: "Rifle", value: "rifle" }
      { name: "Hunt", value: "hunt" }
      { name: "Product", value: "product" }
    ]
    #if window?.tenant?._id?.toString() is "5684a2fc68e9aa863e7bf182" #RBO
    $scope.huntCatalogTypes.push { name: "Precision Shooting Course", value: "course" }
    $scope.huntCatalogTypes.push { name: "Adventure Advisor", value: "specialist" }
    $scope.huntCatalogTypes.push { name: "Advertising", value: "advertising" }

    $scope.paymentPlans = [
      { name: "Hunt Amortized", value: "hunt" }
      { name: "Full Payment Required", value: "full" }
      { name: "6,12,18 Months", value: "months" }
      { name: "Monthly Subscription", value: "subscription_monthly" }
      { name: "Yearly Subscription", value: "subscription_yearly" }
    ]

    if $scope.user?.isAdmin || $scope.user?.userType == 'tenant_manager'
      $scope.getOutfitters()
      $scope.loadHuntCatalog($routeParams.id)
    else
      alert "Unauthorized error"

  $scope.getOutfitters = () ->
    $scope.loadingHuntCatalog = true;
    search = {
      type: "name"
      text: ""
      parentId: null
      outfitters: true
    }
    results = Search.find search, ->
      for result in results
        result.name = result.first_name + ' ' + result.last_name if not result.name and result.first_name and result.last_name
        result.nameLink = "<a href=#{'"'}#!/admin/outfitter/#{result._id}#{'"'}>#{result.name}</a>"
      $scope.outfitters = results
      $scope.calcCommissionAmounts() if $scope.huntCatalog and !$scope.huntCatalog.rbo_commission
    , (err) ->
      console.log "outfitter search error:", err

  $scope.loadHuntCatalog = (huntCatalogId) ->
    $scope.loadingHuntCatalog = true;
    if huntCatalogId is "new"
      $scope.isNew = true
      $scope.huntCatalog = new HuntCatalog()
      $scope.huntCatalog.createdAt = new Date()
      $scope.huntCatalog.isActive = false
      $scope.huntCatalog.status = "need more info"
      $scope.huntCatalog.memberDiscount = true

      $scope.loadingHuntCatalog = false;

    else
      setHuntCatalog = (results) ->
        $scope.huntCatalog = results
        $scope.initUI($scope.huntCatalog) if $scope.needInitUI
        $scope.needInitUI = false
        $scope.huntCatalog.startDate = new Date($scope.huntCatalog.startDate)
        $scope.huntCatalog.endDate = new Date($scope.huntCatalog.endDate)
        startDateStr = "#{$scope.huntCatalog.startDate.getMonth()+1}/#{$scope.huntCatalog.startDate.getDate()}/#{$scope.huntCatalog.startDate.getFullYear()}"
        endDateStr = "#{$scope.huntCatalog.endDate.getMonth()+1}/#{$scope.huntCatalog.endDate.getDate()}/#{$scope.huntCatalog.endDate.getFullYear()}"
        #$scope.huntCatalog.budgetRange = "$#{$scope.huntCatalog.budgetStart} - $#{$scope.huntCatalog.budgetEnd}"
        if !$scope.huntCatalog.price_total and $scope.huntCatalog.price
          $scope.huntCatalog.price_total = $scope.huntCatalog.price
        if !$scope.huntCatalog.fee_processing
          $scope.huntCatalog.fee_processing = 0
        $scope.huntCatalog.priceStr = ""
        $scope.huntCatalog.priceStr = ""
        $scope.huntCatalog.priceStr = "$#{$scope.formatMoneyStr($scope.huntCatalog.price)}" if $scope.huntCatalog.price
        $scope.huntCatalog.price_nom = $scope.huntCatalog.fee_processing + $scope.huntCatalog.price + ($scope.huntCatalog.price * $scope.nomPerent) if $scope.huntCatalog.price
        $scope.huntCatalog.price_nomStr = "$#{$scope.formatMoneyStr($scope.huntCatalog.price_nom)}" if $scope.huntCatalog.price_nom
        $scope.huntCatalog.dateRange = "#{startDateStr} - #{endDateStr}"
        if $scope.huntCatalog.huntSpecialMessage
          $scope.huntCatalog.huntSpecialMessageAsHTML = $scope.huntCatalog.huntSpecialMessage.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.huntCatalog.huntSpecialMessageAsHTML = $sce.trustAsHtml($scope.huntCatalog.huntSpecialMessageAsHTML);
        if $scope.huntCatalog.description
          $scope.huntCatalog.descriptionAsHTML = $scope.huntCatalog.description.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.huntCatalog.descriptionAsHTML = $sce.trustAsHtml($scope.huntCatalog.descriptionAsHTML);
        if $scope.huntCatalog.pricingNotes
          $scope.huntCatalog.pricingNotesAsHTML = $scope.huntCatalog.pricingNotes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
          $scope.huntCatalog.pricingNotesAsHTML = $sce.trustAsHtml($scope.huntCatalog.pricingNotesAsHTML);
        $scope.calcCommissionAmounts() if $scope.outfitters?.length and !$scope.huntCatalog.rbo_commission
        $scope.loadingHuntCatalog = false;
        $scope.allowAddMedia = true

      if $scope.user.isAdmin or $scope.user?.userType == 'tenant_manager'
        HuntCatalog.adminRead {id: huntCatalogId}, (results) ->
          setHuntCatalog(results)
        , (err) ->
          if err?.data
            alert "loading hunt catalog error: " + err.data
          else
            alert "loading hunt catalog error"
          $scope.loadingHuntCatalog = false;
          window.location = "/#!/dashboard"


  $scope.validate = (huntCatalog) ->
    valid = true
    messages = []

    if huntCatalog.rbo_commission < huntCatalog.rbo_reps_commission
      valid = false
      messages.push "Reps Commission Amount cannot be greater than the Commission to RBO amount."

    if !huntCatalog.status
      messages.push "Status is required."
    if !huntCatalog.type
      messages.push "Type is required."
    if !huntCatalog.paymentPlan
      messages.push "Payment Plan is required."
    if !huntCatalog.huntNumber
      messages.push "Hunt Catalog Number is required."
    if !huntCatalog.title
      messages.push "Title is required."
    if !huntCatalog.outfitter_userId
      messages.push "Outfitter/Vendor assignment is required."
    if huntCatalog.price is null
      messages.push "Price is required."
    if huntCatalog.price_total is null
      messages.push "Total Price is required."
    if huntCatalog.rbo_commission  is null
      messages.push "Commission amount to RBO is required."
    if huntCatalog.rbo_reps_commission is null
      messages.push "Commission amount to Reps is required."
    if huntCatalog.fee_processing is null
      messages.push "Processing fee amount is required."

    valid = false if messages.length

    messageStr = ""
    for message in messages
      messageStr = messageStr + message + "\n"
    alert messageStr unless valid
    return valid

  $scope.submit = (huntCatalog) ->
    error = (res) ->
      if res?.data?.error
        alert(res.data.error)
      else
        alert "An error occurred while saving"

    escapeRegExp = (str) ->
      str.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1")

    replaceAll = (str, find, replace) ->
      str.replace(new RegExp(escapeRegExp(find), 'g'), replace);

    updateSuccess = (result) ->
      huntCatalog = _.omit result, '__v', '$promise', '$resolved'
      $scope.huntCatalog = huntCatalog
      $scope.redraw()
      alert 'Hunt Catalog item saved successfully.'
      if $scope.user.isAdmin || $scope.user?.userType == 'tenant_manager'
        window.location = "#!/admin/huntcatalogs"
      else
        window.location = "/#!/dashboard"

    #validate data
    if $scope.validate($scope.huntCatalog)
      #update/insert Hunt Catalog
      $scope.huntCatalog.tenantId = $scope.user.tenantId
      data = _.omit $scope.huntCatalog, '__v', '$promise', '$resolved'
      HuntCatalog.adminUpdate data, updateSuccess, error

  $scope.sendEmail = ($event, huntCatalog) ->
    $event.preventDefault()
    resumeCb = (err, results) ->
      console.log "Back from modal with err, results:", err, results

    modal = $modal.open
      templateUrl: 'templates/partials/huntcatalog_email.html'
      controller: 'HuntCatalogEmail'
      resolve: {
        huntCatalog: -> return huntCatalog
        currentUser: -> return $scope.user
        resumeCb: -> return resumeCb
      }
      scope: $scope

    modal.result.then (results) ->
      console.log "modal end1", results
    , (err) ->
      console.log "modal end2", err



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
    window.location = "#!/admin/huntcatalogs"


  $scope.initUI = (huntCatalog) ->

    huntCatalogId = huntCatalog._id if huntCatalog
    files = []
    if huntCatalog.media?.length
      for media in huntCatalog.media
        file = media
        file.name = media.originalName
        files.push file

    getFileInfo = (e) ->
      $.map(e.files, (file) ->
        info = file.name
        # File size is not available in all browsers
        if file.size > 0
          info += ' (' + Math.ceil(file.size / 1024) + ' KB)'
        info
      ).join ', '

    onSelect = (e) ->
      console.log 'Select :: ' + getFileInfo(e)
      return

    onUpload = (e) ->
      console.log 'Upload :: ' + getFileInfo(e)
      return

    onSuccess = (e) ->
      console.log 'Success (' + e.operation + ') :: ' + getFileInfo(e)
      $scope.loadHuntCatalog($scope.huntCatalog._id) if $scope.huntCatalog._id
      return

    onError = (e) ->
      console.log 'Error (' + e.operation + ') :: ' + getFileInfo(e)
      return

    onComplete = (e) ->
      console.log 'Complete'
      return

    onCancel = (e) ->
      console.log 'Cancel :: ' + getFileInfo(e)
      return

    onRemove = (e) ->
      console.log 'Remove :: ' + getFileInfo(e)
      return

    onProgress = (e) ->
      console.log 'Upload progress :: ' + e.percentComplete + '% :: ' + getFileInfo(e)
      return

    apitoken = "EgWiJixOwcemGuegUbitOudsishpyoshVafApDyovrypDyajboofjenekshecfecBeileds1olMywejnewcelfoarmejGhotteiptOowJatJenVemyor2SlujPavfalyiegyincyRyirDowsobCacceskUryowtUnadTehijfersetajortabhotorweuncatkafBinUtlagsirakWavegteorUzHeObJethDycsobBesutjocwentym"
    saveUrl = "admin/huntcatalog/mediaAdd/#{huntCatalogId}/#{apitoken}"
    removeUrl = "admin/huntcatalog/mediaRemove/#{huntCatalogId}/#{apitoken}"
    angular.element('#files').kendoUpload
      async:
        saveUrl: saveUrl
        removeUrl: removeUrl
        autoUpload: false
      dropZone: ".dropZone"
      cancel: onCancel
      complete: onComplete
      error: onError
      progress: onProgress
      remove: onRemove
      select: onSelect
      success: onSuccess
      upload: onUpload
      files: files if files
      validation: {
        maxFileSize: 10485760 #10MB
      }


  $scope.statusChanged = (newStatus) ->
    if newStatus is "available" and !$scope.enableFull
      alert "Marking this hunt catalog item ready to be reviewed.  Once reviewed, it will be made available for customers to purchase."
      if !$scope.enableFull
        newStatus = "ready for review"
        $scope.huntCatalog.status = newStatus
    if newStatus is "available" or newStatus is "sold"
      $scope.huntCatalog.isActive = true
    else
      $scope.huntCatalog.isActive = false

  $scope.updatePrice = (huntCatalog) ->

    $scope.fee_percentage = 0 if huntCatalog.type is "membership" or huntCatalog.type is "specialist"

    if huntCatalog.price
      $scope.huntCatalog.fee_processing = $scope.roundCurrency(huntCatalog.price * $scope.fee_percentage / 100)
      $scope.huntCatalog.price_total = huntCatalog.price + $scope.huntCatalog.fee_processing
      if huntCatalog.memberDiscount
        $scope.huntCatalog.price_nom = $scope.huntCatalog.fee_processing + huntCatalog.price + (huntCatalog.price * $scope.nomPerent)
        $scope.huntCatalog.price_nom = $scope.roundCurrency $scope.huntCatalog.price_nom
      else
        $scope.huntCatalog.price_nom = $scope.huntCatalog.price_total
      $scope.calcCommissionAmounts(null, huntCatalog.price, true)

  $scope.updateProcessingFee = (huntCatalog) ->
    $scope.huntCatalog.price_total = huntCatalog.price + huntCatalog.fee_processing

  $scope.outfitterChanged = (huntCatalog) ->
    if huntCatalog.outfitter_userId
      for outfitter in $scope.outfitters
        if outfitter._id is huntCatalog.outfitter_userId
          $scope.outfitter = outfitter
          huntCatalog.outfitter_name = outfitter.name
          $scope.calcCommissionAmounts(outfitter.commission, huntCatalog.price, true) if outfitter.commission and huntCatalog.price
          break

  $scope.calcCommissionAmounts = (outfitterPercentage, price, reCalulate) ->
    for outfitter in $scope.outfitters
      if outfitter._id is $scope.huntCatalog.outfitter_userId
        $scope.outfitter = outfitter
        break

    if !outfitterPercentage and $scope.huntCatalog.outfitter_userId
      outfitterPercentage = $scope.outfitter.commission

    if !price and $scope.huntCatalog.price
      price = $scope.huntCatalog.price

    #calculate RBO commission amount
    if reCalulate or $scope.huntCatalog.rbo_commission is null
      if outfitterPercentage and price
        $scope.huntCatalog.rbo_commission = price * (outfitterPercentage / 100)

      if $scope.huntCatalog.rbo_commission
        $scope.huntCatalog.rbo_commission = $scope.roundCurrency $scope.huntCatalog.rbo_commission

    #calculate RBO REP amount
    if reCalulate or $scope.huntCatalog.rbo_reps_commission is null
      switch $scope.huntCatalog.type
        when "specialist"
          $scope.huntCatalog.rbo_reps_commission = 0
        when "membership"
          $scope.huntCatalog.rbo_reps_commission = 75
        when "rifle"
          $scope.huntCatalog.rbo_reps_commission = 1100
        when "course"
          $scope.huntCatalog.rbo_reps_commission = 400
        when "advertising"
          $scope.huntCatalog.rbo_reps_commission = price * (20 / 100)
        when "product"
          $scope.huntCatalog.rbo_reps_commission = $scope.huntCatalog.rbo_commission * (35 / 100)
        when "hunt"
          #15% comm is split into 7% Sales, 6% RBO, 2% Overrides.    <10% split into 5% Sales, 4% RBO, and 1% Overrides
          if $scope.outfitter?.commission >= 15
            $scope.huntCatalog.rbo_reps_commission = price * (7 / 100)
          else
            $scope.huntCatalog.rbo_reps_commission = price * (4 / 100)

    if $scope.huntCatalog.rbo_commission <= 0
      $scope.huntCatalog.rbo_reps_commission = 0

    $scope.huntCatalog.rbo_reps_commission = Math.round($scope.huntCatalog.rbo_reps_commission * 100) / 100 if $scope.huntCatalog?.rbo_reps_commission


  $scope.editOutfitter = ($event, huntCatalog) ->
    $event.preventDefault()
    if huntCatalog.outfitter_userId
      window.location = "#!/admin/outfitter/#{huntCatalog.outfitter_userId}"
    else
      alert "Please select an outfitter"

  $scope.productMarginRep = (huntCatalog) ->
    if huntCatalog.type is "product"
      $scope.huntCatalog.rbo_reps_commission = huntCatalog.rbo_commission * (35 / 100)
      $scope.huntCatalog.rbo_reps_commission = Math.round($scope.huntCatalog.rbo_reps_commission * 100) / 100 if $scope.huntCatalog?.rbo_reps_commission

  $scope.switchToPurchaseView = ($event) ->
    $event.preventDefault()
    window.location = "#!/huntcatalog/#{$scope.huntCatalog._id}"

  $scope.roundCurrency = (amount) ->
    return (Math.round (amount*100)) / 100

  $scope.enableReps = ->
    repTenants = []
    repTenants.push("54a8389952bf6b5852000007") #GotMyTagDev
    repTenants.push("5684a2fc68e9aa863e7bf182") #Rolling Bones
    repTenants.push("5bd75eec2ee0370c43bc3ec7") #Now for testing
    if $scope?.user?.tenantId and ($scope.user.tenantId in repTenants or $scope.user.tenantId.toString() in repTenants)
      $scope.showRep = true
    else if $scope.user?.isAdmin and !$scope.user?.tenantId
      $scope.showRep = true
    else
      $scope.showRep = false

  $scope.enableFullCheck = ->
    if $scope.user?.isAdmin and $scope.user?.userType is "super_admin"
      $scope.enableFull = true
    else
      $scope.enableFull = false

  $scope.init.call(@)
])
