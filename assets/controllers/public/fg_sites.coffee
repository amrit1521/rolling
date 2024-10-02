APP = window.APP
APP.Controllers.controller('FGSites', ['$scope', 'State', ($scope, State) ->
  $scope.init = ->
    $scope.states = State.index()

  $scope.init.call(@)
])
