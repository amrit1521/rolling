APP = window.APP
APP.Controllers.controller('HuntsNevadaHunts', ['$scope', '$location', '$routeParams', '$sce', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, $sce, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.choice = {}
  $scope.hunts = {}
  $scope.types = {}
  $scope.huntType = ""

  $scope.init = ->
    $scope.stateId = $routeParams.stateId
    $scope.huntId = $routeParams.huntId
    $scope.user = Storage.get 'user'

    async.parallel [
      (done) ->
        $scope.getChoices done
      (done) ->
        $scope.getOptions done
    ], ->
      console.log "$scope.choice", $scope.choice

      fields = Object.keys($scope.choice).filter (el) -> ~el.search 'Ans'

      for field in fields
        continue unless $scope.choice[field]?.length

        for option in $scope.huntOptions
          if option.data.value + field.replace('Ans', '') is $scope.choice[field]
            $scope.choice[field] = option
            break

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
          matches = key.match /Ans(\d+)/
          continue unless matches


          # Here - we need to find the matching option, then
          for option in $scope.huntOptions
            if option.data.value is value.substr(0, (value.length - 1))
              choiceNum = matches[1]

              $scope.choice['Ans' + choiceNum] = option

              value = option.data.hunterChoice + ' / ' + option.data.hunt + ' / ' + option.data.unitGroupDescription

              choice = {
                name: nth[choiceNum] + ' Choice:'
                value
              }
              $scope.groupChoices.push choice

              break

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

  $scope.getOptions = (done = ->) ->
    options = HuntOption.get {huntId: $scope.huntId}, ->
      return done() unless options
      $scope.huntOptions = options
      for option in $scope.huntOptions
        option.data = JSON.parse option.data

      $scope.huntOptions = $scope.huntOptions.sort (a, b) ->
        if a.data.hunt != b.data.hunt
          parseInt(a.data.hunt, 10) - parseInt(b.data.hunt, 10)
        else
          parseInt(a.data.hunterChoice, 10) - parseInt(b.data.hunterChoice, 10)

      done()

  $scope.setHuntType = (type) ->
    $scope.huntType = type

  $scope.prepChoice = (hunt) ->
    return unless hunt
    console.log "hunt:", hunt
    choices = {}

    for name, choice of hunt
      continue unless choice?.data
      choices[name] = choice.data.value + name.replace('Ans', '')
      pointOnly = not _.isNumber choice.data.hunterChoice

    choices = {group_id: hunt.group_id} if hunt.group_id?.length >= 6 and not (true in [$scope.groupNotFound, $scope.groupWaiting])

    {
      choices
      hunt: $scope.huntType
      huntId: $scope.huntId
      userId: Storage.get('user')._id
      stateId: $scope.stateId
      pointOnly
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
