APP = window.APP
APP.Controllers.controller('HuntsColoradoHunts', ['$scope', '$location', '$routeParams', '$sce', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, $sce, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.choice = {
    unsuccess: "1,REFUND"
  }
  $scope.hunts = {}
  $scope.types = {}
  $scope.huntType = ""

  $scope.init = ->
    $scope.stateId = $routeParams.stateId
    $scope.huntId = $routeParams.huntId
    $scope.user = Storage.get 'user'
    $scope.getChoices()

    hunt = Hunt.get {id: $scope.huntId}, ->
      $scope.hunt = hunt

    groupMembers = HuntChoice.groupCheck {userId: $scope.user._id, huntId: $scope.huntId},
      ->
        $scope.groupMembers = groupMembers
    (res) ->
        console.log "groupMembers error:", res.data?.error


  $scope.checkGroupId = (groupId) ->
    $scope.choice ?= {}
    $scope.choice.group_id = '' + groupId
    return if not groupId or groupId.length < 6
    clearTimeout $scope.groupLookup if $scope.groupLookup
    $scope.findGroupReset()
    $scope.groupLookup = setTimeout ->
      $scope.findGroup $scope.huntId, groupId
      $scope.redraw()
    , 500

  $scope.findGroupReset = ->
    $scope.groupLookup = null
    $scope.groupChoices = null
    $scope.groupNotFound = null
    $scope.groupWaiting = null
    $scope.groupMembers = null

  $scope.findGroup = (huntId, groupId) ->
    return unless groupId?.length >= 6

    nth = "1": "First", "2": "Second", "3": "Third", "4": "Fourth", "5": "Fifth", "6": "Sixth", "7": "Seventh"

    groupChoices = HuntChoice.groupLookup {huntId, groupId},
      ->
        $scope.findGroupReset()
        return $scope.groupWaiting = true unless groupChoices?.choices

        $scope.groupChoices = []
        for key, value of groupChoices.choices
          $scope.choice[key] = value unless key is 'group_id'
          matches = key.match /hunt_code(\d+)_1/
          continue unless matches

          choiceNum = matches[1]

          value = (groupChoices.choices["hunt_code#{choiceNum}_1"] +
            groupChoices.choices["hunt_code#{choiceNum}_2"] +
            groupChoices.choices["hunt_code#{choiceNum}_3"] +
            groupChoices.choices["hunt_code#{choiceNum}_4"]).toUpperCase()

          choice = {
            name: nth[choiceNum] + ' Choice:'
            value
          }
          $scope.groupChoices.push choice

        $scope.groupChoices.push {name: "If Unsuccessful:", value: groupChoices.choices.unsuccess.split(',').pop()} if groupChoices.choices?.unsuccess

        $scope.redraw()
      (res) ->
        $scope.findGroupReset()
        switch res.data?.code
          when 1002
            $scope.groupNotFound = true
          when 1003
            $scope.groupWaiting = true
          when res.data?.error
            alert("An error occurred:" + res.data.error)

        $scope.redraw()

  $scope.getChoices = (done = ->) ->
    choice = HuntChoice.get {huntId: $scope.huntId, userId: $scope.user._id}, ->
      return done() if not choice or choice[0] is 'n'

      $scope.choice = choice.choices
      if $scope.choice?.group_id?.length >= 6
        $scope.checkGroupId $scope.choice.group_id
      done()

  $scope.setHuntType = (type) ->
    $scope.huntType = type

  $scope.prepChoice = (hunt) ->
    return unless hunt
    choices = _.clone hunt

    for index in [1...4]
      if choices['hunt_code' + index + '_3']?.substr(0, 1) is '0'
        choices['hunt_code' + index + '_3'] = 'O' + choices['hunt_code' + index + '_3']?.substr(1)

    choices = {group_id: choices.group_id} if choices?.group_id?.length >= 6 and true in [$scope.groupNotFound, $scope.groupWaiting]

    {
      choices
      hunt: $scope.huntType
      huntId: $scope.huntId
      userId: Storage.get('user')._id
      stateId: $scope.stateId
    }

  $scope.save = (hunt) ->
    $scope.saving = true
    choice = $scope.prepChoice(hunt)
    return unless choice
    HuntChoice.save choice,
      ->
        $scope.saving = false
        alert "your choices have been saved",
      (res) ->
        $scope.saving = false
        if res?.data?.error
          alert(res.data.error)
        else
          alert "An error occurred while saving"

  $scope.testRun = (hunt) ->
    $scope.testRunning = true
    choice = $scope.prepChoice(hunt)
    return unless choice
    result = HuntChoice.run {test: true, userId: Storage.get('user')._id, choice},
      ->
        $scope.testRunning = false
        $scope.testResult = result.fileURL if result.fileURL
        $scope.testResultSafe = $sce.trustAsHtml $scope.testResult
      (res) ->
        $scope.testRunning = false
        if res?.data?.error
          alert(res.data.error)
        else
          alert "An error occurred while running the test"

  $scope.run = (hunt) ->
    choice = $scope.prepChoice(hunt)
    return unless choice

    HuntChoice.save choice,
      ->
        $location.path '/creditcard/' + $scope.huntId,
      (res) ->
        if res?.data?.error
          alert(res.data.error)
        else
          alert "An error occurred while running the application"

  $scope.showGroupChoices = ->
    return $scope.choice?.group_id?.length and not $scope.groupMembers?.length

  $scope.showRunButtons = ->
    return true unless $scope.choice?.group_id?.length >= 6
    return true if $scope.groupChoices?.length
    return false

  $scope.viewTestResult = ->
    $scope.showResult = true

  $scope.hideTestResult = ->
    $scope.showResult = false


  $scope.viewReceipt = ->
    console.log "$scope.receiptURL:", $scope.receiptURL

  $scope.init.call(@)
])
