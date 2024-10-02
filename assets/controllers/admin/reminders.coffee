APP = window.APP
APP.Controllers.controller('AdminReminders', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'Reminder', 'View', 'User', ($scope, $rootScope, $location, $modal, Storage, Reminder, View, User) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#remindersGrid'
    $scope.user = Storage.get 'user'
    $scope.loading = false;
    $scope.items = []
    $scope.item = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.dateFilterType = null
    if $scope.user?.isAdmin
      $scope.getTestUsers () ->
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


  $scope.getTestUsers = (cb) ->
    User.testUsers {tenantId: $scope.tenant._id}, (rsp) ->
      #success
      for testUser in rsp
        testUser.displayName = "#{testUser.first_name} #{testUser.last_name}"
        testUser.displayName += " - #{testUser.clientId}" if testUser.clientId
      $scope.testUsers = rsp
      return cb()
    ,
      (err) ->
        console.log "Failed to get list of test users. Error: ", err


  $scope.loadItems = (firstTime) ->
    $scope.loading = true;
    setItems = (results) ->
      items = []
      for item in results.reminders
        #item.start = new Date(item.start) if item.start
        #item.end = new Date(item.end) if item.end
        item.start = moment(item.start, 'YYYY-MM-DD').toDate()
        item.end = moment(item.end, 'YYYY-MM-DD').toDate()
        item.send_open = new Date(item.send_open) if item.send_open
        item.send_close = new Date(item.send_close) if item.send_close
        item.validatedOn = new Date(item.validatedOn) if item.validatedOn
        item.testUserId = "" unless item.testUserId
        for testUser in $scope.testUsers
          if testUser._id is item.testUserId
            if testUser.displayName
              item.testUser_name = testUser.displayName
            else if testUser.name
              item.testUser_name = testUser.name
            else if testUser.first_name or testUser.last_name
              item.testUser_name = "#{testUser.first_name} #{testUser.last_name}"
            else
              item.testUser_name = testUser._id
            break

        if item.isDrawResultUnsuccess is true or item.isDrawResultSuccess is true
          console.log "Skipping Draw Result Item: ", item.title
        else
          items.push item
      $scope.items = items
      $scope.loading = false;
      if firstTime
        $scope.setupGrid(JSON.parse(JSON.stringify(items)))
      else
        $scope.setGridItems(JSON.parse(JSON.stringify(items)))

    if $scope.user.isAdmin
      results = Reminder.adminIndex {all:true}, (results) ->
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
      window.location = "#!/admin/reminder/#{$scope.item._id}"
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

  $scope.addReminder = ($event) ->
    $event.preventDefault()
    if $scope.user.isAdmin
      window.location = "#!/admin/reminder/new"

  $scope.editRow = ($event) ->
    $event.preventDefault()
    item = this.dataItem($($event.currentTarget).closest("tr"));
    if $scope.user.isAdmin
      window.location = "#!/admin/reminder/#{item._id}"

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
    dateColumn = "start"
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
        fileName: "Reminders.xlsx",
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
        field: "start",
        dir: "desc"
      }
      schema: {
        model: {
          id: "_id"
          fields: {
            start: { type: "date" }
            end: { type: "date" }
            send_open: { type: "date" }
            send_close: { type: "date" }
            validatedOn: { type: "date" }
            active: { type: "boolean" }
            isDrawResultSuccess: { type: "boolean" }
            isDrawResultUnsuccess: { type: "boolean" }
          }
        }
      }
      #aggregate: [
      #  { field: "rbo_repTotal", aggregate: "sum" }
      #]
      #filter: { field: "type", operator: "neq", value: "Purchase" }
    })
    return dataSource


  $scope.getGridColumns = () ->
    TEMPLATE_UserNameLink = '# if(typeof testUser_name != "undefined" && testUser_name) { # <a href="\\#!/admin/masquerade/#:testUserId#">#:testUser_name#</a> # } else { # <a href="\\#!/admin/masquerade/#:testUserId#">#:testUserId#</a> # } # '
    TEMPLATE_Count = "#= data.field#: #=data.value# (total: #= count#)"
    TEMPLATE_EDIT = '# if(typeof _id != "undefined") { # <a href="\\#!/admin/reminder/#:_id#">EDIT</a> # } # '
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"

    gridColumns = []

    gridColumns.push { field: 'active', title: 'Active', hidden: false  }
    gridColumns.push { field: 'title', title: 'Title', hidden: false }
    gridColumns.push { field: 'state', title: 'State', hidden: false, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'start', title: 'Open Date', template: TEMPLATE_formatDate('start') }
    gridColumns.push { field: 'end', title: 'Close Date', template: TEMPLATE_formatDate('end') }
    gridColumns.push { field: 'testUser_name', title: 'Test User', hidden: false, template: TEMPLATE_UserNameLink }
    gridColumns.push { field: 'send_open', title: 'Send Open On', template: TEMPLATE_formatDate('send_open') }
    gridColumns.push { field: 'send_close', title: 'Send Close On', template: TEMPLATE_formatDate('send_close') }
    gridColumns.push { field: 'txtStart', title: 'Text Msg (Start)', hidden: true  }
    gridColumns.push { field: 'txtEnd', title: 'Text Msg (End)', hidden: true  }
    gridColumns.push { field: 'website_link', title: 'Website', hidden: true  }
    gridColumns.push { field: 'edit', title: 'EDIT', hidden: false, template: TEMPLATE_EDIT}
    gridColumns.push { field: 'validatedOn', title: 'Last Validated on', template: TEMPLATE_formatDate('validatedOn') }

    $scope.gridColumns = gridColumns

    return gridColumns

  $scope.init.call(@)
])
