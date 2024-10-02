APP = window.APP
APP.Controllers.controller('HuntsNevadaSilverStateDeer', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl15$grbAppType"}'

  $scope.init.call(@)
])
