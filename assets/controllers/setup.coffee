APP = window.APP
APP.Controllers.controller('Setup', ['$scope', '$rootScope', '$location', 'Format', 'Point', 'Postal', 'State', 'Storage', 'User', ($scope, $rootScope, $location, Format, Point, Postal, State, Storage, User) ->
  $scope.pointStates = ["Arizona", "California", "Colorado", "Florida", "Montana", "Nevada", "NewMexico", "North Dakota", "Oregon", "Pennsylvania", "South Dakota", "Texas", "Utah", "Washington", "Wyoming"]

  $scope.showStates = false
  $scope.states = State.stateList
  $scope.countries = User.countryList
  $scope.state = {
    cid: null
  }

  $scope.init = ->
    $scope.showHeaderButtons($scope)

    throttlePostal = _.throttle $scope.getState, 500
    $scope.$watch 'user.mail_postal', throttlePostal
    $scope.stateOptions = State.stateList
    $scope.user = {
      country: 'United States'
    }
    $scope.createUserWithNoPoints = true
    $scope.sendWelcomeEmail = false
    $scope.sendWelcomeEmail = true if $scope.isRBO()
    $scope.subscribe_all = false
    checkLoggedIn = Storage.get 'user'
    window.location = "#!/register" unless checkLoggedIn

  $scope.getStatePage = (state) ->
    return '' unless state?.length
    state = state.replace(" ", "")
    "templates/partials/states/#{state.toLowerCase()}.html"

  $scope.showState = (state) ->
    if not ~$scope.pointStates.indexOf state
      state = 'Colorado'
      $scope.showStates = true

    $scope.stateTemplate = state
    $scope.redraw()


  $scope.getState = (mail_postal) ->
    return unless mail_postal?.length >= 5
    result = Postal.getState {mail_postal},
      ->
        $scope.showState(result.state)
      , (res) ->
        if res?.data?.code is 9462
          $scope.showState()

          return

        if res?.data?.error
          alert(res.data.error)

        $scope.showState()

  $scope.toggleNoPointsUser = () ->
    if $scope.createUserWithNoPoints
      $scope.createUserWithNoPoints = true
    else
      $scope.createUserWithNoPoints = true

  $scope.submit = (user, state) ->
    if !user?.email?.length
      alert "Please enter a valid email address."
    else
      $scope.createUserWithNoPoints = true
      parentUser = Storage.get 'user'
      user.parentId = parentUser._id if parentUser?._id
      user.source = "Dashboard"
      user.needsWelcomeEmail = $scope.sendWelcomeEmail
      if $scope.sendWelcomeEmail is false
        user.welcomeEmailSent = new Date()
      user.reminders = {
        email: false
        text: false
        stateswpoints: true
        types: ['app-start', 'app-end']
        states: []
      }
      if $scope.subscribe_all
        user.subscriptions = {
          hunts: true
          products: true
          newsletters: true
          rifles: true
        }

      user.createNewUser = true
      $scope.searchingUser = true
      data = _.extend {state: $scope.stateTemplate, cid: state.cid}, user

      if $scope.createUserWithNoPoints
        user.dob = moment(user.dob, 'MM/DD/YYYY').format('YYYY-MM-DD') if user.dob and ~user.dob.search /\//
        user.name = user.first_name + ' ' + user.last_name
        user.active = true
        Format.checkSSN(user)
        #user.country = 'United States'
        result = User.save user,
          # success
          ->
            new_user = result.user if result?.user
            #$scope.masquerade user._id
            #Storage.set 'user', user
            #Storage.set 'token', result.token
            #$location.path '/reminders'
            #$scope.searchingUser = false
            User.changePassword {password: "default", newPassword: "default", _id: new_user._id},
              ->
                console.log "defaults set."
                alert("#{new_user.first_name} #{new_user.last_name} created successfully")
                $scope.gotoRRADS(null, new_user)
                return $location.path '/dashboard'
            ,
              (res) ->
                console.log "error setting defaults:", res
          ,
          # err
          (res) ->
            $scope.searchingUser = false
            if res?.data?.error
              alert(res.data.error)
            else
              alert "An error occurred"
      else
        if not data.state?.length
          $scope.searchingUser = false
          alert "State is required"
          return

        result = State.findUser data,
          ->
            $rootScope.activeState = null
            user = _.clone result.user
            user.name = user.first_name + ' ' + user.last_name
            user.parentId = parentUser._id if parentUser?._id
            $scope.masquerade user._id
            Storage.set 'user', user
            Storage.set 'token', result.token
            $scope.searchingUser = false
            $rootScope.loadingUser = true
            User.changePassword {password: "default", newPassword: "default", _id: user._id},
              ->
                console.log "defaults set."
            ,
            (res) ->
              console.log "error setting defaults:", res
            $location.path '/dashboard'

          , (res) ->
            $scope.searchingUser = false
            if res?.data?.error
              alert(res.data.error)
            else
              alert "An error occurred"

  $scope.init.call(@)
])
