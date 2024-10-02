APP = window.APP
APP.Controllers.controller('AdminHuntCatalogs', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'HuntCatalog', 'View', ($scope, $rootScope, $location, $modal, Storage, HuntCatalog, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#huntCatalogsGrid'
    $scope.user = Storage.get 'user'
    $scope.loadingHuntCatalogs = false;
    $scope.huntCatalogs = []
    $scope.huntCatalog = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    if $scope.user?.isAdmin || $scope.user?.userType == 'tenant_manager'
      $scope.loadAllHuntCatalogs()
      $scope.initGrid()
      $scope.loadSavedViews()
    else
      alert "Unauthorized error"

  $scope.loadAllHuntCatalogs = () ->
    $scope.loadingHuntCatalogs = true;
    setHunts = (results) ->
      hunts = []
      for hunt in results
        hunt.isActive = false unless hunt.isActive
        hunt.rboNet = hunt.rbo_commission - hunt.rbo_reps_commission
        hunts.push hunt
      $scope.huntCatalogs = results
      $scope.loadingHuntCatalogs = false;
      $scope.setupGrid(JSON.parse(JSON.stringify(results)))

    if $scope.user.isAdmin || $scope.user?.userType == 'tenant_manager'
      if $scope.user?.userType == 'tenant_manager'
        outfitterId = $scope.user._id
      else
        outfitterId = null
      results = HuntCatalog.adminIndex {outfitterId: outfitterId}, (results) ->
        setHunts(results)
      , (err) ->
        console.log "loadAllHuntCatalogs errored:", err
        $scope.loadingHuntCatalogs = false;

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


  $scope.setupGrid = (huntCatalogs) ->
    #console.log "huntCatalogs:", huntCatalogs

    TEMPLATE_HCTitleLink = '# if(typeof title != "undefined" && title) { # <a href="\\#!/admin/huntcatalog/#:_id#">#:title#</a> # } else { #  # } # '

    TEMPLATE_formatMoney = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseFloat(#{fieldKey}), 'c') : '' #"

    dataSource = new kendo.data.DataSource({
      data: huntCatalogs
      pageSize: 50
      sort: {
        field: "updatedAt",
        dir: "desc"
      }
      #filter: { field: "type", operator: "eq", value: "Request Hunt Info" }
      schema: {
        model: {
          fields: {
            isActive: { type: "boolean" }
            isHuntSpecial: { type: "boolean" }
            createMember: { type: "boolean" }
            createRep: { type: "boolean" }
            #budgetStart: { type: "number" }
            #budgetEnd: { type: "number" }
            price: { type: "number" }
            price_total: { type: "number" }
            fee_processing: { type: "number" }
            rbo_commission: { type: "number" }
            rbo_reps_commission: { type: "number" }
            rboNet: { type: "number" }
            startDate: { type: "date" }
            endDate: { type: "date" }
            updatedAt: { type: "date" }
            createdAt: { type: "date" }
          }
        }
      }
    })

    gridColumns = []
    gridColumns.push { field: 'huntNumber', title: 'Hunt Number', hidden: false} if $scope.user.isAdmin
    gridColumns.push { field: 'title', title: 'Title', hidden: false, template: TEMPLATE_HCTitleLink }
    gridColumns.push { field: 'price', title: 'Price', hidden: false, aggregates: ["count"], template: TEMPLATE_formatMoney('price'), groupHeaderTemplate: "Price: #= data.value# (total: #= count#)"}
    gridColumns.push { field: 'type', title: "Type", hidden: false}
    gridColumns.push { field: 'startDate', title: 'Date Starts', hidden: true, template: "#= (data.startDate) ? kendo.toString(kendo.parseDate(startDate), 'MM/dd/yyyy') : '' #" }
    gridColumns.push { field: 'endDate', title: 'Date Ends', hidden: true, template: "#= (data.endDate) ? kendo.toString(kendo.parseDate(endDate), 'MM/dd/yyyy') : '' #" }
    gridColumns.push {field: 'isActive', title: 'Viewable', hidden:true, filterable: { messages: { isTrue: "True", isFalse: "False" } }} if $scope.user.isAdmin
    gridColumns.push { field: 'status', title: "Status", hidden: false}
    gridColumns.push { field: 'paymentPlan', title: "Payment Plan", hidden: true} if $scope.user.isAdmin
    gridColumns.push { field: 'isHuntSpecial', title: 'Hunt Special', hidden: true, filterable: { messages: { isTrue: "True", isFalse: "False" } } }
    gridColumns.push { field: 'createMember', title: 'Create Membership', hidden: true, filterable: { messages: { isTrue: "True", isFalse: "False" } } }
    gridColumns.push { field: 'createRep', title: 'Create Rep', hidden: true, filterable: { messages: { isTrue: "True", isFalse: "False" } } }
    gridColumns.push { field: 'outfitter_name', title: 'Outfitter', hidden: true, template: '# if(typeof outfitter_name != "undefined") { # <a href="\\#!/admin/outfitter/#:outfitter_userId#">#:outfitter_name#</a> # } # ' } if $scope.user.isAdmin or $scope.user.userType == 'tenant_manager'
    gridColumns.push { field: 'country', title: 'Country', hidden: true }
    gridColumns.push { field: 'state', title: 'State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "State: #= data.value# (total: #= count#)" }
    gridColumns.push { field: 'area', title: 'Area', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Location: #= data.value# (total: #= count#)" }
    gridColumns.push { field: 'species', title: 'Species', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Species: #= data.value# (total: #= count#)" }
    gridColumns.push { field: 'classification', title: 'Classification', hidden: true }
    gridColumns.push { field: 'weapon', title: 'Weapon', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Weapon: #= data.value# (total: #= count#)" }
    #gridColumns.push { field: 'budgetStart', title: 'Budget Starts', aggregates: ["count"], groupHeaderTemplate: "Budget: #= data.value# (total: #= count#)", template: "#= (data.budgetStart) ? kendo.toString(kendo.parseInt(budgetStart), 'c0') : '' #" } unless $scope.user.isAdmin
    #gridColumns.push { field: 'budgetStart', title: 'Budget Starts', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Budget: #= data.value# (total: #= count#)", template: "#= (data.budgetStart) ? kendo.toString(kendo.parseInt(budgetStart), 'c0') : '' #" } if $scope.user.isAdmin
    #gridColumns.push { field: 'budgetEnd', title: 'Budget Ends', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Budget: #= data.value# (total: #= count#)", template: "#= (data.budgetEnd) ? kendo.toString(kendo.parseInt(budgetEnd), 'c0') : '' #" }
    gridColumns.push { field: 'huntSpecialMessage', title: 'Special Msg', hidden: true }
    gridColumns.push { field: 'description', title: 'Description', hidden: true }
    if $scope.user.isAdmin
      gridColumns.push { field: 'fee_processing', title: 'Processing Fee', hidden: false, aggregates: ["count"], template: TEMPLATE_formatMoney('fee_processing')}
      gridColumns.push { field: 'price_total', title: 'Total Price', hidden: false, aggregates: ["count"], template: TEMPLATE_formatMoney('price_total'), groupHeaderTemplate: "Total Price: #= data.value# (total: #= count#)"}
      gridColumns.push { field: 'rbo_commission', title: 'RBO Commission', hidden: true, aggregates: ["count"], template: TEMPLATE_formatMoney('rbo_commission'), groupHeaderTemplate: "RBO Commission: #= data.value# (total: #= count#)"}
      gridColumns.push { field: 'rbo_reps_commission', title: 'Rep Commission Amount', hidden: true, aggregates: ["count"], template: TEMPLATE_formatMoney('rbo_reps_commission'), groupHeaderTemplate: "Rep Commission: #= data.value# (total: #= count#)"}
      gridColumns.push { field: 'rboNet', title: 'RBO Comm - Reps', hidden: true, aggregates: ["count"], template: TEMPLATE_formatMoney('rboNet'), groupHeaderTemplate: "RBO Comm - Reps: #= data.value# (total: #= count#)"}
      gridColumns.push { field: 'updatedAt', title: 'Last Updated', hidden: true, template: "#= (data.updatedAt) ? kendo.toString(kendo.parseDate(updatedAt), 'MM/dd/yyyy') : '' #" }
      gridColumns.push { field: 'createdAt', title: 'Created', hidden: true, template: "#= (data.createdAt) ? kendo.toString(kendo.parseDate(createdAt), 'MM/dd/yyyy') : '' #" }
      gridColumns.push { field: 'internalNotes', title: 'Internal Notes', hidden: true }

    if $scope.user.isAdmin
      $scope.toolbar = ["excel", "Save Current View"]
    else
      $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "HuntCatalog.xlsx",
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
    $scope.huntCatalog = null
    $scope.huntCatalog = this.dataItem(this.select());
    #console.log "$scope.huntCatalog", $scope.huntCatalog

  $scope.initGrid = () ->
    angular.element($scope.GRID_SELECTOR_ID).delegate(' table tr', 'dblclick', () ->
      if $scope.user.isAdmin
        window.location = "#!/admin/huntcatalog/#{$scope.huntCatalog._id}"
    )

  $scope.editRow = ($event) ->
    $event.preventDefault()
    huntCatalog = this.dataItem($($event.currentTarget).closest("tr"));
    if $scope.user.isAdmin
      window.location = "#!/admin/huntcatalog/#{huntCatalog._id}"

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


  $scope.init.call(@)
])
