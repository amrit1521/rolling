APP = window.APP
APP.Controllers.controller('ReviewStep', ['$scope', '$sce', '$modalInstance', 'pageSrc', 'resumeCb', ($scope, $sce, $modalInstance, pageSrc, resumeCb) ->
  $scope.showCreditCard = false

  $scope.init = ->
    $scope.pageUrl = $sce.trustAsResourceUrl("data:text/html;charset=utf-8," + encodeURI(pageSrc))
    $scope.resumeCb = resumeCb

  $scope.ok = ->
    $scope.resumeCb()
    $modalInstance.dismiss('cancel')

  $scope.cancel = ->
    $scope.resumeCb('stop')
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
