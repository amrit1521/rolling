APP = window.APP
APP.Controllers.controller('HuntsNevadaDreamTagNelsonBighornSheep', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl21$grbAppType"}'

  $scope.init.call(@)
])
