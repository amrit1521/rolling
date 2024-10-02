loadingAPP = window.APP
APP.Controllers.controller('ServiceRequests', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'ServiceRequest', 'View', ($scope, $rootScope, $location, $modal, Storage, ServiceRequest, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#serviceRequestsGrid'
    $scope.user = Storage.get 'user'
    $scope.loading = false;
    $scope.items = []
    $scope.item = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.dateFilterType = null
    if $scope.user?.isAdmin
      $scope.loadSavedViews()
      $scope.loadItems(true)
      $scope.initGridHandlers()
    else
      alert "Unauthorized error"
    $scope.thisWeekStart = moment().startOf('week').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.thisWeekEnd = moment().endOf('week').format("YYYY-MM-DD")+"T23:59:59.999Z"
    $scope.thisMonthStart = moment().startOf('month').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.thisMonthEnd = moment().endOf('month').format("YYYY-MM-DD")+"T23:59:59.999Z"
    $scope.thisYearStart = moment().startOf('year').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.thisYearEnd = moment().endOf('year').format("YYYY-MM-DD")+"T23:59:59.999Z"
    $scope.lastWeekStart = moment().subtract(1, 'weeks').startOf('week').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.lastWeekEnd = moment().subtract(1, 'weeks').endOf('week').format("YYYY-MM-DD")+"T23:59:59.999Z"
    $scope.lastMonthStart = moment().subtract(1, 'months').startOf('month').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.lastMonthEnd = moment().subtract(1, 'months').endOf('month').format("YYYY-MM-DD")+"T23:59:59.999Z"
    $scope.lastYearStart = moment().subtract(1, 'years').startOf('year').format("YYYY-MM-DD")+"T00:00:00.000Z"
    $scope.lastYearEnd = moment().subtract(1, 'years').endOf('year').format("YYYY-MM-DD")+"T23:59:59.999Z"

  $scope.loadItems = (firstTime) ->
    $scope.loading = true;
    setItems = (results) ->
      items = []
      for item in results
        #Apply any additional calculated fields or logic here
        item.createdAt = new Date(parseInt(item._id.substring(0, 8), 16) * 1000)
        item.user_name = item.first_name + " " + item.last_name unless item.user_name
        item.user_name = "" if item.user_name?.indexOf("undefined") > -1
        item.userId = 'undefined' unless item.userId
        item.purchaseId = item.purchase.purchaseId if item.purchase?.purchaseId
        item.huntCatalogId = item.purchase.huntCatalogId if item.purchase?.huntCatalogId
        item.huntCatalogNumber = item.purchase.huntCatalogNumber if item.purchase?.huntCatalogNumber
        item.huntCatalogTitle = item.purchase.huntCatalogTitle if item.purchase?.huntCatalogTitle
        item.huntCatalogType = item.purchase.huntCatalogType if item.purchase?.huntCatalogType
        item.purchaseNotes = item.purchase.purchaseNotes if item.purchase?.purchaseNotes
        item.paymentMethod = item.purchase.paymentMethod if item.purchase?.paymentMethod
        item.depositReceived = new Date(item.purchase_hunt.depositReceived) if item.purchase_hunt?.depositReceived
        item.client_doc_sent = new Date(item.purchase_hunt.client_doc_sent) if item.purchase_hunt?.client_doc_sent
        item.outfitter_doc_sent = new Date(item.purchase_hunt.outfitter_doc_sent) if item.purchase_hunt?.outfitter_doc_sent
        item.outfitter_payment_sent = new Date(item.purchase_hunt.outfitter_payment_sent) if item.purchase_hunt?.outfitter_payment_sent
        items.push item
      $scope.items = results
      $scope.loading = false;
      if firstTime
        $scope.setupGrid(JSON.parse(JSON.stringify(results)))
      else
        $scope.setGridItems(JSON.parse(JSON.stringify(results)))

    if $scope.user.isAdmin
      results = ServiceRequest.adminIndex (results) ->
        setItems(results)
      , (err) ->
        console.log "loadAll errored:", err
        $scope.loading = false;

  $scope.loadSavedViews = () ->
    viewFindData = {
      tenantId: window.tenant._id
      selector: $scope.GRID_SELECTOR_ID
      userId: $scope.user._id
    }
    results = View.find viewFindData, (results) ->
      $scope.customViews = results
    , (err) ->
      console.log "loadSavedViews errored:", err

  $scope.setSelected = (args) ->
    $scope.item = null
    $scope.item = this.dataItem(this.select());

  $scope.initGridHandlers = () ->
    #Double Click row
    angular.element($scope.GRID_SELECTOR_ID).delegate(' table tr', 'dblclick', () ->
      window.location = "#!/admin/servicerequest/#{$scope.serviceRequest._id}"
    )

    #Save View
    angular.element($scope.GRID_SELECTOR_ID).delegate('.k-grid-SaveCurrentView', 'click', ($event) ->
      $event.preventDefault()
      $scope.saveCurrentView(angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid"))
    )

    #Column data tool tips
    angular.element($scope.GRID_SELECTOR_ID).kendoTooltip
      filter: 'td'
      show: (e) ->
        if @content.text() != ''
          angular.element('[role="tooltip"]').css 'visibility', 'visible'
        return
      hide: ->
        angular.element('[role="tooltip"]').css 'visibility', 'hidden'
        return
      content: (e) ->
        element = e.target[0]
        if element.offsetWidth < element.scrollWidth
          e.target.text()
        else
          ''

  $scope.editRow = ($event) ->
    $event.preventDefault()
    item = this.dataItem($($event.currentTarget).closest("tr"));
    if $scope.user.isAdmin
      window.location = "#!/admin/servicerequest/#{item._id}"

  $scope.loadGridView = (customView) ->
    return window.location.reload() unless customView
    return unless customView.options
    $scope.dateFilterType = null
    options = JSON.parse(customView.options)
    options.toolbar = $scope.toolbar
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    grid.dataSource.filter({}) #clear previous filters

    #Just keep the same columns hidden/showing, but use all updated column details/settings
    for savedColumn in options.columns
      for column in $scope.gridColumns
        if column.field is savedColumn.field
          column.hidden = savedColumn.hidden #note not cloning here, just modifying the actual $scope reference.
          break
    options.columns = $scope.gridColumns

    grid.setOptions(options) #apply new filters
    $scope.initGridHandlers()
    #grid.refresh();


  $scope.saveCurrentView = (grid) ->
    gridOptions = grid.getOptions()
    delete gridOptions.dataSource.data;
    gridOptions = kendo.stringify(gridOptions)
    if $scope.customView
      customView = $scope.customView
    else
      customView = {selector: $scope.GRID_SELECTOR_ID}
    customView.options = gridOptions

    modalReturned = (results) ->
      if results.savedView
        alert("View saved successfully.")
        $scope.customView = results.savedView
        $scope.customViews.push results.savedView if results.newView
        $scope.redraw()
      else if (results is "cancel" or results is "backdrop click")
        console.log "modal cancelled"
      else if results.error
        alert("The view failed to save successfully. #{customView.error}")
      else
        alert("The view failed to save successfully.")

    modal = $modal.open
      templateUrl: 'templates/partials/save_view.html'
      controller: 'SaveView'
      resolve: {
        customView: -> return customView
        currentUser: -> return $scope.user
      }
      scope: $scope

    modal.result.then modalReturned, modalReturned


  $scope.applyDateFilterType = (dateFilterType) ->
    $scope.dateFilterType = dateFilterType
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    dataSourceFilter = grid.dataSource.filter()
    if !dataSourceFilter
      dataSourceFilter = {
        logic: "and"
        filters: []
      }
    filters = dataSourceFilter.filters
    dateColumn = "createdAt"
    switch dateFilterType
      when "this_week"
        startDate = $scope.thisWeekStart
        endDate = $scope.thisWeekEnd
      when "this_month"
        startDate = $scope.thisMonthStart
        endDate = $scope.thisMonthEnd
      when "this_year"
        startDate = $scope.thisYearStart
        endDate = $scope.thisYearEnd
      when "last_week"
        startDate = $scope.lastWeekStart
        endDate = $scope.lastWeekEnd
      when "last_month"
        startDate = $scope.lastMonthStart
        endDate = $scope.lastMonthEnd
      when "last_year"
        startDate = $scope.lastYearStart
        endDate = $scope.lastYearEnd

    startDate = new Date(startDate)
    endDate = new Date(endDate)

    #clear previous dateColumn filters
    tFilters = []
    for filter in filters
      tFilters.push filter unless filter.field is dateColumn
    filters = tFilters

    filters.push {
      field: dateColumn
      operator: "gte"
      value: startDate
    }
    filters.push {
      field: dateColumn
      operator: "lte"
      value: endDate
    }

    dataSourceFilter.filters = filters
    grid.dataSource.filter(dataSourceFilter)
    grid.refresh();
    return


  $scope.setupGrid = (gridItems) ->
    #console.log "gridItems:", gridItems
    if $scope.user.isAdmin
      $scope.toolbar = ["excel", "Save Current View"]
    else
      $scope.toolbar = ["excel"]

    dataSource = $scope.getNewDataSource(gridItems)
    gridColumns = $scope.getGridColumns()

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "ServieRequests.xlsx",
        filterable: true
      },
      change: $scope.setSelected
      groupable: true
      sortable: true
      selectable: 'multiple'
      reorderable: true
      resizable: true
      filterable: true
      columnMenu: true
      pageable:
        pageSizes: [ 50,100,200,500,'All' ]
        input: true,
        numeric: false
      filterable: {
        mode: "menu, row"
        operators: {
          string: {
            contains: "Contains",
            eq: "Is equal to",
            neq: "Is not equal to",
            startswith: "Starts with",
            doesnotcontain: "Does not contain",
            endswith: "Ends with"
            isnull: "Is null"
            isnotnull: "Is not null"
            isempty: "Is empty"
            isnotempty: "Is not empty"
          } }
      },
      columns: gridColumns


  $scope.setGridItems = (gridItems) ->
    #console.log "gridItems:", gridItems
    dataSource = $scope.getNewDataSource(gridItems)
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    grid.setDataSource(dataSource)


  $scope.getNewDataSource = (gridItems) ->
    dataSource = new kendo.data.DataSource({
      data: gridItems
      pageSize: 50
      sort: {
        field: "createdAt",
        dir: "desc"
      }
      schema: {
        model: {
          id: "_id"
          fields: {
            createdAt: { type: "date" }
            updatedAt: { type: "date" }
            lastFollowedUpAt: { type: "date" }
            external_date_created: { type: "date" }
            needsFollowup: { type: "boolean" }
            depositReceived: { type: "date" }
            client_doc_sent: { type: "date" }
            outfitter_doc_sent: { type: "date" }
            outfitter_payment_sent: { type: "date" }
          }
        }
      }
      #aggregate: [
      #  { field: "rbo_repTotal", aggregate: "sum" }
      #]
      filter: { field: "type", operator: "neq", value: "Purchase" }
    })
    return dataSource


  $scope.getGridColumns = () ->
    TEMPLATE_UserNameLink = '# if(typeof user_name != "undefined" && user_name) { # <a href="\\#!/admin/masquerade/#:userId#">#:user_name#</a> # } else if (typeof user_first_name != "undefined" && typeof user_last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:userId#">#:user_first_name# #:user_last_name#</a> # } else { # <a href="\\#!/admin/masquerade/#:userId#">#:userId#</a> # } # '
    TEMPLATE_Count = "#= data.field#: #=data.value# (total: #= count#)"
    TEMPLATE_EDIT = '# if(typeof _id != "undefined") { # <a href="\\#!/admin/servicerequest/#:_id#">EDIT</a> # } # '
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"

    gridColumns = []

    gridColumns.push { field: 'type', title: 'Type', hidden: false, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'status', title: 'Status', hidden: false}
    gridColumns.push { field: 'needsFollowup', title: 'Needs Followup', hidden: false}
    gridColumns.push { field: 'lastFollowedUpAt', title: 'Last Follow-Up', template: TEMPLATE_formatDate('lastFollowedUpAt') }
    gridColumns.push { field: 'user_name', title: 'User', hidden: false, template: TEMPLATE_UserNameLink }
    gridColumns.push { field: 'message', title: 'Message', hidden: false }
    #gridColumns.push { field: 'external_date_created', title: 'Date Created', hidden: false, template: TEMPLATE_formatDate('external_date_created')}

    gridColumns.push { field: 'purchaseId', title: 'Receipt', hidden: true  }
    gridColumns.push { field: 'huntCatalogNumber', title: 'Hunt Catalog Number', hidden: true  }
    gridColumns.push { field: 'huntCatalogTitle', title: 'Hunt Catalog Title', hidden: true  }
    gridColumns.push { field: 'huntCatalogType', title: 'Hunt Catalog Type', hidden: true  }
    gridColumns.push { field: 'purchaseNotes', title: 'Purchase Notes', hidden: true  }
    gridColumns.push { field: 'paymentMethod', title: 'Payment Method', hidden: true  }
    gridColumns.push { field: 'depositReceived', title: 'Deposit Received', hidden: true, template: TEMPLATE_formatDate('depositReceived')  }
    gridColumns.push { field: 'client_doc_sent', title: 'Client Letter Sent', hidden: true, template: TEMPLATE_formatDate('client_doc_sent')  }
    gridColumns.push { field: 'outfitter_doc_sent', title: 'Outfitter Letter Sent', hidden: true, template: TEMPLATE_formatDate('outfitter_doc_sent')  }
    gridColumns.push { field: 'outfitter_payment_sent', title: 'Outfitter Payments Sent', hidden: true, template: TEMPLATE_formatDate('outfitter_payment_sent')  }
    gridColumns.push { field: 'external_id', title: 'ID', hidden: true  }
    gridColumns.push { field: 'userId', title: 'User Id', hidden: true }
    gridColumns.push { field: 'phone', title: 'Phone', hidden: true }
    gridColumns.push { field: 'email', title: 'Email', hidden: true }
    gridColumns.push { field: 'notes', title: 'Notes', hidden: true }
    gridColumns.push { field: 'clientId', title: 'Client Id', hidden: true }
    gridColumns.push { field: 'memberId', title: 'Member Id', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'address', title: 'Address', hidden: true }
    gridColumns.push { field: 'city', title: 'City', hidden: true }
    gridColumns.push { field: 'state', title: 'State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'postal', title: 'Zip', hidden: true }
    gridColumns.push { field: 'country', title: 'Country', hidden: true }
    gridColumns.push { field: 'contactDiffs', title: 'Contact Info Diffs', hidden: true }
    gridColumns.push { field: 'species', title: 'Species', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'location', title: 'Location', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'weapon', title: 'Weapon', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'budget', title: 'Budget', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'referral_ip', title: 'IP', hidden: true }
    gridColumns.push { field: 'referral_url', title: 'URL', hidden: true }
    gridColumns.push { field: 'referral_source', title: 'Source', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'specialOffers', title: 'Special Offers', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'newsletter', title: 'Newsletter', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }

    gridColumns.push { field: 'updatedAt', title: 'Last Updated', hidden: false, template: TEMPLATE_formatDate('updatedAt') }
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: false, template: TEMPLATE_formatDate('createdAt') }
    gridColumns.push { field: 'edit', title: 'EDIT', hidden: false, template: TEMPLATE_EDIT}
    $scope.gridColumns = gridColumns

    return gridColumns

  $scope.init.call(@)
])
