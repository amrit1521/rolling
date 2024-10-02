APP = window.APP
APP.Controllers.controller('Terms', ['$scope', ($scope) ->

  $scope.init = -> $scope.showHeaderButtons($scope)

  $scope.init.call(@)
])
