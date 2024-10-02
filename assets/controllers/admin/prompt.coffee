APP = window.APP
APP.Controllers.controller('Prompt', ['$scope', '$modalInstance', 'prompt', 'resumeCb', ($scope, $modalInstance, prompt, resumeCb) ->

  $scope.init = ->
    $scope.message = prompt.message
    $scope.answers = {}

    $scope.buttons = prompt.buttons
    $scope.buttons ?= ["OK"]

    if prompt.label
      $scope.label = prompt.label
      $scope.label ?= "Answer:"

    if prompt.inputs
      $scope.inputs = prompt.inputs

    $scope.resumeCb = resumeCb

  $scope.ok = (button, answers) ->
    $scope.resumeCb(null, button, answers)
    $modalInstance.dismiss('cancel')

  $scope.cancel = ->
    $scope.resumeCb('stop')
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
