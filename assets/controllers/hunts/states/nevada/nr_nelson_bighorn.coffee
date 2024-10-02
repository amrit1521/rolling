APP = window.APP
APP.Controllers.controller('HuntsNevadaNRNelsonBighorn', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl06$grbAppType"}'

  $scope.init.call(@)
])
