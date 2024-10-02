APP = window.APP
APP.Controllers.controller('HuntsNevadaNRAntleredElk', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl09$grbAppType"}'

  $scope.init.call(@)
])
