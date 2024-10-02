APP = window.APP
APP.Controllers.controller('UserReminders', ['$scope', '$location', 'Reminder', 'Storage', 'User', ($scope, $location, Reminder, Storage, User) ->
  $scope.init = ->
    $scope.user = Storage.get 'user'
    return $scope.createUser() unless $scope.user

    $scope.getReminders()

  $scope.createUser = ->
    result = User.defaultUser(
      {demo: true}
      ->
        Storage.set 'user',  result.user
        $scope.user = result.user


        Storage.set 'token', result.token
        $scope.redraw()

        $scope.getReminders()
      (res) ->
        if res?.data?.error
          alert(res.data.error)
        else
          console.log "An error occurred while creating user"
    )

  $scope.getReminders = ->
    return unless $scope.user?.reminders?.states?.length

    byStateData = {
      tenantId: $scope.user.tenantId
      states: $scope.user.reminders.states
    }
    byStateData.tenantId = window.tenant._id if $scope.user.isAdmin and !$scope.user.tenantId
    results = Reminder.byStates byStateData, ->
      $scope.reminderStates = []

      tmpReminders = {}

      for reminder in results
        tmpReminders[reminder.state] ?= []
        tmpReminders[reminder.state].push reminder

      for state, reminders of tmpReminders
        $scope.reminderStates.push {
          name: state
          reminders: reminders
        }

      $scope.redraw()

  $scope.showSettings = -> $location.path '/reminders'

  $scope.init.call(@)
])
