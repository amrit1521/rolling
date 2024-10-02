APP = window.APP
APP.Controllers.controller('HuntsApplication', ['$scope', '$routeParams', 'Hunt', ($scope, $routeParams, Hunt) ->
  $scope.init = ->
    $scope.stateId = $routeParams.stateId

    hunt = Hunt.get $routeParams, ->
      $scope.hunt = hunt

      options = Hunt.options $routeParams, ->
        $scope.options = options

  $scope.init.call(@)
])
