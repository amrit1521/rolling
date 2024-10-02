APP = window.APP
APP.Controllers.controller('UsersPoints', ['$scope', '$rootScope', '$routeParams', '$location', 'Hunt', 'HuntChoice', 'Point', 'Pubnub', 'State', 'Storage', 'User', 'UserState', 'Utah', ($scope, $rootScope, $routeParams, $location, Hunt, HuntChoice, Point, Pubnub, State, Storage, User, UserState, Utah) ->
  $scope.states = []
  $scope.application = {
    hunts: []
  }

  $scope.init = ->
    return #Tmp Disable Points
    $scope.user = Storage.get 'user'
    return unless $scope?.user?._id
    $scope.stateOptions = State.stateList
    $scope.searchingUser = $rootScope.loadingUser
    $scope.refreshing = $scope.searchingUser
    $scope.findingState = ""
    $rootScope.loadingUser = false

    if $scope.searchingUser
      $scope.loadPoints()
      setTimeout ->
        return unless $scope.searchingUser
        console.log "searchingUser init timeout"
        $scope.searchingUser = false
        $scope.redraw()
      , 30000 # 30 Seconds

    $rootScope.$on 'change::user', $scope.updateUser
    $scope.sanitize()
    Pubnub.init()
    Pubnub.subscribe $scope, $scope.user._id, 100 if $scope?.user?._id
    $scope.$on "$destroy", ->
      Pubnub.unsubscribe $scope, $scope.user._id

    $scope.$on 'PUBNUB-connect', ($event, message) ->
      $scope.connected = true
      $scope.loadStates true

    $scope.loadStates true if $scope.connected

    $scope.$on 'PUBNUB-state-get-points', ($event, message) ->
      #console.log "PUBNUB-state-get-points message [#{message.data.abbreviation}]:", message
      $scope.findingState = message.data.abbreviation
      $scope.redraw()

    $scope.$on 'PUBNUB-state-update', ($event, message) ->
      console.log "PUBNUB-state-update message [#{message.data.abbreviation}]:", message
      $scope.updateState message

    $scope.$on 'PUBNUB-user-update', ($event, message) ->
      console.log "PUBNUB-user-update message :", message
      Storage.set 'user', message.data
      $scope.redraw()

    states = Storage.get 'states'

    $scope.statesUserId = Storage.get('statesUserId')
    if $scope.statesUserId is $scope.user._id
      $scope.states = states
    else
      $scope.states = []
      states = State.byUser {id: $scope.user._id},
        # success
        ->
          for state in states
            if state.hunts
              for hunt in state.hunts
                if hunt.point and hunt.point.count
                  state.userHasPoints = true
                  state.show = true

          $scope.states =  states
          Storage.set 'states', $scope.states
          Storage.set 'statesUserId', $scope.user._id
        ,
        # err
        (res) ->
          $scope.states = []
          alert (res.data.error) if res?.data?.error
    $scope.redraw()

  ###
  # Methods
  ###

  $scope.addHunt = ->
    $scope.showAddHunt = true

  $scope.back = ($event) ->
    $event.preventDefault()
    window.history.back()

  $scope.changeSelection = ($event, hunt) ->
    if jQuery($event.target).is(':checked')
      $scope.application.hunts.push hunt unless ~$scope.application.hunts.indexOf hunt
    else
      $scope.application.hunts = $scope.application.hunts.filter ($hunt) ->
        return hunt isnt $hunt

  $scope.clearCID = ($event, state) ->
    $event.preventDefault()

    UserState.clear {userId: $scope.user._id, stateId: state._id},
      ->
        state.cid = null
      (err) ->
        console.log "err", err
        alert "Error clearing CID. " + err.data unless err.data == "Not Found"

  $scope.explainWeight = ($event, point) ->
    $event.preventDefault()
    alert('This state has weighted points.  This is the point\'s weight')

  $scope.findStatePoints = (state, user) ->
    data = _.extend {state: state.name, cid: state.cid}, user
    Storage.set 'user', user
    $scope.searchingUser = true

    done = ->
      console.log "searchingUser find state points"
      $scope.searchingUser = false
      $scope.showMoreStates = false
      $scope.loadStates(true)

    State.findUser data,
      ->
        done()
        Point.all( {userId: user._id} )

      , (res) ->
        done()

  $scope.getLastUpdate = (state) ->
    return '' unless state?.hunts?.length

    for hunt in state.hunts
      continue unless hunt.point?._id?.length

      timestamp = hunt.point._id.toString().substring(0,8)
      date = new Date( parseInt( timestamp, 16 ) * 1000 )
      return moment(date).format('MM/DD/YYYY h:mmA')

    return ''

  $scope.getStatePoints = (state, cb = ->) ->
    # return cb $scope.points = state.points if state.points?.length

    return cb() unless state.hasPoints

    state.loading = true
    state.showEnterId = false
    state.searched = false

    state.cid = state.cid.replace(/[^0-9]/g, '') if state.cid and state.abbreviation is 'WA'

    search = {
      stateId: state._id
      userId: $scope.user._id
      refresh: true
    }
    search.cid = state.cid if state.cid

    Point.byState search,
      ->
        state.loading = false
        state.showEnterId = false
        state.searched = true

        $scope.loadStates(false)
      , ->
        $scope.loadStates(false)

  $scope.huntSort = (hunt) ->
    result = ''
    result += '___' if hunt?.point?.count
    result += hunt.name
    result

  $scope.stateSort = (state) ->
    result = ''
    # result += '___' if state?.userHasPoints
    result += state.name
    result

  $scope.loadStates = (reload, cb = ->) ->
    console.log "states:", $scope.states
    $scope.redraw()

  $scope.loadPoints = ->
    $scope.refreshing = true
    Point.all {userId: $scope.user._id}, ->
      $scope.refreshing = false

  $scope.updateState = (message) ->
    update = message.data
    $scope.states ?= []
    found = false

    update.show = update.active && not message.error
    if update.hunts?.length
      for hunt in update.hunts
        if hunt.point?.count
          update.userHasPoints = true
          break

    for state, i in $scope.states
      if state._id is update._id
        $scope.states[i] = update unless message.error
        alert message.error.error if message?.error?.error and $scope.states[i].show
        found = true

    $scope.searchingUser = false if update.show
    $scope.states.push update unless found
    Storage.set 'states', $scope.states
    Storage.set 'statesUserId', $scope.user._id
    $scope.statesUserId = $scope.user._id

    $scope.redraw()
    return

  $scope.refresh = ($event) ->
    $event.preventDefault()
    $scope.refreshing = true

    Point.all {userId: $scope.user._id}, ->
      $scope.refreshing = false

  $scope.sanitize = ->
    $scope.user.ssnx = $scope.user.ssn.substr(0, 4) if $scope.user.ssn
    $scope.user.ssn = null

  $scope.showApplications = (state) ->
    if $scope.user.isAdmin
      return !$scope.isPhonegap and !!state?.applicationReady
    else
      return false

  $scope.showHunt = (state, hunt) ->
    return (!$scope.isPhonegap) or ($scope.isPhonegap and state.userHasPoints and hunt.point?.count)

  $scope.showHunts = (state) ->
    return false unless state
    return state.hasPoints || state.applicationReady

  $scope.showStateForm = (state) ->
    state.active and state.hasPoints and not state.userHasPoints

  $scope.showWeight = (hunt) ->
    ignoredHunts = [
      "532b0dd75926e0e56ed0ebd7" # CO Deer
      "532b0dd75926e0e56ed0ebd9" # CO Elk
      "532b0dd75926e0e56ed0ebdc" # CO Pronghorn
    ]
    return false if hunt._id in ignoredHunts
    return false if not hunt.point?.weight and hunt.point?.weight isnt 0
    true

  $scope.stateForm = (state) ->
    if state.hasPoints then "templates/partials/states/#{state.name.toLowerCase().replace(" ","")}.html" else ''

  $scope.testRun = ($event, state) ->
    $event.preventDefault()
    HuntChoice.run {test: true, userId: Storage.get('user')._id, stateId: state._id}

  $scope.updateUser = ($event, user) ->
    $scope.states = [] if user._id isnt $scope.statesUserId
    $scope.user = user
    $scope.sanitize()

  $scope.urlify = (name) ->
    name.toLowerCase().replace(/[^\w]+/g, '_').replace(/^_+/, '').replace(/_+$/, '')

  $scope.init.call(@)
])
