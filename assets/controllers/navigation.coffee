APP = window.APP
APP.Controllers.controller('Navigation', ['$scope', '$rootScope', 'Storage', ($scope, $rootScope, Storage) ->

  $scope.init = () ->
    $scope.user = Storage.get 'user'

    $('a', '#slidemenu').on 'click', ->
      return if $(this).attr 'data-toggle'
      $('.navbar-toggle').trigger 'click', event

    $rootScope.$on 'change::user', $scope.setUser
    $rootScope.$on 'remove::user', $scope.setUser

    $rootScope.$on 'change::adminuser', $scope.setAdmin
    $rootScope.$on 'remove::adminuser', $scope.setAdmin

  $scope.setUser = (event, user) ->
    return $scope.user = user if user
    delete $scope.user

  $scope.setAdmin = (event, user) ->
    return $scope.adminUser = user if user
    delete $scope.adminUser

  $scope.init.call(@)
])
