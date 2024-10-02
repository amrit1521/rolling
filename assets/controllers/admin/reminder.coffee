APP = window.APP
APP.Controllers.controller('AdminReminder', ['$scope', '$rootScope', '$location', '$routeParams', '$sce', 'Storage', 'Reminder', 'State', 'User', '$modal', 'Search', ($scope, $rootScope, $location, $routeParams, $sce, Storage, Reminder, State, User, $modal, Search) ->

  $scope.init = () ->
    $scope.user = Storage.get 'user'
    $scope.reminder = null
    $scope.isNew = false
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.testUsers = []
    $scope.reminderTypes = [
      { name: "Application Deadline", value: "application" }
      { name: "Drawresult Unsuccessful", value: "drawresult_unsuccessful" }
      { name: "Drawresult Successful", value: "drawresult_successful" }
    ]

    if $scope.user?.isAdmin
      $scope.getTestUsers () ->
        $scope.loadReminder($routeParams.id)
    else
      alert "Unauthorized error"

  $scope.loadReminder = (reminderId) ->
    $scope.loadingReminder = true;
    if reminderId is "new"
      $scope.isNew = true
      $scope.reminder = new Reminder()
      $scope.reminder.active = false
      $scope.reminder.reminderType = "application"
      $scope.loadingReminder = false;
      $scope.reminder.tenantId = $scope.user.tenantId

    else
      setReminder = (results) ->
        $scope.reminder = results.reminder
        $scope.reminder.start = moment($scope.reminder.start, 'YYYY-MM-DD').toDate()
        $scope.reminder.end = moment($scope.reminder.end, 'YYYY-MM-DD').toDate()
        if $scope.reminder.send_open
          $scope.reminder.send_open = new Date($scope.reminder.send_open)
        else if $scope.reminder.start
          $scope.reminder.send_open = $scope.reminder.start
        if $scope.reminder.send_close
          $scope.reminder.send_close = new Date($scope.reminder.send_close)
        else if $scope.reminder.end
          $scope.reminder.send_close = $scope.reminder.end
        $scope.reminder.validatedOn = new Date($scope.reminder.validatedOn) if $scope.reminder.validatedOn
        $scope.reminder.tenantId = $scope.user.tenantId unless $scope.reminder.tenantId
        $scope.reminder.reminderType = "application" unless $scope.reminder.reminderType
        $scope.loadingReminder = false;

      if $scope.user.isAdmin
        Reminder.byId {_id: reminderId}, (results) ->
          setReminder(results)
        , (err) ->
          console.log "Loading reminder error: ", err
          if err?.data
            alert "loading reminder error: " + err.data
          else
            alert "loading reminder error"
          $scope.loadingReminder = false;
          window.location = "/#!/admin/reminders"


  $scope.getTestUsers = (cb) ->
    User.testUsers {tenantId: $scope.tenant._id}, (rsp) ->
      #success
      for testUser in rsp
        testUser.displayName = "#{testUser.first_name} #{testUser.last_name}"
        testUser.displayName += " - #{testUser.clientId}" if testUser.clientId
      $scope.testUsers = rsp
      return cb()
    ,
      (err) ->
        console.log "Failed to get list of test users. Error: ", err


  $scope.changeDates = ($event, reminder) ->
    $event.preventDefault() if $event
    reminder.send_open = reminder.start if reminder.start
    reminder.send_close = reminder.end if reminder.end

  $scope.validate = (reminder) ->
    valid = true
    messages = []

    if reminder.active isnt false and reminder.active isnt true
      messages.push "Is Active is required."
    if !reminder.title
      messages.push "Title is required."
    if !reminder.start
      messages.push "Open Date is required."
    if !reminder.end
      messages.push "End Date is required."
    if !reminder.state
      messages.push "State is required."
    if reminder.tenantId is null
      messages.push "Tenant Id is required."
    if reminder.reminderType  is null
      messages.push "Reminder Type is required."
    valid = false if messages.length

    messageStr = ""
    for message in messages
      messageStr = messageStr + message + "\n"
    alert messageStr unless valid
    return valid

  $scope.validateAndSave = ($event, reminder) ->
    $event.preventDefault() if $event
    reminder.validatedOn = new Date()
    $scope.submit($event, reminder)

  $scope.submit = ($event, reminder) ->
    $event.preventDefault() if $event
    error = (res) ->
      if res?.data?.error
        alert(res.data.error)
      else
        alert "An error occurred while saving"

    updateSuccess = (result) ->
      reminder = _.omit result, '__v', '$promise', '$resolved'
      $scope.reminder = reminder
      $scope.redraw()
      alert 'Reminder saved successfully.'
      window.location = "/#!/admin/reminders"

    #validate data
    if $scope.validate(reminder)
      #update/insert Reminder
      data = _.omit reminder, '__v', '$promise', '$resolved'
      Reminder.save data, updateSuccess, error

  $scope.sendTestAndSave = ($event, reminder, saveReminder) ->
    $event.preventDefault() if $event
    $scope.submit($event, reminder) if saveReminder
    if !reminder.testUserId
      alert 'A test email address or test cell number has not be configured for this reminder.  Please edit the reminder and run the test again.'
      return
    if !reminder.testDrawResultId and (reminder.isDrawResultSuccess or reminder.isDrawResultUnsuccess)
      alert 'A test draw result has not be configured for this reminder.  Please edit the reminder and run the test again.'
      return

    result = Reminder.test reminder
    , ->
      if result.status is "sent"
        alert("Test successful. Result status: " + result.status)
      else
        alert("Test failed. Result: " + JSON.stringify(result))
    , (err) ->
      console.log "Test failed with: result: ", result
      console.log "Test failed with: err: ", err

  $scope.send = (reminder) ->
    console.log "reminder:", reminder
    window.location = "#!/admin/reminders/send/#{reminder._id}"

  $scope.cancel = ($event) ->
    $event.preventDefault()
    window.location = "/#!/admin/reminders"




  $scope.init.call(@)
])
