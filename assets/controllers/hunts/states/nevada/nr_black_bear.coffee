APP = window.APP
APP.Controllers.controller('HuntsNevadaNRBlackBear', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl12$grbAppType"}'

  $scope.init.call(@)
])
