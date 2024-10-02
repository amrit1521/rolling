APP = window.APP
APP.Controllers.controller('WizardIndex', ['$scope', '$rootScope', '$location', ($scope, $rootScope, $location) ->

  ###
  # Methods
  ###
  $scope.init = () ->

  $scope.save = ($event, user) ->
    $location.path("#/dashboard")

  $scope.init.call(@)
])
