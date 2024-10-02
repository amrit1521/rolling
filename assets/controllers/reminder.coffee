APP = window.APP
APP.Controllers.controller('Reminder', ['$scope', '$location', 'State', 'Storage', 'User', ($scope, $location, State, Storage, User) ->

  $scope.init = ->
    $scope.showHeaderButtons($scope)
    $scope.user = Storage.get 'user'
    console.log "Reminder::init scope.user:", $scope.user
    $scope.reminders = $scope.user.reminders
    states = State.index -> $scope.states = states

  $scope.checkState = ($event, state) ->

    checked = $($event.target).is(':checked')

    if checked
      $scope.user.reminders.states.push state.name unless $scope.inStates(state)
    else
      $scope.user.reminders.states = $scope.user.reminders.states.filter (item) ->
        item isnt state.name

    $scope.redraw()

  $scope.checkType = (type) ->
    $scope.user.reminders.types.push type unless $scope.inTypes(type)
    $scope.redraw()

  $scope.inStates = (state) ->
    return false unless $scope.user?.reminders?.states?.length
    return ~$scope.user.reminders.states.indexOf state.name

  $scope.inTypes = (type) ->
    return false unless $scope.user?.reminders?.types?.length
    return ~$scope.user.reminders.types.indexOf type

  $scope.sanitize = ->
    $scope.user.ssnx = $scope.user.ssn if $scope.user.ssn
    $scope.user.ssn = null

  $scope.submit = ->
    console.log "reminders", $scope.user.reminders
    $scope.user = _.omit $scope.user, '__v', '$promise', '$resolved'
    User.update(

      $scope.user,

      # success
      (res) ->
        user = _.omit res, '__v', '$promise', '$resolved'
        $scope.user = user
        $scope.sanitize()
        Storage.set 'user', user
        $location.path '/dashboard'
      ,

      # err
      (res) ->
        if res?.data?.error
          alert(res.data.error)
        else
          alert "An error occurred while saving"
    )

  $scope.init.call(@)
])
