APP = window.APP
APP.Controllers.controller('AdminDrawResults', ['$scope', '$routeParams', 'DrawResult', ($scope, $routeParams, DrawResult) ->
  $scope.init = ->
    $scope.statusType = "2-successful"
    $scope.statusTypes = {
      "1-all": "All"
      "2-successful": "Successful"
      "3-unsuccessful": "Unsuccessful"
      "4-bonusPointOnly": "Purchased Bonus Point Only"
    }
    $scope.state = $routeParams.state
    drawResults = DrawResult.report {state: $scope.state, type: $routeParams.type}, ->
      $scope.drawResults = drawResults

  $scope.getDrawResults = (statusType) ->
    statusType = statusType.split("-")[1]
    drawResults = DrawResult.report {state: $scope.state, type: statusType}, ->
      $scope.drawResults = drawResults

  $scope.init.call(@)
])
