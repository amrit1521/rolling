APP = window.APP
APP.Controllers.controller('AdminTenant', ['$scope', '$routeParams', '$location', 'Tenant', ($scope, $routeParams, $location, Tenant) ->
  $scope.init = ->
    if $routeParams.id
      $scope.isUpdate = true
      tenant = Tenant.adminRead $routeParams, ->
        tenant.percentage = tenant.commission * 100
        $scope.tenant = tenant
    else
      $scope.tenant = {}
      $scope.isUpdate = false

    $scope.cancel = ($event) ->
      $event.preventDefault() if $event
      $location.path '/admin/tenants'

    $scope.submit = ($event, tenant) ->
      $event.preventDefault() if $event
      tenant.referralPrefix = tenant.clientPrefix
      cb = ->
        alert 'Tenant saved'
        $location.path '/admin/tenants'
        $scope.redraw()
      cberr = (err) ->
        errMsg = ""
        errMsg = err.data if err?.data?
        alert "Tenant failed to save with error: #{errMsg}"

      if tenant?._id
        Tenant.adminUpdate tenant, cb, cberr
      else
        Tenant.adminSave tenant, cb, cberr

    $scope.sendToRRADS = ($event, tenant) ->
      $event.preventDefault() if $event
      tenant.referralPrefix = tenant.clientPrefix
      Tenant.adminPushRRADS tenant,
        (results) ->
          #console.log "Tenant pushed to RRADS with results: ", results
          alert "Tenant successfully pushed to RADS."
          $location.path "/admin/tenants"
          ,
        (err) ->
          errMsg = ""
          console.log "Tenant push to RRADS failed with error: ", err
          errMsg = err.data.error if err?.data?.error?
          alert "Tenant failed to pushed to RADS.  Error: #{errMsg}"

  $scope.delete = ($event, tenant) ->
    $event.preventDefault() if $event
    alert "Please contact RBO Tech Support with the request to delete this tenant."
    #if (confirm "This action can not be undone.  Are you sure you want to remove this tenant?")
    #  Tenant.adminDelete {id: tenant._id}, ->
    #    alert 'Tenant deleted'
    #    $location.path '/admin/tenants'
    #    $scope.redraw()

  $scope.init.call(@)
])
