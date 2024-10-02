APP = window.APP
APP.Controllers.controller('HuntCatalog', ['$scope', '$rootScope', '$location', '$routeParams', '$sce', 'Storage', 'HuntCatalog', 'State', 'User', '$modal', 'Search', ($scope, $rootScope, $location, $routeParams, $sce, Storage, HuntCatalog, State, User, $modal, Search) ->

  $scope.init = () ->
    $scope.user = Storage.get 'user'
    $scope.parentClientId = $routeParams.ref
    $scope.website = $routeParams.website
    $scope.huntCatalog = null
    $scope.needInitUI = true

    $scope.loadHuntCatalog($routeParams.id)


  $scope.loadHuntCatalog = (huntCatalogId) ->
    $scope.loadingHuntCatalog = true;

    setHuntCatalog = (results) ->
      $scope.huntCatalog = results
      $scope.initUI($scope.huntCatalog) if $scope.needInitUI
      $scope.needInitUI = false
      $scope.huntCatalog.startDate = new Date($scope.huntCatalog.startDate)
      $scope.huntCatalog.endDate = new Date($scope.huntCatalog.endDate)
      startDateStr = "#{$scope.huntCatalog.startDate.getMonth()+1}/#{$scope.huntCatalog.startDate.getDate()}/#{$scope.huntCatalog.startDate.getFullYear()}"
      endDateStr = "#{$scope.huntCatalog.endDate.getMonth()+1}/#{$scope.huntCatalog.endDate.getDate()}/#{$scope.huntCatalog.endDate.getFullYear()}"
      #$scope.huntCatalog.budgetRange = "$#{$scope.huntCatalog.budgetStart} - $#{$scope.huntCatalog.budgetEnd}"
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


      $scope.loadingHuntCatalog = false;

    HuntCatalog.read {id: huntCatalogId}, (results) ->
      setHuntCatalog(results)
    , (err) ->
      console.log "loading hunt catalog error:", err
      alert "Item not found."
      $scope.loadingHuntCatalog = false;
      $scope.cancel


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
    if $scope.website
      location = "https://www.rollingbonesoutfitters.com/hunt-catalog/?website=true"
      if $scope.parentClientId
        location = "#{location}&ref=#{$scope.parentClientId}"
    else
      if $scope.parentClientId
        location = "#!/huntcatalogs?ref=#{$scope.parentClientId}"
      else
        location = "#!/huntcatalogs"

    return window.location = location

  $scope.purchase = ($event, huntCatalog) ->
    $event.preventDefault()
    if huntCatalog._id
      if $scope.parentClientId
        location = "#!/huntcatalog/purchase/#{huntCatalog._id}?ref=#{$scope.parentClientId}"
      else
        location = "#!/huntcatalog/purchase/#{huntCatalog._id}"
      if $scope.website and $scope.parentClientId
        location = "#{location}&website=#{$scope.website}"
      else if $scope.website and !$scope.parentClientId
        location = "#{location}?website=#{$scope.website}"
      return window.location = location
    else
      alert "An item to purchase was not selected.  Please select and item first and then try again."

  $scope.initUI = (huntCatalog) ->

    huntCatalogId = huntCatalog._id if huntCatalog
    files = []
    if huntCatalog.media?.length
      for media in huntCatalog.media
        file = media
        file.name = media.originalName
        files.push file

  $scope.init.call(@)
])
