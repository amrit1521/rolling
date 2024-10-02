APP = window.APP
APP.Controllers.controller('AdminRemindersOld', ['$scope', 'Reminder', 'State', 'User', 'DrawResult', '$modal', ($scope, Reminder, State, User, DrawResult, $modal) ->
  $scope.init = ->
    $scope.loadActive()
    $scope.states = State.stateList
    $scope.cellCarriers = ['at&t', 'verizon', 'cricket', 'sprint', 't-mobile', 'uscc', 'fido', 'alltel', 'nextel', 'tracfone', 'telus', 'boost_cdma', 'wind', 'bellmobility', 'virgin_mobile'];
    $scope.testUsersOptions = []
    $scope.testDrawOptions = []
    $scope.getTestUsers()

  $scope.addReminder = ($event) ->
    $event.preventDefault()
    $scope.reminders.push {editing: true}

  $scope.cancel = (reminder) ->
    reminder.editing = false
    $scope._removeReminder reminder if not reminder._id

  $scope.delete = (reminder) ->
    if confirm 'Are you sure you want to delete the reminder titled: ' + reminder.title
      Reminder.delete _.pick(reminder, '_id'), ->
        $scope._removeReminder reminder

  $scope.test = (reminder) ->
    if !reminder.testUserId
      alert 'A test email address or test cell number has not be configured for this reminder.  Please edit the reminder and run the test again.'
      return
    if !reminder.testDrawResultId and (reminder.isDrawResultSuccess or reminder.isDrawResultUnsuccess)
      alert 'A test draw result has not be configured for this reminder.  Please edit the reminder and run the test again.'
      return
    else
      handleRsp = () ->
        Reminder.byId _.pick(reminder, '_id')
        , (rsp) ->
          $scope.updateReminder rsp.reminder
          if rsp.reminder.testLastMsg and rsp.reminder.testLastMsg.length > 0
            alert(rsp.reminder.testLastMsg)
          else
            alert("Reminder test sent.")
        , (err) ->
          alert("Error sending reminder test." + err)

      result = Reminder.test reminder
      , ->
        if result.results?.length and result.results[0] and result.results[0].status is "sent" and result.results[0].reject_reason is null
          alert("Test successful. Result status: " + result.results[0].status)
        else
          alert("Test failed. Result: " + JSON.stringify(result))
      , (err) ->
        console.log "Test failed with: result: ", result
        console.log "Test failed with: err: ", err

  $scope.send = (reminder) ->
    console.log "reminder:", reminder
    window.location = "#!/admin/reminders/send/#{reminder._id}"

  $scope.edit = (reminder) ->
    reminder.editing = true
    $scope.getTestDraws(reminder)

  $scope._removeReminder = (data) ->
    for reminder, key in $scope.reminders
      if reminder.$$hashKey is data.$$hashKey
        $scope.reminders.splice key, 1
        break

    $scope.redraw()

  $scope.save = (reminder) ->
    reminder.saving = true
    reminder.editing = false
    data = reminder
    data.start = moment(data.start).format('YYYY-MM-DD')
    data.end = moment(data.end).format('YYYY-MM-DD')
    result = Reminder.save data
      , ->
        cResult = _.pick result, '_id', 'end', 'start', 'state', 'title'

        reminder.saving = false
        _.extend reminder, cResult
      , ->
        alert('Error occured while saving')
        reminder.saving = false
        reminder.editing = true

  $scope.loadAll = ->
    Reminder.adminIndex(
      {all:true}
      (res) ->
        $scope.reminders = res.reminders
        $scope.reminders.forEach (reminder) ->
          reminder.start = moment(reminder.start, 'YYYY-MM-DD').toDate()
          reminder.end = moment(reminder.end, 'YYYY-MM-DD').toDate()
      (res) ->
        $scope.reminders = []
        alert 'unable to get reminders'
    )

  $scope.loadActive = ->
    Reminder.adminIndex(
      (res) ->
        $scope.reminders = res.reminders
        $scope.reminders.forEach (reminder) ->
          reminder.start = moment(reminder.start, 'YYYY-MM-DD').toDate()
          reminder.end = moment(reminder.end, 'YYYY-MM-DD').toDate()
      (res) ->
        $scope.reminders = []
        alert 'unable to get reminders'
    )

  $scope.showAll = ->
    if $scope.viewMode
      # show all
      $scope.loadAll()
    else
      # show active
      $scope.loadActive()

  $scope.getTestUsers = () ->
    User.testUsers {tenantId: $scope.tenant._id}, (rsp) ->
      #success
      for testUser in rsp
        testUser.displayName = "#{testUser.first_name} #{testUser.last_name}"
        testUser.displayName += " - #{testUser.clientId}" if testUser.clientId
      $scope.testUsersOptions = rsp
    ,
      (err) ->
        console.log "Failed to get list of test users. Error: ", err


  $scope.getTestDraws = (reminder) ->
    return unless reminder.isDrawResultSuccess or reminder.isDrawResultUnsuccess
    if reminder.isDrawResultSuccess and reminder.isDrawResultUnsuccess
      statusType = "all"
    else if reminder.isDrawResultSuccess
      statusType = "successful"
    else if reminder.isDrawResultUnsuccess
      statusType = "unsuccessful"
    else
      return

    DrawResult.report {state: reminder.state, type: statusType}, (rsp) ->
      #success
      testDrawOptions = []
      uniqueOptions = []
      for drawresult in rsp
        drawresult.displayName = "#{drawresult.name} (#{drawresult.status})"
        drawresult.displayName += " - #{drawresult.unit}" if drawresult.unit
        if not uniqueOptions[drawresult.displayName]
          testDrawOptions.push drawresult
          uniqueOptions[drawresult.displayName] = drawresult
      $scope.testDrawOptions = testDrawOptions
      $scope.redraw()
    ,
      (err) ->
        console.log "Failed to get list of draw results. Error: ", err

  $scope.updateReminder = (updatedReminder) ->
    for reminder in $scope.reminders
      if reminder._id is updatedReminder._id
        reminder.testLastMsg = updatedReminder.testLastMsg
        break

  $scope.init.call(@)
])
