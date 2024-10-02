APP = window.APP
APP.Controllers.controller('HuntEdit', ['$scope', '$routeParams', 'Hunt', 'State', ($scope, $routeParams, Hunt, State) ->

  $scope.init = ->
    console.log "$routeParams:", $routeParams
    $scope.stateId = $routeParams.stateId
    $scope.fileName = $routeParams.file
    $scope.huntName = $routeParams.name
    state = State.get {id: $scope.stateId}, ->
      $scope.state = state
      $scope.huntTemplate = "templates/hunts/states/#{$scope.state.name.toLowerCase()}/#{$scope.fileName}.html"

  $scope.back = ($event) ->
    $event.preventDefault()
    window.history.back()

  $scope.init.call(@)
])
