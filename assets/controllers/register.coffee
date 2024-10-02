APP = window.APP
APP.Controllers.controller('Register', ['$scope', '$rootScope', '$location', 'Format', 'Point', 'Storage', 'User', 'Postal', 'State', ($scope, $rootScope, $location, Format, Point, Storage, User, Postal, State) ->
  $scope.pointStates = ["Arizona", "California", "Colorado", "Florida", "Montana", "Nevada", "NewMexico", "North Dakota", "Oregon", "Pennsylvania", "South Dakota", "Texas", "Utah", "Washington", "Wyoming"]

  $scope.showStates = false
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
    $scope.createUserWithNoPoints = false

    $('#inputBirthDate').on 'blur', ->
      return unless $scope.user
      Format.checkDOB($scope.user)
      $scope.redraw()

  $scope.toggleNoPointsUser = () ->
    if $scope.createUserWithNoPoints
      $scope.createUserWithNoPoints = false
    else
      $scope.createUserWithNoPoints = true

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


  $scope.submit = (user, state)  ->
    return unless user
    #console.log user
    user.email = user.email?.toLowerCase()
    #Try logging in first to see if a user with the same email and password already exist.  If so, just log them in rather than creating a duplicate user.
    result = User.login {email: user.email, password: user.password},
      # success
      =>
        console.log "logging in"
        user = result.user
        Storage.set 'user',  result.user
        Storage.set 'token', result.token
        Storage.set 'topToken', result.token
        $scope.adminUser = user if result.user.isAdmin
        Storage.set 'adminUser', $scope.adminUser if result.user.isAdmin
        $location.path '/dashboard'
    ,
    # Login Failed
    (res) =>
      console.log "creating new user account", user
      if !user.mail_postal and !user.first_name and !user.last_name
        alert "Please enter a zip code to register by state points, or First and Last name to register without points."
        return

      Format.checkSSN(user)
      user.source = "Dashboard"
      user.needsWelcomeEmail = true

      #If they gave their Name, email, and password, then just register them if they have points or not.
      if user.first_name or user.last_name
        user.name = user.first_name + ' ' + user.last_name
        result = User.register user,
          # success
          ->
            user = _.clone result.user
            Storage.set 'user', user
            Storage.set 'token', result.token
            Point.all {userId: user._id} #try get points too
            $location.path '/dashboard'
          ,
          # err
          (res) ->
            alert (res.data.error+"  Please try again.") if res?.data?.error
      else
        #Try to register them checking if they have points. Fail if no points found so they can double check their info.
        $scope.searchingUser = true
        data = _.extend {state: $scope.stateTemplate, cid: state.cid}, user
        if not data.state?.length
          $scope.searchingUser = false
          alert "State is required"
          return

        result = State.findUser data,
          # success
          ->
            $scope.searchingUser = false
            tNewEmail = user.email
            tNewPswd = user.password
            #user = _.clone result.user
            user = result.user
            user.name = user.first_name + ' ' + user.last_name
            user.email = tNewEmail
            user.password = tNewPswd
            user.type = "local"

            result = User.save user,
            # success
            ->
              Storage.set 'user', user
              Storage.set 'token', result.token
              $rootScope.loadingUser = true
              #Point.all {userId: user._id}
              $location.path '/dashboard'
            ,
            #err
            (res) ->
              if res?.data?.error
                alert(res.data.error)
              else
                alert "An error occurred"
        ,
        # err
        (res) ->
          $scope.searchingUser = false
          if res?.data?.error
            alert(res.data.error)
          else
            alert "An error occurred"

  $scope.init.call(@)
])
