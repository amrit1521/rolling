APP = window.APP
APP.Controllers.controller('HuntsNevadaSilverStateAntelope', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl16$grbAppType"}'

  $scope.init.call(@)
])
