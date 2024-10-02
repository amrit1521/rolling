APP = window.APP
APP.Controllers.controller('HuntsNewMexicoBigHornSheep', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->

  $scope.init = () ->
    $scope.hunt.BigHornOptions = []

    if $scope.hunt.choice?.choice1_hunt_id
      selectedOption = $scope.getSelectedOption($scope.hunt._id, $scope.hunt.choice.choice1_hunt_id)
      if selectedOption
        $scope.hunt.BigHornOptions['choice1_hunt_id'] = selectedOption.options
      else
        $scope.hunt.BigHornOptions['choice1_hunt_id'] = null
    if $scope.hunt.choice?.choice2_hunt_id
      selectedOption = $scope.getSelectedOption($scope.hunt._id, $scope.hunt.choice.choice2_hunt_id)
      if selectedOption
        $scope.hunt.BigHornOptions['choice2_hunt_id'] = selectedOption.options
      else
        $scope.hunt.BigHornOptions['choice2_hunt_id'] = null
    if $scope.hunt.choice?.choice3_hunt_id
      selectedOption = $scope.getSelectedOption($scope.hunt._id, $scope.hunt.choice.choice3_hunt_id)
      if selectedOption
        $scope.hunt.BigHornOptions['choice3_hunt_id'] = selectedOption.options
      else
        $scope.hunt.BigHornOptions['choice3_hunt_id'] = null

    return

  $scope.setHuntOptions = (index, huntId, huntOptionValue) ->
    if index is 'choice1_hunt_id'
      $scope.hunt.choice.choice1_option1 = null
      $scope.hunt.choice.choice1_option2 = null
      $scope.hunt.choice.choice1_option3 = null
    else if index is 'choice2_hunt_id'
      $scope.hunt.choice.choice2_option1 = null
      $scope.hunt.choice.choice2_option2 = null
      $scope.hunt.choice.choice2_option3 = null
    else if index is 'choice3_hunt_id'
      $scope.hunt.choice.choice3_option1 = null
      $scope.hunt.choice.choice3_option2 = null
      $scope.hunt.choice.choice3_option3 = null
    selectedOption = $scope.getSelectedOption(huntId, huntOptionValue)
    $scope.hunt.BigHornOptions[index] = selectedOption.options if selectedOption


  $scope.getSelectedOption = (huntId, huntOptionValue) ->
    for option in $scope.huntOptions[huntId]
      if option.value is huntOptionValue
        return option


  $scope.init.call(@)
])
