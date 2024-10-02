APP = window.APP
APP.Controllers.controller('AdminHuntsEdit', ['$scope', '$routeParams', '$location', 'Hunt', 'State', ($scope, $routeParams, $location, Hunt, State) ->
  $scope.init = ->
    if $routeParams.stateId
      $scope.state = State.adminRead {id: $routeParams.stateId}
    else if $routeParams.id
      $scope.huntId = $routeParams.id
      $scope.hunt = Hunt.adminRead {id: $routeParams.id}, ->
        $scope.state = State.adminRead {id: $scope.hunt.stateId}

  $scope.submit = (hunt) ->
    hunt.stateId = $scope.state._id
    method = 'adminCreate'
    if hunt._id
      method = 'adminUpdate'
    Hunt[method] hunt, ->
      alert 'Hunt saved'
      $location.path '/admin/state/hunts/' + $scope.state._id
      $scope.redraw()

  $scope.init.call(@)
])
