APP = window.APP
APP.Controllers.controller('Login', ['$scope',  '$location', '$routeParams', 'Storage', 'User', ($scope,  $location, $routeParams, Storage, User) ->

  $scope.init = ->
    console.log "login happened"
    $scope.doFacebookLogin = false unless $scope.doFacebookLogin
    $scope.facebookLoaded  = false unless $scope.facebookLoaded
    $scope.user = Storage.get 'user'
    if $scope.user?.isRep
      window.location = "#!/repdashboard"
    else if $scope.user
      window.location = "#!/dashboard"

    if $routeParams.stamp
      console.log "Login::RRADS pass through"
      result = User.loginPassthrough {stamp: $routeParams.stamp},
        # success
        =>
          $scope.initStorage (result)
          if result.params?.destination is "receipt" and result.params?.purchase_id
            $location.path "/purchase_receipt/#{result.params.purchase_id}"
          else if result.user.isRep and result.params?.destination is "repdashboard"
            $location.path '/repdashboard'
          else if result.params?.destination is "admindashboard"
            $location.path '/admin/reports/users'
          else
            $location.path '/login'
        ,
        # error
        (res) ->
          console.log "Failed passthrough from RRADS with response: ", res
          $location.path '/login'


  $scope.submit = ->
    console.log "Login::submit"

    result = User.login {@email, @password},
      # success
      =>
        #user = result.user
        #Storage.set 'user',  result.user
        #Storage.set 'token', result.token
        #Storage.set 'topToken', result.token
        #$scope.adminUser = user if result.user.isAdmin
        #Storage.set 'adminUser', $scope.adminUser if result.user.isAdmin
        $scope.initStorage (result)
        now = new Date()
        memExp = new Date(result.user.memberExpires) if result.user.memberExpires
        repExp = new Date(result.user.repExpires) if result.user.repExpires

        #if result.user.isRep and result.user.repType and repExp and now < repExp  #TODO: Put back in repExp after populate repExpires correctly.
        if result.user.isRep and result.user.repType
          $location.path '/repdashboard'
        else if result.user.isMember and memExp and now < memExp and result.user.isAdmin
          $location.path '/memberdashboard'
        else
          $location.path '/dashboard'
      ,
      # error
      (res) -> alert(res.data.error) if res?.data?.error

  $scope.initStorage = (result) ->
    user = result.user
    Storage.set 'user',  result.user
    Storage.set 'token', result.token
    Storage.set 'topToken', result.token
    $scope.adminUser = user if result.user.isAdmin
    Storage.set 'adminUser', $scope.adminUser if result.user.isAdmin

  $scope.init.call(@)

])
