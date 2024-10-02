APP = window.APP
APP.Controllers.controller('HuntsNevadaAntleredMuleDeer', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl04$grbAppType"}'

  $scope.init.call(@)
])
