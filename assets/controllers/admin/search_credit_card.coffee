APP = window.APP
APP.Controllers.controller('SearchCreditCard', ['$scope', '$sce', '$modalInstance', 'application', 'State', 'Storage', 'User', 'Search', ($scope, $sce, $modalInstance, application, State, Storage, User, Search) ->

  $scope.init = ->
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.cardTypes = [
      'American Express'
      'Discover'
      'MasterCard'
      'Visa'
    ]
    $scope.application = application

    if application.cardIndex.blank
      $scope.card = {
        name: application.name
        phone: application.phone_home
        address: application.mail_address
        city: application.mail_city
        country: application.mail_country
        postal: application.mail_postal
        state: application.mail_state
        isNew: true
      }
    else
      $scope.getCard()



  $scope.getCard = () ->
    Search.card {index: application.cardIndex.index, userId: $scope.application._id}, (res) ->
      $scope.card = {
        title: application.cardIndex.title
        index: application.cardIndex.index
        isNew: false
        name: res.card.name
        phone: res.card.phone
        address: res.card.address
        address2: res.card.address2
        city: res.card.city
        state: res.card.state
        country: res.card.country
        postal: res.card.postal
        type: res.card.type
        number: res.card.number
        code: res.card.code
        month: res.card.month
        year: res.card.year

      }
    ,
      (err) ->
        console.log "error: ", err
        alert "Unable to retrieve this user's credit card.  Please contact support@gotmytag.com for assistance"
        $modalInstance.dismiss('cancel')

  $scope.save = (card) =>
    if card.isNew
      if $scope.application.cards?.length > 1 and !$scope.application.cards[1].isNew
        index = 2
      else
        index = 1
      newCard = _.extend {}, card, {isNew: true, title: '#' + (index) + ' XXXX-XXXX-XXXX-' + card.number.substr(-4)}
      application.cards.splice index, 0, newCard
      application.cardIndex = application.cards[index-1]
      $modalInstance.dismiss('save')

    else
      application.cardIndex = card
      newCard = card
      index = card.index
      title: '#' + (index) + ' XXXX-XXXX-XXXX-' + card.number.substr(-4)
      $modalInstance.dismiss('save')

    #save the card to mongo
    newCard.userId = $scope.application._id
    newCard.cardIndex = index
    User.cardUpdate newCard, (err, res) ->
      console.log err if err

  $scope.cancel = ->
    application.cardIndex = null
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
