APP = window.APP
APP.Controllers.controller('AdminBilling', ['$scope', '$routeParams', 'Tenant', 'Storage', ($scope, $routeParams, Tenant, Storage) ->
  $scope.init = ->
    $scope.user = Storage.get 'user'
    $scope.thisMonth = moment().format("MMMM")
    $scope.lastMonth = moment().subtract(1, 'months').format("MMMM")
    $scope.thisWeekStart = moment().startOf('week').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.thisWeekEnd = moment().endOf('week').format("YYYY-MM-DD")+"T23:59:59.999Z"
    $scope.lastWeekStart = moment().subtract(1, 'weeks').startOf('week').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.lastWeekEnd = moment().subtract(1, 'weeks').endOf('week').format("YYYY-MM-DD")+"T23:59:59.999Z"

    $scope.loading = true
    $scope.currentTenant = ""
    $scope.tenants = []
    $scope.getTenants()


  $scope.getTenants = () ->

    # ASK RYAN, IS THIS SECRUE ENOUGH?
    gmtSuperReportGetAllTenants = $routeParams.all and !$scope.user.tenantId

    getTenantBilling = (tenant, done) ->
      $scope.currentTenant = tenant.name

      results = Tenant.adminBilling {id: tenant._id}, {allTenants: gmtSuperReportGetAllTenants}, (results) ->
        console.log "Billing results for #{tenant.name}", results
        tenant = results
        index = 0
        for tmpTenant in $scope.tenants
          if tmpTenant.name is tenant.name
            $scope.tenants[index] = tenant
            $scope.redraw()
            break
          index = index + 1
        return done null, tenant
      , (err) ->
        return done err


    if gmtSuperReportGetAllTenants
      tenants = Tenant.adminIndex {}, ->
        $scope.tenants = tenants

        async.mapSeries $scope.tenants, getTenantBilling, (err, tenants) ->
          console.log "ERROR: ", err if err
          console.log "Done with all tenant billing calls."
          $scope.tenants = tenants
          $scope.loading = false
    else
      getTenantBilling tenant, (err, tenant) ->
        console.log "Error getting tenant billing: ", err if err
        $scope.tenants = [tenant]
        $scope.loading = false

  $scope.init.call(@)
])
