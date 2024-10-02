APP = window.APP
APP.Controllers.controller('FGOdds', ['$scope', 'State', ($scope, State) ->
  $scope.init = ->
    $scope.states = State.index()

  $scope.init.call(@)
])
