APP = window.APP
APP.Controllers.controller('AdminReportsUsers', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'Report', 'View', ($scope, $rootScope, $location, $modal, Storage, Report, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#reportsUserGrid'
    $scope.TREE_SELECTOR_ID = '#reportsUserTree'
    $scope.user = Storage.get 'user'
    $scope.quicksearch = null
    $scope.loading = false;
    $scope.loadingTree = false;
    $scope.items = []
    $scope.item = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.dateFilterType = null
    $scope.showTabs = $scope.showTabView()
    $scope.showGrid = true
    $scope.showTree = false
    $scope.membersAndRepsOnly = false
    if $scope.user?.isAdmin
      #$scope.loadAll()
      #$scope.loadAllTree($scope.membersAndRepsOnly, false)
      $scope.initGrid()
      $scope.loadSavedViews()
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

  $scope.runQuickSearch = (quicksearch, showAll) ->
    if showAll
      quicksearch = null
      $scope.quicksearch = null
      #$scope.loadAllTree($scope.membersAndRepsOnly, false)
    $scope.loadAll(quicksearch)

  $scope.importUsers = () ->
    window.location = "#!/admin/users/userimport"

  $scope.addNewUser = () ->
    window.location = "#!/admin/users/new"

  $scope.loadAll = (quicksearch) ->
    $scope.loading = true;
    setItems = (results) ->
      items = []
      for item in results
        #Apply any additional calculated fields or logic here
        item.isMember = false unless item.isMember
        item.isRep = false unless item.isRep
        item.isAppUser = false unless item.isAppUser
        items.push item
      $scope.items = results
      $scope.loading = false;
      $scope.setupGrid(JSON.parse(JSON.stringify(results)))

    if $scope.user.isAdmin
      results = Report.adminUsers {quicksearch: quicksearch}, (results) ->
        setItems(results)
      , (err) ->
        console.log "loadAll errored:", err
        $scope.loading = false;

  $scope.loadAllTree = (membersAndRepsOnly, refresh) ->
    return unless typeof membersAndRepsOnly is "boolean"
    $scope.loadingTree = true;
    setItems = (results) ->
      items = []
      for item in results
        #Apply any additional calculated fields or logic here
        item.x = true if item.x
      $scope.treeItems = results
      $scope.loadingTree = false;
      if refresh
        $scope.refreshTree(JSON.parse(JSON.stringify(results)))

      else
        $scope.setupTree(JSON.parse(JSON.stringify(results)))

    if $scope.user.isAdmin
      results = Report.adminUsersTree {membersAndRepsOnly: membersAndRepsOnly}, (results) ->
        setItems(results)
      , (err) ->
        console.log "Report.adminUsersTree errored:", err
        $scope.loadingTree = false;

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

  $scope.setupTree = (tree) ->
    dataSource = new kendo.data.HierarchicalDataSource({
      data: tree
    })
    angular.element($scope.TREE_SELECTOR_ID).kendoTreeView
      dataSource: dataSource
      template: "#if (item.items) {#
                    <span class='#=item.class#'> (#=item.numChildren#) #=item.text# </span>
                  #} else {#
                    <span class='#=item.class#'> #=item.text# </span>
                  #}#"

  $scope.refreshTree = (tree) ->
    dataSource = new kendo.data.HierarchicalDataSource({
      data: tree
    })
    treeView = angular.element($scope.TREE_SELECTOR_ID).data("kendoTreeView")
    treeView.setDataSource(dataSource)


  $scope.setupGrid = (users) ->
    TEMPLATE_UserLink = '# if(typeof name != "undefined" && name) { # <a href="\\#!/admin/masquerade/#:_id#">#:name#</a> # } else if (typeof first_name != "undefined" && typeof last_name != "undefined" && first_name) { # <a href="\\#!/admin/masquerade/#:_id#">#:first_name# #:last_name#</a> # } else if (typeof email != "undefined" && email) { # <a href="\\#!/admin/masquerade/#:_id#">#:email#</a> # } else { # <a href="\\#!/admin/masquerade/#:_id#">#:_id#</a> # } # '
    TEMPLATE_ParentLink = '# if(typeof parentId != "undefined") { # <a href="\\#!/admin/masquerade/#:parentId#">#:parentId#</a> # } # '
    TEMPLATE_ParentNameLink = '# if(typeof parent_name != "undefined" && parent_name) { # <a href="\\#!/admin/masquerade/#:parent__id#">#:parent_name#</a> # } else if (typeof parent_first_name != "undefined" && typeof parent_last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:parent__id#">#:parent_first_name# #:parent_last_name#</a> # } else if (typeof parent__id != "undefined" && parent__id) { # <a href="\\#!/admin/masquerade/#:parent__id#">#:parent__id#</a> # } # '
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"

    dataSource = new kendo.data.DataSource({
      data: users
      pageSize: 50
      sort: {
        field: "created",
        dir: "desc"
      }
      #filter: { field: "type", operator: "eq", value: "Request Hunt Info" }
      schema: {
        model: {
          fields: {
            active: { type: "boolean" }
            isAppUser: { type: "boolean" }
            isAdmin: { type: "boolean" }
            isMember: { type: "boolean" }
            isOutfitter: { type: "boolean" }
            isVendor: { type: "boolean" }
            isRep: { type: "boolean" }
            needsWelcomeEmail: { type: "boolean" }
            needsPointsEmail: { type: "boolean" }
            powerOfAttorney: { type: "boolean" }
            modified: { type: "date" }
            created: { type: "date" }
            createdAt: { type: "date" }
            dob: { type: "date" }
            memberStarted: { type: "date" }
            memberExpires: { type: "date" }
            repStarted: { type: "date" }
            repExpires: { type: "date" }
            rep_next_payment: { type: "date" }
            welcomeEmailSent: { type: "date" }
            pointsEmailSent: { type: "date" }
          }
        }
      }
    })

    gridColumns = []
    gridColumns.push { field: 'name', title: 'Name', hidden: false, template: TEMPLATE_UserLink}
    gridColumns.push { field: 'clientId', title: 'Client Id', hidden: false}
    gridColumns.push { field: 'isMember', title: 'Is Member', hidden: false} if $scope.isRBO()
    gridColumns.push { field: 'isRep', title: 'Is Rep', hidden: false} if $scope.isRBO()
    gridColumns.push { field: 'created', title: 'Created', hidden: false, template: TEMPLATE_formatDate('created')}
    if $scope.isRBO()
      gridColumns.push { field: 'reminderStates', title: 'Reminder States', hidden: true}
      gridColumns.push { field: 'isAppUser', title: 'App user', hidden: true}
      gridColumns.push { field: 'platform', title: 'App Platform', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'parentId', title: 'Parent Id', hidden: true, aggregates: ["count"], template: TEMPLATE_ParentLink, groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'parent__id', title: 'Parent Id', hidden: true, aggregates: ["count"], template: TEMPLATE_ParentLink, groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'parent_name', title: 'Parent Name', hidden: true, aggregates: ["count"], template: TEMPLATE_ParentNameLink, groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'parent_first_name', title: 'Parent First Name', hidden: true}
      gridColumns.push { field: 'parent_last_name', title: 'Parent Last Name', hidden: true}
      gridColumns.push { field: 'parent_clientId', title: 'Parent Client Id', hidden: true}
      gridColumns.push { field: 'parent_email', title: 'Parent Email', hidden: true}
      gridColumns.push { field: '_id', title: 'User Id', hidden: true}
      gridColumns.push { field: 'active', title: 'Active', hidden: true}
      #gridColumns.push { field: 'createdAt', title: 'Created At', hidden: true}
      #gridColumns.push { field: 'modified', title: 'Modified', hidden: true}
      gridColumns.push { field: 'memberId', title: 'Member Id', hidden: true}
      gridColumns.push { field: 'memberType', title: 'Member Type', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'memberStatus', title: 'Member Status', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'memberStarted', title: 'Member Started', hidden: true, template: TEMPLATE_formatDate('memberStarted')}
      gridColumns.push { field: 'memberExpires', title: 'Member Expires', hidden: true, template: TEMPLATE_formatDate('memberExpires')}
      gridColumns.push { field: 'repType', title: 'Rep Type', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'repStatus', title: 'Rep Status', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'repStarted', title: 'Rep Started', hidden: true, template: TEMPLATE_formatDate('repStarted')}
      gridColumns.push { field: 'rep_next_payment', title: 'Rep Next Payment', hidden: true, template: TEMPLATE_formatDate('rep_next_payment')}
      gridColumns.push { field: 'repExpires', title: 'Rep Expires', hidden: true, template: TEMPLATE_formatDate('repExpires')}
      gridColumns.push { field: 'referredBy', title: 'Referred By', hidden: true}
      gridColumns.push { field: 'dob', title: 'DOB', hidden: true, template: TEMPLATE_formatDate('dob')}
    gridColumns.push { field: 'email', title: 'Email', hidden: false}
    gridColumns.push { field: 'first_name', title: 'First Name', hidden: true}
    gridColumns.push { field: 'last_name', title: 'Last Name', hidden: true}
    gridColumns.push { field: 'middle_name', title: 'Middle Name', hidden: true}
    gridColumns.push { field: 'gender', title: 'Gender', hidden: true}
    if $scope.isRBO()
      gridColumns.push { field: 'isAdmin', title: 'Is Admin', hidden: true}
      gridColumns.push { field: 'isOutfitter', title: 'Is Outfitter', hidden: true}
      gridColumns.push { field: 'imported', title: 'Imported', hidden: true}
      gridColumns.push { field: 'internalNotes', title: 'Internal Notes', hidden: true}
      gridColumns.push { field: 'needsWelcomeEmail', title: 'Needs Welcome Email', hidden: true}
      gridColumns.push { field: 'welcomeEmailSent', title: 'Welcome Email Sent', hidden: true, template: TEMPLATE_formatDate('welcomeEmailSent')}
      gridColumns.push { field: 'needsPointsEmail', title: 'Needs Points Email', hidden: true}
      gridColumns.push { field: 'pointsEmailSent', title: 'Points Email Sent', hidden: true, template: TEMPLATE_formatDate('pointsEmailSent')}
    gridColumns.push { field: 'mail_address', title: 'Mail Address', hidden: true}
    gridColumns.push { field: 'mail_city', title: 'Mail City', hidden: true}
    gridColumns.push { field: 'mail_country', title: 'Mail Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'mail_postal', title: 'Mail Postal', hidden: true}
    gridColumns.push { field: 'mail_state', title: 'Mail State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'phone_cell', title: 'Phone Cell', hidden: true}
    gridColumns.push { field: 'phone_cell_carrier', title: 'Phone Cell Carrier', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'phone_day', title: 'Phone Day', hidden: true}
    gridColumns.push { field: 'phone_home', title: 'Phone Home', hidden: true}
    gridColumns.push { field: 'physical_address', title: 'Physical Address', hidden: true}
    gridColumns.push { field: 'physical_city', title: 'Physical City', hidden: true}
    gridColumns.push { field: 'physical_country', title: 'Physical Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'physical_postal', title: 'Physical Postal', hidden: true}
    gridColumns.push { field: 'physical_state', title: 'Physical State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    if $scope.adminTenantEdit()
      gridColumns.push { field: 'isVendor', title: 'Is Vendor', hidden: true}
      gridColumns.push { field: 'isOutfitter', title: 'Is Outfitter', hidden: true}

    if $scope.isRBO()
      gridColumns.push { field: 'powerOfAttorney', title: 'Power Of Attorney', hidden: true}
      gridColumns.push { field: 'residence', title: 'Residence', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'source', title: 'Source', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
      gridColumns.push { field: 'username', title: 'Username', hidden: true}

    if $scope.adminFullEdit()
      $scope.toolbar = ["excel", "Save Current View"]
      gridColumns.push { field: 'payment_customerProfileId', title: 'AUTH.NET Customer Profile Id', hidden: true}
      gridColumns.push { field: 'payment_paymentProfileId', title: 'AUTH.NET Payment Profile Id', hidden: true}
    else
      $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "user_report.xlsx",
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
      if $scope.user.isAdmin
        #TODO
        console.log "DEBUG: $scope.item dblclick()", $scope.item
        #window.location = "#!/admin/huntcatalog/#{$scope.huntCatalog._id}"
    )

  $scope.editRow = ($event) ->
    $event.preventDefault()
    item = this.dataItem($($event.currentTarget).closest("tr"));
    if $scope.user.isAdmin
      #TODO
      console.log "DEBUG: $scope.item dblclick()", item
      #window.location = "#!/admin/huntcatalog/#{huntCatalog._id}"

  $scope.loadGridView = (customView) ->
    return window.location.reload() unless customView
    options = JSON.parse(customView.options)
    options.toolbar = $scope.toolbar
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    grid.dataSource.filter({}) #clear previous filters
    grid.setOptions(options) #apply new filters
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
    dateColumn = "created"
    ###  TODO: May want to switch autofilters date range to be on these dates rather than created depending on the report?
    if $scope.customView?.name?.toLowerCase().indexOf("member") > -1
      dateColumn = "memberStarted"
    if $scope.customView?.name?.toLowerCase().indexOf("rep") > -1
      dateColumn = "repStarted"
    ###
    if $scope.customView?.name?.toLowerCase().indexOf("memberships expiring") > -1
      dateColumn = "memberExpires"

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

  $scope.showTabView = () ->
    if window?.tenant?._id?.toString() is "5684a2fc68e9aa863e7bf182" or window?.tenant?._id?.toString() is "5bd75eec2ee0370c43bc3ec7" #RBO
      return true
    else
      return false

  $scope.toogleTab = ($event, tab) ->
    $event.preventDefault()
    $scope.showGrid = true
    $scope.showTree = false
    #if tab is "users"
    #  $scope.showGrid = true
    #  $scope.showTree = false
    #else if tab is "family"
    #  $scope.showGrid = false
    #  $scope.showTree = true

  $scope.toogleTreeExpand = (type) ->
    treeview = angular.element($scope.TREE_SELECTOR_ID).data("kendoTreeView")
    if type is "collapse"
      treeview.collapse(".k-item")
    else if type is "expand"
      treeview.expand(".k-item")

  $scope.refreshTreeView = ($event, membersAndRepsOnly) ->
    $scope.membersAndRepsOnly = membersAndRepsOnly
    $scope.loadAllTree(membersAndRepsOnly, true)

  $scope.init.call(@)
])
