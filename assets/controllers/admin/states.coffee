APP = window.APP
APP.Controllers.controller('AdminStates', ['$scope', 'State', ($scope, State) ->
  $scope.init = ->
    $scope.states = State.adminIndex()

  $scope.init.call(@)
])
