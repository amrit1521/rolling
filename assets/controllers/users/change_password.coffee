APP = window.APP
APP.Controllers.controller('ChangePassword', ['$scope', '$location', 'User', 'Storage', ($scope, $location, User, Storage) ->
  $scope.init = () ->
    #$scope.hasPassword = true if $scope.user.password, this would improve the UI.  But at this point $scope.user didn't actually contain the password and I don't want to make another api call.
    $scope.hasPassword = true

  $scope.submit = (user) ->
    User.changePassword user,
      # success
      ->
        #Angular is not refreshing on the return to profile. Tmp solution is that we are just going to log them out.
        alert("Thank you, your password has been reset.  Please login again.")
        Storage.remove('user')
        Storage.remove('adminUser')
        Storage.remove('prevUser')
        Storage.remove('token')
        Storage.remove('navUsers')
        Storage.clear()
        $scope.prevUser = null
        $location.path '/login'

        ###
        if $scope.$$phase
          $location.path '/profile'
        else
          $scope.$apply ->
            $location.path '/profile'

        ###
      ,
      # err
      (res) -> alert(res.data.error) if res?.data?.error

  $scope.init.call(@)
])
