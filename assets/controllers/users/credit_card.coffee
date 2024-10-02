APP = window.APP
APP.Controllers.controller('UsersCreditCard', ['$scope', '$location', '$routeParams', 'Hunt', 'HuntChoice', 'State', 'Storage', 'User', ($scope, $location, $routeParams, Hunt, HuntChoice, State, Storage, User) ->
  $scope.init = () ->
    $scope.huntId = $routeParams.huntId
    $scope.user = Storage.get 'user'
    $scope.states = State.stateList
    $scope.countries = User.countryList

    hunt = Hunt.get {id: $scope.huntId}, ->
      $scope.hunt = hunt
      console.log "$scope.hunt:", $scope.hunt

    huntChoice = HuntChoice.get {huntId: $scope.huntId, userId: $scope.user._id}, ->
      $scope.huntChoice = huntChoice
      console.log "$scope.huntChoice:", $scope.huntChoice

  $scope.back = ($event) ->
    $event.preventDefault()
    window.history.back()

  $scope.submit = (card) ->
    $scope.running = true
    choice = JSON.parse angular.toJson($scope.huntChoice)

    console.log "choice:", choice
    console.log "card:", card

    result = HuntChoice.run {test: false, userId: Storage.get('user')._id, card, choice},
      ->
        $scope.running = false
        $scope.receiptURL = result.fileURL if result.fileURL
        $scope.licenseUrls = result.licenseUrls if result.licenseUrls

      (res) ->
        console.log "Found an error"
        $scope.running = false
        if res?.data?.error
          alert(res.data.error)
        else
          alert "An error occurred while running the application"

  $scope.init.call(@)
])
