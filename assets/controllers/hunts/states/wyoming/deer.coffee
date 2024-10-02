APP = window.APP
APP.Controllers.controller('HuntsWyomingDeer', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'HuntOption', 'Storage', ($scope, $location, $routeParams, Hunt, HuntChoice, HuntOption, Storage) ->
  $scope.choice = {}
  $scope.hunts = {}
  $scope.types = {}

  $scope.init = ->
    $scope.huntId = $routeParams.huntId
    $scope.user = Storage.get 'user'
    $scope.huntType = 'btnApply5'
    $scope.preferecePoint = true

    hunt = Hunt.get {id: $scope.huntId}, ->
      $scope.hunt = hunt
      console.log "$scope.hunt:", $scope.hunt

    async.parallel [
      (done) ->
        $scope.getChoices done
      (done) ->
        $scope.getOptions done
    ], (err, results) ->

      data = $scope.huntOptions[0].data

      keys = Object.keys(data.options).filter (element) ->
        return ~element.match(/comboHuntArea(\d+)/)

      for key in keys
        areaNum = key.match(/comboHuntArea(\d+)/)[1]
        $scope.hunts[key] = []
        for j of data.options[key]
          $scope.hunts[key].push j

        console.log "1- set default value of:", key
        $scope.setChoice areaNum, data
        $scope.setupWatch key, data

  $scope.getChoices = (done) ->
    choice = HuntChoice.get {huntId: $scope.huntId, userId: $scope.user._id}, ->
      return done() unless choice
      $scope.choices = choice.choices
      $scope.huntType = choice.hunt
      $scope.preferecePoint = choice.preferecePoint
      done()

  $scope.getOptions = (done) ->
    options = HuntOption.get {huntId: $scope.huntId}, ->
      return done() unless options
      $scope.huntOptions = options
      for option in $scope.huntOptions
        option.data = JSON.parse option.data
      done()

  $scope.setupWatch = (key, data) ->
    areaNum = key.match(/comboHuntArea(\d+)/)[1]
    typeName = "comboType" + areaNum
    $scope.$watch 'choice.' + key, (newValue, oldValue) ->
      return if newValue is oldValue
      $scope.types[typeName] = data.options[key][$scope.choice?[key]]
      $scope.choice[typeName] = $scope.types?[typeName][0]

  $scope.setChoice = (areaNum, data) ->
    huntName = 'comboHuntArea' + areaNum
    typeName = 'comboType' + areaNum
    if not $scope.choices or not $scope.hunts?[huntName]?.length
      $scope.choice[huntName] = $scope.hunts[huntName][0]
      $scope.types[typeName] = data.options[huntName][$scope.choice[huntName]]
      $scope.choice[typeName] = $scope.types[typeName][0]
    else

      for hunt in $scope.hunts[huntName]
        if hunt is $scope.choices[huntName]
          $scope.choice[huntName] = hunt
          break

      $scope.types[typeName] = data.options[huntName][$scope.choice?[huntName]]

      for type, index in $scope.types[typeName]
        console.log type, " is ", $scope.choices[typeName], ":", (type is $scope.choices[typeName])
        if type is $scope.choices[typeName]
          console.log "set ", typeName, ' to: ', $scope.types[typeName][index]
          $scope.choice[typeName] = $scope.types[typeName][index]
          break

  $scope.prepChoice = (hunt) ->
    if not hunt.comboHuntArea11
      hunt.comboHuntArea11 = ''
      delete hunt.comboType11

    if not hunt.comboHuntArea21
      hunt.comboHuntArea21 = ''
      delete hunt.comboType21

    if not hunt.comboHuntArea31
      hunt.comboHuntArea31 = ''
      delete hunt.comboType31

    console.log "hunt:", hunt
    {
      choices: hunt
      hunt: $scope.huntType
      preferecePoint: $scope.preferecePoint
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

  $scope.run = (hunt) ->
    choice = $scope.prepChoice(hunt)
    console.log "choice:", choice
    HuntChoice.save choice, ->
      $location.path '/creditcard/' + $scope.huntId

  $scope.init.call(@)
])
