APP = window.APP
APP.Controllers.controller('HuntsColoradoBear', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.init = ->
    $scope.setHuntType '{"year":"' + moment().format('YYYY') + '", "priv_code":"487", "species":"1", "app_type":"A", "prefix":"B"}'

  $scope.init.call(@)
])
