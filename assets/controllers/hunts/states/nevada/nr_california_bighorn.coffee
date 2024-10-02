APP = window.APP
APP.Controllers.controller('HuntsNevadaNRCaliforniaBighorn', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl11$grbAppType"}'

  $scope.init.call(@)
])
