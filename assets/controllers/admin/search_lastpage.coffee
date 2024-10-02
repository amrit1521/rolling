APP = window.APP
APP.Controllers.controller('LastPage', ['$scope', '$sce', '$modalInstance', 'pageSrc', 'error', ($scope, $sce, $modalInstance, pageSrc, error) ->

  $scope.init = ->
    $scope.pageUrl = $sce.trustAsResourceUrl("data:text/html;charset=utf-8," + encodeURI(pageSrc))
    $scope.error = error

  $scope.ok = ->
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
