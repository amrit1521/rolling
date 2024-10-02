APP = window.APP
APP.Controllers.controller('ServiceRequest', ['$scope', '$rootScope', '$location', '$routeParams', 'Storage', 'ServiceRequest', ($scope, $rootScope, $location, $routeParams, Storage, ServiceRequest) ->

  $scope.init = () ->
    $scope.user = Storage.get 'user'
    $scope.serviceTypes = [
      { name: "Hunting Opportunities", value: "Request Hunt Info" }
      { name: "Concierge Services", value: "Support" }
      { name: "Technical Support", value: "Technical Support" }
    ]
    if $scope.user.isAdmin
      $scope.serviceTypes.push {name: "Purchase", value: "Purchase"}

    $scope.serviceSources = [
      { name: "Hunting Rep", value: "Sales Rep" }
      { name: "TV Show", value: "TV Show" }
      { name: "Sportsman Expo/Show", value: "Sportsman Expo/Show" }
      { name: "Web", value: "Web" }
    ]
    $scope.serviceBudgets = [
      { value: "2000", name: "$0 - $2,000" }
      { value: "4000", name: "$2,000 - $4,000" }
      { value: "6000", name: "$4,000 - $6,000" }
      { value: "10000", name: "$6,000 - $10,000" }
      { value: "15000", name: "$10,000 - $15,000" }
      { value: "30000", name: "$15,000 - $30,000" }
      { value: "unlimited", name  : "$30,000+" }
    ]
    $scope.serviceStatus = [
      { name: "Waiting for client to respond", value: "waiting on client" }
      { name: "Closed", value: "closed" }
    ]

    $scope.serviceRequest = null
    $scope.isNewRequest = false
    $scope.loadServiceRequest($routeParams.id)

  $scope.loadServiceRequest = (serviceRequestId) ->
    $scope.loadingServiceRequest = true;
    if serviceRequestId is "new"
      $scope.isNewRequest = true
      if $scope.user.physical_address
        address = $scope.user.physical_address
        city = $scope.user.physical_city
        country = $scope.user.physical_country
        postal = $scope.user.physical_postal
        state = $scope.user.physical_state
      else if $scope.user.mail_address
        address = $scope.user.mail_address
        city = $scope.user.mail_city
        country = $scope.user.mail_country
        postal = $scope.user.mail_postal
        state = $scope.user.mail_state
      phone = null
      if $scope.user.phone_cell
        phone = $scope.user.phone_cell
      else if $scope.user.phone_home
        phone = $scope.user.phone_home
      else if $scope.user.phone_day
        phone = $scope.user.phone_day
      phone = phone.split(".")[0] if phone

      $scope.serviceRequest = new ServiceRequest()
      $scope.serviceRequest.userId = $scope.user._id
      $scope.serviceRequest.tenantId = $scope.user.tenantId
      $scope.serviceRequest.clientId = $scope.user.clientId
      $scope.serviceRequest.memberId = $scope.user.memberId
      $scope.serviceRequest.tenantId = $scope.user.tenantId
      $scope.serviceRequest.first_name = $scope.user.first_name
      $scope.serviceRequest.last_name = $scope.user.last_name
      $scope.serviceRequest.address = address
      $scope.serviceRequest.city = city
      $scope.serviceRequest.country = country
      $scope.serviceRequest.postal = postal
      $scope.serviceRequest.state = state
      $scope.serviceRequest.email = $scope.user.email
      $scope.serviceRequest.phone = phone
      $scope.serviceRequest.external_date_created = new Date()

      $scope.loadingServiceRequest = false;

    else
      result = ServiceRequest.adminRead {id: serviceRequestId}, (results) ->
        result.lastFollowedUpAt = new Date(result.lastFollowedUpAt) if result.lastFollowedUpAt
        result.purchase_hunt.depositReceived = new Date(result.purchase_hunt.depositReceived) if result.purchase_hunt?.depositReceived
        result.purchase_hunt.client_doc_sent = new Date(result.purchase_hunt.client_doc_sent) if result.purchase_hunt?.client_doc_sent
        result.purchase_hunt.outfitter_doc_sent = new Date(result.purchase_hunt.outfitter_doc_sent) if result.purchase_hunt?.outfitter_doc_sent
        result.purchase_hunt.outfitter_payment_sent = new Date(result.purchase_hunt.outfitter_payment_sent) if result.purchase_hunt?.outfitter_payment_sent
        $scope.serviceRequest = result
        $scope.loadingServiceRequest = false;
      , (err) ->
        console.log "loading service request errored:", err
        $scope.loadingServiceRequest = false;

  $scope.submit = (serviceRequest) ->
    error = (res) ->
      if res?.data?.error
        alert(res.data.error)
      else
        alert "An error occurred while savingfff"

    updateServiceRequestSuccess = (result) ->
      serviceRequest = _.omit result, '__v', '$promise', '$resolved'
      $scope.serviceRequest = serviceRequest
      $scope.redraw()
      alert 'Service Request saved successfully.'
      if $scope.user.isAdmin
        window.location = "#!/admin/servicerequests"
      else
        window.location = "/#!/dashboard"


    #update/insert Service Request
    if $scope.isNewRequest
      serviceRequestData = _.omit $scope.serviceRequest, '__v', '$promise', '$resolved'
      ServiceRequest.adminUpdate serviceRequestData, updateServiceRequestSuccess, error
    else
      $scope.promptSaveNote null, (err, note) ->
        if err
          alert err
          console.log "Save was cancelled"
          return
        else if note
          serviceRequestData = _.omit $scope.serviceRequest, '__v', '$promise', '$resolved'
          ServiceRequest.adminUpdate serviceRequestData, updateServiceRequestSuccess, error
        else
          alert "When saving a Service Request, a note is required."

  $scope.cancel = () ->
    window.location = "#!/admin/servicerequests"

  $scope.statusChanged = (newStatus) ->
    if newStatus is "closed"
      $scope.serviceRequest.needsFollowup = false
    else
      $scope.serviceRequest.needsFollowup = true


  $scope.promptSaveNote = ($event, cb) ->
    $event.preventDefault() if $event
    now = $scope.formatDate(new Date())
    kendo.prompt("#{$scope.user.name} Note: ", "")
      .then (data) ->
        if !data
          return cb null, data
        note = data
        if $scope.serviceRequest.notes
          $scope.serviceRequest.notes += "\n#{now}, #{$scope.user.name}: #{note}"
        else
          $scope.serviceRequest.notes = "#{now}, #{$scope.user.name}: #{note}"
        return cb null, data

      , () ->
        return cb null, null


  $scope.formatDate = (date) ->
    dformat = [date.getMonth()+1,
      date.getDate(),
      date.getFullYear()].join('/')+' '+
      [date.getHours(),
        date.getMinutes(),
        date.getSeconds()].join(':')
    return dformat

  $scope.addNote = ($event) ->
    $scope.promptSaveNote $event, (err, note) ->
      if err
        alert err
        return
      else
        $scope.redraw()
        return


  $scope.init.call(@)
])
