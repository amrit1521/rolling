APP = window.APP
APP.Controllers.controller('HuntsNevadaDreamTagCaliforniaBighornSheep', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl23$grbAppType"}'

  $scope.init.call(@)
])
