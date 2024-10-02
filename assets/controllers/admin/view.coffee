APP = window.APP
APP.Controllers.controller('SaveView', ['$scope', '$modalInstance','Storage', 'customView', 'currentUser', 'View', ($scope, $modalInstance, Storage, customView, currentUser, View) ->

  $scope.init = ->
    $scope.tenant = window.tenant
    $scope.user = currentUser
    $scope.customView = customView
    $scope.originalViewName = customView.name
    if $scope.customView.name
      $scope.newView = false
    else
      $scope.newView = true

  $scope.save = ($event, newView, customView) ->
    $event.preventDefault()
    $scope.newView = newView
    $scope.customView = customView

    if $scope.newView and $scope.customView.name is $scope.originalViewName
      alert("The name for this new view is already used.  Please try a different name. ")
    else
      viewData = {
        name: $scope.customView.name
        description: $scope.customView.description
        tenantId: $scope.tenant._id
        admin_only: $scope.customView.admin_only
        options: $scope.customView.options
        selector: $scope.customView.selector
      }
      viewData._id = $scope.customView._id unless $scope.newView

      if $scope.customView.admin_only
        viewData.admin_only = true;
      else
        viewData.admin_only = false;

      View.save viewData, (results) ->
        if results._id
          $modalInstance.dismiss({status: "success", savedView: results, newView: $scope.newView})
        else
          console.log "Error, saving view:", results
          $modalInstance.dismiss({status: "failed", error: results, errorMsg: "Error occurred saving this view."})
      , (err) ->
        console.log "save view error:", err
        if err?.data?.error
          $modalInstance.dismiss({status: "failed", error: err, errorMsg: "Error occurred saving this view: #{err.data.error}"})
        else
          $modalInstance.dismiss({status: "failed", error: err, errorMsg: "Error occurred saving this view."})

  $scope.cancel = ($event) ->
    $event.preventDefault()
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
