APP = window.APP
APP.Controllers.controller('Contact', ['$scope', ($scope) ->

  $scope.init = ->
    $scope.showHeaderButtons($scope) if $scope.isPhonegap

  $scope.init.call(@)
])
