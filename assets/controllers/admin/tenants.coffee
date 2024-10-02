APP = window.APP
APP.Controllers.controller('AdminTenants', ['$scope', '$routeParams', 'Tenant', ($scope, $routeParams, Tenant) ->
  $scope.init = ->
    $scope.tenants = Tenant.adminIndex($routeParams)

  $scope.init.call(@)
])
