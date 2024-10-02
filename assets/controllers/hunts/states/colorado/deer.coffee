APP = window.APP
APP.Controllers.controller('HuntsColoradoDeer', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.init = ->
    $scope.setHuntType '{"year":"' + moment().format('YYYY') + '", "priv_code":"491", "species":"2", "app_type":"A", "prefix":"D"}'

  $scope.init.call(@)
])
