APP = window.APP
APP.Controllers.controller('RepDashboard', ['$scope', '$rootScope', '$routeParams', '$location', 'Storage', 'User', ($scope, $rootScope, $routeParams, $location, Storage, User) ->
  $scope.states = []
  $scope.application = {
    hunts: []
  }

  $scope.init = ->
    $scope.user = Storage.get 'user'
    return unless $scope?.user?._id
    $scope.parent = null

  $scope.getRepDashboard = ->
    if tenant._id.toString() is '5684a2fc68e9aa863e7bf182' or tenant._id.toString() is '5bd75eec2ee0370c43bc3ec7'
      return "templates/custom/rbo/dashboard_rep.html"
    else
      window.location = "#!/dashboard"

  $scope.setParentAndRep = (userId) ->
    results = User.getParentAndRep {userId: userId}, () ->
      $scope.parent = parent if results.parent._id


  $scope.init.call(@)
])
