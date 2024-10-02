APP = window.APP
APP.Controllers.controller('HuntsNevadaSilverStateNelsonBHS', ['$scope', ($scope) ->
  $scope.init = ->
    $scope.setHuntType '{"type": "ctl00$ContentPlaceHolder1$gvAppType$ctl17$grbAppType"}'

  $scope.init.call(@)
])
