APP = window.APP
APP.Controllers.controller('RBO_REP_USERS', ['$scope', '$rootScope', '$location', '$modal', '$routeParams' ,'Storage', 'Report', 'View', 'User', ($scope, $rootScope, $location, $modal, $routeParams, Storage, Report, View, User) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#repUsersGrid'
    $scope.user = Storage.get 'user'
    $scope.loading = false;
    $scope.includeProspects = false
    $scope.view = $routeParams.view if $routeParams.view
    $scope.items = []
    $scope.item = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.dateFilterType = "this_month"
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
    $scope.allStart = moment("09/01/2017")
    $scope.allEnd = moment()
    $scope.startDate = new Date($scope.thisMonthStart)
    $scope.endDate = new Date($scope.thisMonthEnd)
    if !$scope.user?.isRep
      alert "Unauthorized error"
      window.location = "#!/dashboard"

  $scope.addNewUser = () ->
    window.location = "#!/admin/users/new"

  $scope.resendWelcomeEmail = (grid) ->
    selectedItems = grid.selectedKeyNames()
    if selectedItems?.length > 0
      kendo.confirm("Confirming resend welcome emails to #{selectedItems.length} selected users.")
      .then () ->
        results = User.sendWelcomeEmails {userIds: selectedItems}, (results) ->
          alert "Welcome emails resent successfully."
        , (err) ->
          console.log "Resend welcome emails errored:", err
          msg = ""
          msg += "#{err.data}" if err.data
          alert "An error occured sending emails. #{msg}"
      , () ->
        console.log "Cancelled resend welcome emails"
    else
      alert "It looks like you haven't marked any users for resending the welcome email.  Please first click the checkbox next to the users you would like to resend the welecome email, and then click the 'Resend Welcome Emails' button again."

  $scope.submit = ($event, quicksearch, showAll) ->
    $event.preventDefault() if $event
    if $scope.user?.isRep
      if showAll
        quicksearch = null
        $scope.quicksearch = null
      $scope.refreshGrid(quicksearch)
    else
      alert "Unauthorized error"

  $scope.refreshGrid = (quicksearch) ->
    $scope.loading = true
    $scope.destroyGrid()
    $scope.initGrid()
    if $scope.user?.isRep
      results = Report.repUsers {quicksearch: quicksearch, userId: $scope.user._id, includeProspects: $scope.includeProspects}, (results) ->
        #results = Report.repUsersDownstream {userId: $scope.user._id}, (results) ->
        $scope.items = $scope.setItems(results)
        dataSource = $scope.getNewDataSource($scope.items)
        $scope.setupGrid(dataSource)
        $scope.loadSavedViews()
        $scope.loading = false
      , (err) ->
        console.log "setItems errored:", err
        $scope.loading = false;
    else
      alert "Unauthorized error"

  $scope.setItems = (results) ->
    items = []
    for item in results
      #Apply any additional calculated fields or logic here
      item.isMember = false unless item.isMember
      item.isRep = false unless item.isRep
      item.isAppUser = false unless item.isAppUser
      items.push item
    return items

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


  $scope.getNewDataSource = (items) ->
    dataSource = new kendo.data.DataSource({
      data: items
      pageSize: 50
      sort: {
        field: "createdAt",
        dir: "desc"
      }
      #filter: { field: "type", operator: "eq", value: "Request Hunt Info" }
      schema: {
        model: {
          id: "_id"
          fields: {
            active: { type: "boolean" }
            isAppUser: { type: "boolean" }
            isMember: { type: "boolean" }
            isRep: { type: "boolean" }
            created: { type: "date" }
            memberExpires: { type: "date" }
            repExpires: { type: "date" }
            rep_next_payment: { type: "date" }
            leveldown: { type: "number" }
          }
        }
      }
      aggregate: [
        { field: "xxx", aggregate: "sum" },
      ]
    })
    return dataSource


  $scope.setupGrid = (dataSource) ->
    TEMPLATE_UserNameLink = '# if(typeof name != "undefined" && name) { # <a href="\\#!/admin/masquerade/#:userId#">#:name#</a> # } else if (typeof first_name != "undefined" && typeof last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:userId#">#:first_name# #:last_name#</a> # } else { # <a href="\\#!/admin/masquerade/#:userId#">#:userId#</a> # } # '
    TEMPLATE_ParentNameLink = '# if(typeof parent_name != "undefined" && parent_name) { # <a href="\\#!/admin/masquerade/#:parent__id#">#:parent_name#</a> # } else if (typeof parent_first_name != "undefined" && typeof parent_last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:parent__id#">#:parent_first_name# #:parent_last_name#</a> # } else if (typeof parent__id != "undefined" && parent__id) { # <a href="\\#!/admin/masquerade/#:parent__id#">#:parent__id#</a> # } # '
    TEMPLATE_Count = "#= data.field#: #=data.value# (total: #= count#)"
    TEMPLATE_Sum = (title) ->
      #return "#{title} Total: #=sum#"
      return "Total: #=kendo.toString(kendo.parseFloat(sum), 'c')#"
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"
    TEMPLATE_formatMoney = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseFloat(#{fieldKey}), 'c') : '' #"
    TEMPLATE_formatPercent = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseFloat(#{fieldKey}), 'p') : kendo.toString(kendo.parseFloat(0), 'c') #"


    gridColumns = []
    gridColumns.push { selectable: true, width: "50px"}
    gridColumns.push { field: 'leveldown', title: 'Level', hidden: false, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'name', title: 'Name', hidden: false, template: TEMPLATE_UserNameLink}
    gridColumns.push { field: 'clientId', title: 'Client Id', hidden: false}
    gridColumns.push { field: 'email', title: 'Email', hidden: false}
    gridColumns.push { field: 'isMember', title: 'Is Member', hidden: false}
    gridColumns.push { field: 'isRep', title: 'Is Rep', hidden: false}
    gridColumns.push { field: 'parent_name', title: 'Parent', hidden: false,  aggregates: ["count"], template: TEMPLATE_ParentNameLink, groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'created', title: 'Created', hidden: false, template: TEMPLATE_formatDate('created')}
    gridColumns.push { field: 'reminderStates', title: 'Reminder States', hidden: true}
    #gridColumns.push { field: 'isAppUser', title: 'App user', hidden: true}
    #gridColumns.push { field: 'platform', title: 'App Platform', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'first_name', title: 'First Name', hidden: true}
    gridColumns.push { field: 'last_name', title: 'Last Name', hidden: true}
    gridColumns.push { field: 'middle_name', title: 'Middle Name', hidden: true}
    gridColumns.push { field: 'mail_address', title: 'Mail Address', hidden: true}
    gridColumns.push { field: 'mail_city', title: 'Mail City', hidden: true}
    gridColumns.push { field: 'mail_country', title: 'Mail Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'mail_postal', title: 'Mail Postal', hidden: true}
    gridColumns.push { field: 'mail_state', title: 'Mail State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'memberStatus', title: 'Member Status', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'memberStarted', title: 'Member Started', hidden: true, template: TEMPLATE_formatDate('memberStarted')}
    gridColumns.push { field: 'memberExpires', title: 'Member Expires', hidden: true, template: TEMPLATE_formatDate('memberExpires')}
    gridColumns.push { field: 'repType', title: 'Rep Type', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'repStatus', title: 'Rep Status', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'repStarted', title: 'Rep Started', hidden: true, template: TEMPLATE_formatDate('repStarted')}
    gridColumns.push { field: 'repExpires', title: 'Rep Expires', hidden: true, template: TEMPLATE_formatDate('repExpires')}
    gridColumns.push { field: 'phone_cell', title: 'Phone Cell', hidden: true}
    gridColumns.push { field: 'physical_address', title: 'Physical Address', hidden: true}
    gridColumns.push { field: 'physical_city', title: 'Physical City', hidden: true}
    gridColumns.push { field: 'physical_country', title: 'Physical Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'physical_postal', title: 'Physical Postal', hidden: true}
    gridColumns.push { field: 'physical_state', title: 'Physical State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }

    gridColumns = $scope.showGridColumns(gridColumns)
    $scope.gridColumns = gridColumns

    if $scope.user.isAdmin
      $scope.toolbar = ["excel", "Save Current View", "Resend Welcome Emails"]
    else if $scope.user.repType is "Agency Manager"
      $scope.toolbar = ["excel", "Resend Welcome Emails"]
    else
      $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "users.xlsx",
        filterable: true
      },
      change: $scope.setSelected
      groupable: true
      sortable: true
      #selectable: 'multiple'
      persistSelection: true
      reorderable: true
      resizable: true
      filterable: true
      columnMenu: true
      pageable:
        pageSizes: [ 50,100,200,500,1000,10000,'All' ]
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
          }
        }
      },
      columns: gridColumns

    angular.element($scope.GRID_SELECTOR_ID).delegate('.k-grid-SaveCurrentView', 'click', ($event) ->
      $event.preventDefault()
      $scope.saveCurrentView(angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid"))
    )

    angular.element($scope.GRID_SELECTOR_ID).delegate('.k-grid-ResendWelcomeEmails', 'click', ($event) ->
      $event.preventDefault()
      $scope.resendWelcomeEmail(angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid"))
    )

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

  $scope.setSelected = (args) ->
    $scope.item = null
    $scope.item = this.dataItem(this.select());

  $scope.initGrid = () ->
    angular.element($scope.GRID_SELECTOR_ID).delegate(' table tr', 'dblclick', () ->
      if $scope.user.isRep
        console.log "dbl click on item: ", $scope.item._id
    )

  $scope.destroyGrid = () ->
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    if grid
      grid.destroy()
      angular.element($scope.GRID_SELECTOR_ID).empty()

  $scope.loadGridView = (customView) ->
    return window.location.reload() unless customView
    options = JSON.parse(customView.options)
    options.toolbar = $scope.toolbar
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    grid.dataSource.filter({}) #clear previous filters
    grid.setOptions(options) #apply new filters
  #grid.refresh();

  #Just keep the same columns hidden/showing, but use all updated column details/settings
  #for savedColumn in options.columns
  #  for column in $scope.gridColumns
  #    if column.field is savedColumn.field
  #      column.hidden = savedColumn.hidden #note not cloning here, just modifying the actual $scope reference.
  #      break
  #options.columns = $scope.gridColumns
  #grid.setOptions(options) #apply new filters
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

  $scope.formatMoneyStr = (number) ->
    number = number.toFixed(2) if number
    return number unless number?.toString()
    numberAsMoneyStr = number.toString()
    mpStrArry = numberAsMoneyStr.split(".")
    if mpStrArry?.length > 0 and mpStrArry[1]?.length == 1
      numberAsMoneyStr = "#{number}0"
    else
      numberAsMoneyStr = "#{number}"
    return numberAsMoneyStr

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

  $scope.setDateRange = (dateFilterType) ->
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
      when "all"
        startDate = $scope.allStart
        endDate = $scope.allEnd
    $scope.startDate = new Date(startDate)
    $scope.endDate = new Date(endDate)

  $scope.showGridColumns = (gridColumns) ->
    showColumns = []
    if $scope.view is "xxxx"
      showColumns = [
        'createdAt', 'TOTAL_PRICE', 'amountPaid', 'percentPaid'
      ]

    if showColumns?.length
      for gridColumn in gridColumns
        if showColumns.indexOf(gridColumn.field) > -1
          gridColumn.hidden = false
        else
          gridColumn.hidden = true

    return gridColumns

  $scope.init.call(@)
])
