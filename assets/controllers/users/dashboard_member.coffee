APP = window.APP
APP.Controllers.controller('MemberDashboard', ['$scope', '$rootScope', '$routeParams', '$location', 'Storage', 'User', ($scope, $rootScope, $routeParams, $location, Storage, User) ->
  $scope.states = []
  $scope.application = {
    hunts: []
  }

  $scope.init = ->
    $scope.user = Storage.get 'user'
    return unless $scope?.user?._id
    $scope.parent = null
    $scope.setParentAndRep($scope.user._id)

  $scope.getMemberDashboard = ->
    if tenant._id.toString() is '5bd75eec2ee0370c43bc3ec7'
      return "www.verdadtech.com"
    else
      window.location = "#!/dashboard"

  $scope.setParentAndRep = (userId) ->
    results = User.getParentAndRep {userId: userId}, () ->
      $scope.parent = parent if results.parent._id


  $scope.init.call(@)
])
