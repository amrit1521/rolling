APP = window.APP
APP.Controllers.controller('HuntsMontanaHunts', ['$scope', '$location', '$routeParams', '$sce', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, $sce, Hunt, HuntChoice, HuntOption, Storage) ->
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

      fields = Object.keys($scope.choice)

#      for field in fields
#        continue unless $scope.choice[field]?.length
#
#        for option in $scope.huntOptions
#          if option.data.value + field.replace('Ans', '') is $scope.choice[field]
#            $scope.choice[field] = option
#            break

    hunt = Hunt.get {id: $scope.huntId}, ->
      $scope.hunt = hunt
      $scope.setHuntType hunt.params

  $scope.getChoices = (done = ->) ->
    choice = HuntChoice.get {huntId: $scope.huntId, userId: $scope.user._id}, ->
      return done() if not choice?.choice or choice[0] is 'n'

      $scope.choice = choice.choices
      done()

  $scope.getOptions = (done = ->) ->
    options = HuntOption.get {huntId: $scope.huntId}, ->
      return done() unless options
      for option, index in options
        options[index] = JSON.parse option.data

      options = options.sort (a, b) ->
        if a.name < b.name
          -1
        else if a.name > b.name
          1
        else
          0

      $scope.huntOptions = {}
      $scope.huntOptions[$scope.huntId] = options

      done()

  $scope.setHuntType = (type) ->
    $scope.huntType = type

  $scope.prepChoice = (hunt) ->
    return unless hunt
    console.log "hunt:", hunt
    choices = {}

    for name, choice of hunt
      continue unless choice?.name
      choices[name] = choice.value

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

  $scope.showRunButtons = -> return true

  $scope.viewTestResult = ->
    $scope.showResult = true

  $scope.hideTestResult = ->
    $scope.showResult = false


  $scope.viewReceipt = ->
    console.log "$scope.receiptURL:", $scope.receiptURL

  $scope.huntFilter = (options, search) ->
    console.log "options:", options
    options.filter (item) -> ~item.name.search search

  $scope.init.call(@)
])
