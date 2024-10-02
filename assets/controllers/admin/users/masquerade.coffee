APP = window.APP
APP.Controllers.controller('AdminUserMasquerade', ['$scope', '$location', '$routeParams', 'Storage', 'User', ($scope, $location, $routeParams, Storage, User) ->

  $scope.init = ->
    console.log "AdminUserMasquerade::init", $routeParams.id
    userId = $routeParams.id

    if userId is 'back'
      $scope.switchBack()
      $location.path '/dashboard'
    else if userId is 'backAdmin'
      $scope.switchBackAdmin()
      $location.path '/dashboard'
    else
      $scope.masquerade userId, (err)->
        alert ("Error occurred switching users.  Please notify info@rollingbonesoutfitters.com with this error. 'Switch User Error': #{err.error}") if err?.error
        alert ("Error occurred switching users.  Please notify info@rollingbonesoutfitters.com with this error. 'Switch User Error'") if err
        $location.path '/dashboard'

  $scope.init.call(@)
])
