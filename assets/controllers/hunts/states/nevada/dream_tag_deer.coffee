APP = window.APP
APP.Controllers.controller('HuntsNevadaDreamTagDeer', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl19$grbAppType"}'

  $scope.init.call(@)
])
