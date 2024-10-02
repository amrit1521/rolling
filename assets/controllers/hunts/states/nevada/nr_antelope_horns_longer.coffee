APP = window.APP
APP.Controllers.controller('HuntsNevadaNRAntelopeHornsLonger', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl05$grbAppType"}'

  $scope.init.call(@)
])
