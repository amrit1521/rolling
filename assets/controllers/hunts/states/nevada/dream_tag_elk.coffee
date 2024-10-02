APP = window.APP
APP.Controllers.controller('HuntsNevadaDreamTagElk', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl22$grbAppType"}'

  $scope.init.call(@)
])
