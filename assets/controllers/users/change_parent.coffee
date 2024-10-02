APP = window.APP
APP.Controllers.controller('ChangeParent', ['$scope', '$location', 'User', 'Storage', ($scope, $location, User, Storage) ->
  $scope.init = () ->
    $scope.newParentClientId = null

  $scope.findParent = ($event, newParentClientId) ->
    return unless newParentClientId
    results = User.getByClientId {clientId: newParentClientId},
      # success
      ->
        if results._id and $scope.user?.tenantId is results?.tenantId
          $scope.newParent = results
        else
          alert "User not found for Client Id: #{newParentClientId}.  Please enter a new Client Id and try again."
      ,
      # err
      (res) ->
        alert(res.data.error) if res?.data?.error



  $scope.submit = (newParent) ->
    data = {
      userId: $scope.user._id
      newParentId: newParent._id
    }
    User.changeParent data,
      # success
      ->
        alert "User's parent re-assigned successfully."
        $location.path '/#!'
      ,
      # err
      (res) -> alert(res.data.error) if res?.data?.error

  $scope.init.call(@)
])
