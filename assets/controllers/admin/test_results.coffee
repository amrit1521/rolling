APP = window.APP
APP.Controllers.controller('TestResults', ['$scope', '$sce', '$modalInstance', 'application', 'State', ($scope, $sce, $modalInstance, application, State) ->
  $scope.showCreditCard = false

  $scope.init = ->
    $scope.states = State.stateList
    $scope.testResultSafe = $sce.trustAsHtml application.results
    $scope.card = _.pick application, 'name', 'mail_city', 'mail_country', 'mail_postal', 'mail_state'
    $scope.card.address = application.address
    $scope.card.phone = application.phone_home
    $scope.application = application

    cards = []
    for key in ['1', '2']
      cards.push {index: key, name: '#' + key + ' XXXX-XXXX-XXXX-' + application.cards[key]} if application.cards[key]?.length
    cards.push {index: '3', name: 'Use another card'}

    $scope.cards = cards
    $scope.cardSelection = $scope.cards[0]
    console.log "$scope.cardSelection:", $scope.cardSelection

    $scope.$watch ->
      $scope.cards[$('#creditCard').val()]
    , (newVal) ->
      return unless newVal?.index is '3'
      console.log "Show credit card dialog"
      $scope.showCreditCard = true

  $scope.ok = (cardSelection, card) ->
    console.log "cardSelection", cardSelection
    console.log "card", card
    if cardSelection.index isnt '3'
      application.package.cardId = cardSelection.index
    else
      application.package.cardId = null
      application.package.card = card

    $scope.checkout application

  $scope.cancel = ->
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
