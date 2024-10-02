APP = window.APP
APP.Controllers.controller('HuntCatalogs', ['$scope', '$rootScope', '$location', '$routeParams', '$modal', 'Storage', 'HuntCatalog', 'View', ($scope, $rootScope, $location, $routeParams, $modal, Storage, HuntCatalog, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#huntCatalogsGrid'
    $scope.user = Storage.get 'user'
    $scope.loadingHuntCatalogs = false;
    $scope.huntCatalogs = []
    $scope.huntCatalog = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.loadAllHuntCatalogs()
    $scope.initGrid()
    $scope.loadSavedViews()
    $scope.parentClientId = $routeParams.ref
    $scope.titleFilter = $routeParams.title if $routeParams?.title
    $scope.numberFilter = $routeParams.number if $routeParams?.number
    $scope.typeFilter = $routeParams.type if $routeParams?.type

  $scope.loadAllHuntCatalogs = () ->
    $scope.loadingHuntCatalogs = true;
    setHunts = (results) ->
      hunts = []
      for hunt in results
        hunt.isActive = false unless hunt.isActive
        #For backwards compatibility
        if !hunt.fee_processing
          hunt.fee_processing = 0
        if !hunt.price_total
          hunt.price_total = hunt.price + hunt.fee_processing
        hunts.push hunt

      $scope.huntCatalogs = results
      $scope.loadingHuntCatalogs = false;
      $scope.setupGrid(JSON.parse(JSON.stringify(results)))

    results = HuntCatalog.index (results) ->
      setHunts(results)
    , (err) ->
      console.log "loadAllHuntCatalogs errored:", err
      $scope.loadingHuntCatalogs = false;

  $scope.loadSavedViews = () ->
    viewFindData = {
      tenantId: window.tenant._id
      selector: $scope.GRID_SELECTOR_ID
      userId: $scope.user._id if $scope.user?._id
    }
    results = View.find viewFindData, (results) ->
      $scope.customViews = results
    , (err) ->
      console.log "loadSavedViews errored:", err


  $scope.setupGrid = (huntCatalogs) ->
    #console.log "huntCatalogs:", huntCatalogs

    TEMPLATE_HCTitleLink = '# if(typeof title != "undefined" && title) { # <a href="\\#!/huntcatalog/#:_id#">#:title#</a> # } else { #  # } # '
    TEMPLATE_formatMoney = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseFloat(#{fieldKey}), 'c') : '' #"

    dataSource = new kendo.data.DataSource({
      data: huntCatalogs
      pageSize: 50
      sort: {
        field: "updatedAt",
        dir: "desc"
      }
      schema: {
        model: {
          fields: {
            isActive: { type: "boolean" }
            isHuntSpecial: { type: "boolean" }
            #budgetStart: { type: "number" }
            #budgetEnd: { type: "number" }
            price_total: { type: "number" }
            price: { type: "number" }
            startDate: { type: "date" }
            endDate: { type: "date" }
            updatedAt: { type: "date" }
            createdAt: { type: "date" }
          }
        }
      }
    })

    filters = []
    filters.push { field: "title", operator: "contains", value: $scope.titleFilter } if $scope.titleFilter
    filters.push { field: "huntNumber", operator: "contains", value: $scope.numberFilter } if $scope.numberFilter
    filters.push { field: "type", operator: "contains", value: $scope.typeFilter } if $scope.typeFilter
    if filters.length
      dataSource.filter({
        logic: "and",
        filters: filters
      })

    gridColumns = []
    gridColumns.push { field: 'huntNumber', title: 'Hunt Number', hidden: false}
    gridColumns.push { field: 'title', title: 'Title', hidden: false, template: TEMPLATE_HCTitleLink }
    gridColumns.push { field: 'status', title: "Status", hidden: true}
    gridColumns.push { field: 'type', title: "Type", hidden: true}
    gridColumns.push { field: 'isHuntSpecial', title: 'Hunt Special', hidden: true, filterable: { messages: { isTrue: "True", isFalse: "False" } } }
    gridColumns.push { field: 'country', title: 'Country', hidden: true }
    gridColumns.push { field: 'state', title: 'State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "State: #= data.value# (total: #= count#)" }
    gridColumns.push { field: 'area', title: 'Area', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Location: #= data.value# (total: #= count#)" }
    gridColumns.push { field: 'species', title: 'Species', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Species: #= data.value# (total: #= count#)" }
    gridColumns.push { field: 'classification', title: 'Classification', hidden: true }
    gridColumns.push { field: 'weapon', title: 'Weapon', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Weapon: #= data.value# (total: #= count#)" }
    #gridColumns.push { field: 'budgetEnd', title: 'Budget Ends', hidden: true, aggregates: ["count"], groupHeaderTemplate: "Budget: #= data.value# (total: #= count#)", template: "#= (data.budgetEnd) ? kendo.toString(kendo.parseInt(budgetEnd), 'c0') : '' #" }
    gridColumns.push { field: 'price_total', title: 'Price', hidden: false, aggregates: ["count"], template: TEMPLATE_formatMoney('price_total'), groupHeaderTemplate: "Price: #= data.value# (total: #= count#)"}
    gridColumns.push { field: 'startDate', title: 'Date Starts', hidden: true, template: "#= (data.startDate) ? kendo.toString(kendo.parseDate(startDate), 'MM/dd/yyyy') : '' #" }
    gridColumns.push { field: 'endDate', title: 'Date Ends', hidden: true, template: "#= (data.endDate) ? kendo.toString(kendo.parseDate(endDate), 'MM/dd/yyyy') : '' #" }
    gridColumns.push { field: 'huntSpecialMessage', title: 'Special Msg', hidden: true }
    gridColumns.push { field: 'description', title: 'Description', hidden: true }
    gridColumns.push { command: { text: "Details", click: $scope.editRow }, width: "90px" }

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
      return window.location = "#!/huntcatalog/#{$scope.huntCatalog._id}?ref=#{$scope.parentClientId}" if $scope.parentClientId
      return window.location = "#!/huntcatalog/#{$scope.huntCatalog._id}"
    )

  $scope.editRow = ($event) ->
    $event.preventDefault()
    $scope.huntCatalog = this.dataItem($($event.currentTarget).closest("tr"));
    return window.location = "#!/huntcatalog/#{$scope.huntCatalog._id}?ref=#{$scope.parentClientId}" if $scope.parentClientId
    return window.location = "#!/huntcatalog/#{$scope.huntCatalog._id}"

  $scope.loadGridView = (customView) ->
    return window.location.reload() unless customView
    options = JSON.parse(customView.options)
    options.toolbar = $scope.toolbar
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    grid.dataSource.filter({}) #clear previous filters
    grid.setOptions(options) #apply new filters
    #grid.refresh();


  $scope.init.call(@)
])
