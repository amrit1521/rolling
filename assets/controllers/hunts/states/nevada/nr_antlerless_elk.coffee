APP = window.APP
APP.Controllers.controller('HuntsNevadaNRAntlerlessElk', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl08$grbAppType"}'

  $scope.init.call(@)
])
