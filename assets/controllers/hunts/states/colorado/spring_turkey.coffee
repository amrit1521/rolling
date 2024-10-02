APP = window.APP
APP.Controllers.controller('HuntsColoradoSpringTurkey', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.init = ->
    $scope.setHuntType '{"year":"' + moment().format('YYYY') + '", "priv_code":"683", "species":"10", "app_type":"L", "prefix":"T"}'

  $scope.init.call(@)
])
