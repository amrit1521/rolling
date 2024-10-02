loadingAPP = window.APP
APP.Controllers.controller('Applications', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'View', 'Hunt', ($scope, $rootScope, $location, $modal, Storage, View, Hunt) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#applicationsGrid'
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
      window.location = "#!/dashboard"
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
    makeBoolean = (value) ->
      tValue = false
      tValue = true if (value is true or value is 'true' or value is 'True')
      return tValue

    setItems = (results) ->
      items = []
      warnings = ""
      for item in results
        #Apply any additional calculated fields or logic here
        #item.createdAt = new Date(parseInt(item._id.substring(0, 8), 16) * 1000)
        item.isMember = false unless item.isMember is true
        item.ak_check = makeBoolean(item.ak_check)
        item.az_check = makeBoolean(item.az_check)
        item.ca_check = makeBoolean(item.ca_check)
        item.co_check = makeBoolean(item.co_check)
        item.fl_check = makeBoolean(item.fl_check)
        item.ia_check = makeBoolean(item.ia_check)
        item.id_check = makeBoolean(item.id_check)
        item.ks_check = makeBoolean(item.ks_check)
        item.ky_check = makeBoolean(item.ky_check)
        item.mt_check = makeBoolean(item.mt_check)
        item.nd_check = makeBoolean(item.nd_check)
        item.nm_check = makeBoolean(item.nm_check)
        item.nv_check = makeBoolean(item.nv_check)
        item.ore_check =makeBoolean(item.ore_check)
        item.sd_check = makeBoolean(item.sd_check)
        item.pa_check = makeBoolean(item.pa_check)
        item.tx_check = makeBoolean(item.tx_check)
        item.ut_check = makeBoolean(item.ut_check)
        item.vt_check = makeBoolean(item.vt_check)
        item.wa_check = makeBoolean(item.wa_check)
        item.wy_check = makeBoolean(item.wy_check)

        if item.missingPowerOfAttorney
          if !warnings?.length
            warnings = "The following users requested applications but have not yet clicked on power of attorney to give permission to do so and must before we apply for them."
            warnings = warnings + " " + item.clientId
          else
            warnings = warnings + ", " + item.clientId

        console.log item if item.missingPowerOfAttorney
        item.powerOfAttorney = false unless item.powerOfAttorney
        items.push item

      $scope.items = items
      alert warnings if warnings?.length
      $scope.loading = false;
      if firstTime
        $scope.setupGrid(JSON.parse(JSON.stringify($scope.items)))
      else
        $scope.setGridItems(JSON.parse(JSON.stringify($scope.items)))

    if $scope.user.isAdmin
      results = Hunt.adminAllApplications (results) ->
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
      #window.location = "#!/admin/servicerequest/#{$scope.serviceRequest._id}"
      console.log "Dbl CLick Not Implemented"
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
      #window.location = "#!/admin/servicerequest/#{item._id}"
      console.log "editRow Implemented"


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
    dateColumn = "modified"
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
        fileName: "StateHuntApplications.xlsx",
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
        field: "last_name",
        dir: "asc"
      }
      schema: {
        model: {
          id: "_id"
          fields: {
            modified: { type: "date" }
            memberExpires: { type: "date" }
            isMember: { type: "boolean" }
            isRep: { type: "boolean" }
            powerOfAttorney: { type: "boolean" }
            ak_check: { type: "boolean" }
            az_check: { type: "boolean" }
            ca_check: { type: "boolean" }
            co_check: { type: "boolean" }
            fl_check: { type: "boolean" }
            ia_check: { type: "boolean" }
            id_check: { type: "boolean" }
            ks_check: { type: "boolean" }
            ky_check: { type: "boolean" }
            mt_check: { type: "boolean" }
            nd_check: { type: "boolean" }
            nm_check: { type: "boolean" }
            nv_check: { type: "boolean" }
            ore_check: { type: "boolean" }
            sd_check: { type: "boolean" }
            pa_check: { type: "boolean" }
            tx_check: { type: "boolean" }
            ut_check: { type: "boolean" }
            vt_check: { type: "boolean" }
            wa_check: { type: "boolean" }
            wy_check: { type: "boolean" }
          }
        }
      }
      #aggregate: [
      #  { field: "rbo_repTotal", aggregate: "sum" }
      #]
      filter: { field: "year", operator: "eq", value: new Date().getFullYear() }
    })
    return dataSource


  $scope.getGridColumns = () ->
    TEMPLATE_UserNameLink = '# if(typeof name != "undefined" && name) { # <a href="\\#!/admin/masquerade/#:userId#">#:name#</a> # } else if (typeof first_name != "undefined" && typeof last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:userId#">#:first_name# #:last_name#</a> # } else { # <a href="\\#!/admin/masquerade/#:userId#">#:userId#</a> # } # '
    TEMPLATE_Count = "#= data.field#: #=data.value# (total: #= count#)"
    #TEMPLATE_EDIT = '# if(typeof _id != "undefined") { # <a href="\\#!/admin/servicerequest/#:_id#">EDIT</a> # } # '
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"

    gridColumns = []

    #User
    gridColumns.push { field: 'year', title: 'Year', hidden: false  }
    gridColumns.push { field: 'name', title: 'User', hidden: true, template: TEMPLATE_UserNameLink }
    gridColumns.push { field: 'last_name', title: 'Last Name', hidden: false}
    gridColumns.push { field: 'first_name', title: 'First Name', hidden: false}
    gridColumns.push { field: 'client_id', title: 'Client Id', hidden: false }
    gridColumns.push { field: 'isMember', title: 'Is Member', hidden: false }
    gridColumns.push { field: 'isRep', title: 'Is Rep', hidden: true }
    gridColumns.push { field: 'powerOfAttorney', title: 'Power Of Attorney', hidden: true }
    gridColumns.push { field: 'memberStatus', title: 'Member Status', hidden: true }
    gridColumns.push { field: 'memberType', title: 'Member Type', hidden: true }
    gridColumns.push { field: 'memberExpires', title: 'Membership Expires', hidden: true, template: TEMPLATE_formatDate('memberExpires') }
    gridColumns.push { field: 'email', title: 'Email', hidden: true }
    gridColumns.push { field: 'phone_cell', title: 'Phone', hidden: true }

    #Applications
    gridColumns.push { field: 'gen_notes', title: 'General Notes', hidden: false  }
    gridColumns.push { field: 'ak_check', title: 'AK Check', hidden: true  }
    gridColumns.push { field: 'ak_notes', title: 'AK Notes', hidden: true  }
    gridColumns.push { field: 'ak_species', title: 'AK Species', hidden: true  }
    gridColumns.push { field: 'az_check', title: 'AZ Check', hidden: true  }
    gridColumns.push { field: 'az_notes', title: 'AZ Notes', hidden: true  }
    gridColumns.push { field: 'az_species', title: 'AZ Species', hidden: true  }
    gridColumns.push { field: 'ca_check', title: 'CA Check', hidden: true  }
    gridColumns.push { field: 'ca_notes', title: 'CA Notes', hidden: true  }
    gridColumns.push { field: 'ca_species', title: 'CA Species', hidden: true  }
    gridColumns.push { field: 'co_check', title: 'CO Check', hidden: true  }
    gridColumns.push { field: 'co_notes', title: 'CO Notes', hidden: true  }
    gridColumns.push { field: 'co_species', title: 'CO Species', hidden: true  }
    gridColumns.push { field: 'fl_check', title: 'FL Check', hidden: true  }
    gridColumns.push { field: 'fl_notes', title: 'FL Notes', hidden: true  }
    gridColumns.push { field: 'fl_species', title: 'FL Species', hidden: true  }
    gridColumns.push { field: 'ia_check', title: 'IA Check', hidden: true  }
    gridColumns.push { field: 'ia_notes', title: 'IA Notes', hidden: true  }
    gridColumns.push { field: 'ia_species', title: 'IA Species', hidden: true  }
    gridColumns.push { field: 'id_check', title: 'ID Check', hidden: true  }
    gridColumns.push { field: 'id_notes', title: 'ID Notes', hidden: true  }
    gridColumns.push { field: 'id_species', title: 'ID Species', hidden: true  }
    gridColumns.push { field: 'ks_check', title: 'KS Check', hidden: true  }
    gridColumns.push { field: 'ks_notes', title: 'KS Notes', hidden: true  }
    gridColumns.push { field: 'ks_species', title: 'KS Species', hidden: true  }
    gridColumns.push { field: 'ky_check', title: 'KY Check', hidden: true  }
    gridColumns.push { field: 'ky_notes', title: 'KY Notes', hidden: true  }
    gridColumns.push { field: 'ky_species', title: 'KY Species', hidden: true  }
    gridColumns.push { field: 'mt_check', title: 'MT Check', hidden: true  }
    gridColumns.push { field: 'mt_notes', title: 'MT Notes', hidden: true  }
    gridColumns.push { field: 'mt_species', title: 'MT Species', hidden: true  }
    gridColumns.push { field: 'nd_check', title: 'ND Check', hidden: true  }
    gridColumns.push { field: 'nd_notes', title: 'ND Notes', hidden: true  }
    gridColumns.push { field: 'nd_species', title: 'ND Species', hidden: true  }
    gridColumns.push { field: 'nm_check', title: 'NM Check', hidden: true  }
    gridColumns.push { field: 'nm_notes', title: 'NM Notes', hidden: true  }
    gridColumns.push { field: 'nm_species', title: 'NM Species', hidden: true  }
    gridColumns.push { field: 'nv_check', title: 'NV Check', hidden: true  }
    gridColumns.push { field: 'nv_notes', title: 'NV Notes', hidden: true  }
    gridColumns.push { field: 'nv_species', title: 'NV Species', hidden: true  }
    gridColumns.push { field: 'ore_check', title: 'ORE Check', hidden: true  }
    gridColumns.push { field: 'ore_notes', title: 'ORE Notes', hidden: true  }
    gridColumns.push { field: 'ore_species', title: 'ORE Species', hidden: true  }
    gridColumns.push { field: 'sd_check', title: 'SD Check', hidden: true  }
    gridColumns.push { field: 'sd_notes', title: 'SD Notes', hidden: true  }
    gridColumns.push { field: 'sd_species', title: 'SD Species', hidden: true  }
    gridColumns.push { field: 'pa_check', title: 'PA Check', hidden: true  }
    gridColumns.push { field: 'pa_notes', title: 'PA Notes', hidden: true  }
    gridColumns.push { field: 'pa_species', title: 'PA Species', hidden: true  }
    gridColumns.push { field: 'tx_check', title: 'TX Check', hidden: true  }
    gridColumns.push { field: 'tx_notes', title: 'TX Notes', hidden: true  }
    gridColumns.push { field: 'tx_species', title: 'TX Species', hidden: true  }
    gridColumns.push { field: 'ut_check', title: 'UT Check', hidden: true  }
    gridColumns.push { field: 'ut_notes', title: 'UT Notes', hidden: true  }
    gridColumns.push { field: 'ut_species', title: 'UT Species', hidden: true  }
    gridColumns.push { field: 'vt_check', title: 'VT Check', hidden: true  }
    gridColumns.push { field: 'vt_notes', title: 'VT Notes', hidden: true  }
    gridColumns.push { field: 'vt_species', title: 'VT Species', hidden: true  }
    gridColumns.push { field: 'wa_check', title: 'WA Check', hidden: true  }
    gridColumns.push { field: 'wa_notes', title: 'WA Notes', hidden: true  }
    gridColumns.push { field: 'wa_species', title: 'WA Species', hidden: true  }
    gridColumns.push { field: 'wy_check', title: 'WY Check', hidden: true  }
    gridColumns.push { field: 'wy_notes', title: 'WY Notes', hidden: true  }
    gridColumns.push { field: 'wy_species', title: 'WY Species', hidden: true  }


    #gridColumns.push { field: 'modified', title: 'Last Updated', hidden: false, template: TEMPLATE_formatDate('modified') }
    #gridColumns.push { field: 'edit', title: 'EDIT', hidden: false, template: TEMPLATE_EDIT}
    $scope.gridColumns = gridColumns

    return gridColumns

  $scope.init.call(@)
])
