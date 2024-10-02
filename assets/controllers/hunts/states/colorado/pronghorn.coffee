APP = window.APP
APP.Controllers.controller('HuntsColoradoPronghorn', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.init = ->
    $scope.setHuntType '{"year":"' + moment().format('YYYY') + '", "priv_code":"465", "species":"7", "app_type":"A", "prefix":"A"}'

  $scope.init.call(@)
])
