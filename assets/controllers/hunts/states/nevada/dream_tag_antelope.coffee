APP = window.APP
APP.Controllers.controller('HuntsNevadaDreamTagAntelope', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl20$grbAppType"}'

  $scope.init.call(@)
])
