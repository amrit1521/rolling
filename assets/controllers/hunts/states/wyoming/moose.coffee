APP = window.APP
APP.Controllers.controller('HuntsWyomingMoose', ['$scope', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.choice = {}

  $scope.init = ->
    $scope.huntId = $routeParams.huntId
    $scope.user = Storage.get 'user'

    hunt = Hunt.get {id: $scope.huntId}, ->
      $scope.hunt = hunt
      console.log "$scope.hunt:", $scope.hunt

    choice = HuntChoice.get {huntId: $scope.huntId, userId: $scope.user._id}, ->
      $scope.choices = choice.choices
      $scope.setChoice()
      $scope.redraw()

    $scope.hunts = []
    options = HuntOption.get {huntId: $scope.huntId}, ->
      $scope.huntOptions = options
      $scope.huntOptions[0].data = JSON.parse $scope.huntOptions[0].data
      for index of $scope.huntOptions[0].data.options.comboHuntArea1
        $scope.hunts.push index

      $scope.choice.comboHuntArea1 = $scope.hunts[0]
      $scope.redraw()

    $scope.$watch 'choice.comboHuntArea1', ->
      $scope.types = $scope.huntOptions?[0].data.options.comboHuntArea1[$scope.choice?.comboHuntArea1]
      $scope.choice.comboType1 = $scope.types?[0]
      $scope.setChoice()

  $scope.setChoice = ->
    return unless $scope.choices and $scope.hunts?.length

    for hunt in $scope.hunts
      if hunt is $scope.choices.comboHuntArea1
        $scope.choice.comboHuntArea1 = hunt
        break

    for type in $scope.types
      if type is $scope.choices.comboType1
        $scope.choice.comboType1 = type
        break

  $scope.prepChoice = (hunt) ->
    console.log "hunt:", hunt
    {
      choices: hunt
      hunt: $scope.huntOptions[0].data.huntData.id
      huntId: $scope.huntId
      userId: Storage.get('user')._id
    }

  $scope.save = (hunt) ->
    choice = $scope.prepChoice(hunt)
    console.log "choice:", choice
    HuntChoice.save choice

  $scope.testRun = (hunt) ->
    console.log "hunt:", hunt
    choice = $scope.prepChoice(hunt)
    console.log "choice:", choice
    HuntChoice.run {test: true, userId: Storage.get('user')._id, choice}

  $scope.init.call(@)
])
