APP = window.APP
APP.Controllers.controller('RBO_REP_PURCHASES', ['$scope', '$rootScope', '$location', '$modal', '$routeParams','Storage', 'Report', 'View', ($scope, $rootScope, $location, $modal, $routeParams, Storage, Report, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#repPurchasesGrid'
    $scope.user = Storage.get 'user'
    $scope.loading = false;
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
    if $scope.user?.isRep
      $scope.refreshGrid()
    else
      alert "Unauthorized error"
      window.location = "#!/dashboard"

  $scope.submit = ($event) ->
    $event.preventDefault() if $event
    if $scope.user?.isRep
      $scope.refreshGrid()
    else
      alert "Unauthorized error"

  $scope.refreshGrid = () ->
    $scope.loading = true
    $scope.destroyGrid()
    $scope.initGrid()
    if $scope.user?.isRep
      results = Report.repPurchases {startDate: $scope.startDate, endDate: $scope.endDate, userId: $scope.user._id}, (results) ->
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
      #Options Sum:
      item.options_total = 0
      if item.options?.length
        hasOptionAddOns = true
        inc = 0
        for option in item.options
          item.options_total += option.price
          #option_desc = "#{option.title}: #{option.specific_type}"
          option_desc = "#{option.title}: $#{$scope.formatMoneyStr(option.price)} #{option.specific_type}"
          if inc is 0
            options_descriptions = "#{option_desc}"
          else
            options_descriptions = "#{options_descriptions}, \r\n\r\n #{option_desc}"
          inc++
      item.options_descriptions = options_descriptions if options_descriptions
      item.TOTAL_PRICE = item.basePrice
      item.TOTAL_PRICE += item.options_total if item.options_total
      item.TOTAL_PRICE += item.fee_processing if item.fee_processing
      item.TOTAL_PRICE += item.shipping if item.shipping
      item.TOTAL_PRICE += item.sales_tax if item.sales_tax
      item.TOTAL_PRICE += item.tags_licenses if item.tags_licenses
      item.percentPaid =  (item.amountPaid / item.TOTAL_PRICE).toFixed(2)
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
          fields: {
            TOTAL_PRICE: { type: "number" }
            clientOwes: { type: "number" }
            amount: { type: "number" }
            amountPaid: { type: "number" }
            percentPaid: { type: "number" }
            basePrice: { type: "number" }
            options_total: { type: "number" }
            tags_licenses: { type: "number" }
            fee_processing: { type: "number" }
            shipping: { type: "number" }
            sales_tax: { type: "number" }
            monthlyPayment: { type: "number" }
            monthlyPaymentNumberMonths: { type: "number" }
            createdAt: { type: "date" }
            start_hunt_date: { type: "date" }
          }
        }
      }
      aggregate: [
        { field: "basePrice", aggregate: "sum" },
        { field: "options_total", aggregate: "sum" },
        { field: "tags_licenses", aggregate: "sum" },
        { field: "fee_processing", aggregate: "sum" },
        { field: "shipping", aggregate: "sum" },
        { field: "sales_tax", aggregate: "sum" },
        { field: "amount", aggregate: "sum" }
        { field: "amountPaid", aggregate: "sum" }
        { field: "commission", aggregate: "sum" }
        { field: "clientOwes", aggregate: "sum" },
        { field: "TOTAL_PRICE", aggregate: "sum" },

      ]
    })
    return dataSource



  $scope.setupGrid = (dataSource) ->
    TEMPLATE_UserNameLink = '# if(typeof user_name != "undefined" && user_name) { # <a href="\\#!/admin/masquerade/#:userId#">#:user_name#</a> # } else if (typeof user_first_name != "undefined" && typeof user_last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:userId#">#:user_first_name# #:user_last_name#</a> # } else { # <a href="\\#!/admin/masquerade/#:userId#">#:userId#</a> # } # '
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
    #default view
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: false, template: TEMPLATE_formatDate('createdAt')}
    gridColumns.push { field: 'huntCatalogCopy.title', title: 'Item', hidden: false,  aggregates: ["count"]}
    gridColumns.push { field: 'invoiceNumber', title: 'Invoice #', hidden: false}
    gridColumns.push { field: 'user_name', title: 'Name', hidden: false, template: TEMPLATE_UserNameLink}
    gridColumns.push { field: 'TOTAL_PRICE', title: 'Total Price', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('TOTAL_PRICE'), footerTemplate: TEMPLATE_Sum("Total Price") }
    gridColumns.push { field: 'basePrice', title: 'Price', hidden: true, template: TEMPLATE_formatMoney('basePrice') }
    gridColumns.push { field: 'options_total', title: 'Options', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('options_total'), footerTemplate: TEMPLATE_Sum("Options") }
    gridColumns.push { field: 'tags_licenses', title: 'Tags & Lic', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('tags_licenses'), footerTemplate: TEMPLATE_Sum("Tags & Lic") }
    gridColumns.push { field: 'fee_processing', title: 'Processing Fee', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('fee_processing'), footerTemplate: TEMPLATE_Sum("Processing Fee") }
    gridColumns.push { field: 'shipping', title: 'Shipping', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('shipping'), footerTemplate: TEMPLATE_Sum("Shipping") }
    gridColumns.push { field: 'sales_tax', title: 'Sales Tax', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('sales_tax'), footerTemplate: TEMPLATE_Sum("Sales Tax") }
    #gridColumns.push { field: 'amount', title: 'Initial Deposit', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('amount'), footerTemplate: TEMPLATE_Sum("Initial Deposit") }
    #gridColumns.push { field: 'amountPaid', title: 'Paid', hidden: false, template: TEMPLATE_formatMoney('amountPaid') }
    #gridColumns.push { field: 'percentPaid', title: '% Paid', hidden: true, template: TEMPLATE_formatPercent('percentPaid') }
    #gridColumns.push { field: 'clientOwes', title: 'Client Owes', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('clientOwes'), footerTemplate: TEMPLATE_Sum("Client Owes") }
    #purchase hunt catalog snapshot fields
    gridColumns.push { field: 'huntCatalogCopy.huntNumber', title: 'Catalog Number', hidden: true,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'huntCatalogCopy.type', title: 'Hunt Catalog Type', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    #purchase fields
    gridColumns.push { field: 'purchaseNotes', title: 'Purchase Notes', hidden: true}
    gridColumns.push { field: 'start_hunt_date', title: 'Hunt Start Date', hidden: true, template: TEMPLATE_formatDate('start_hunt_date')}
    #gridColumns.push { field: 'paymentUsed', title: 'Payment Method', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    #gridColumns.push { field: 'monthlyPayment', title: 'Monthly', hidden: true, template: TEMPLATE_formatMoney('monthlyPayment') }
    #gridColumns.push { field: 'monthlyPaymentNumberMonths', title: '# Months', hidden: true}
    #CC Fields
    #user fields
    gridColumns.push { field: 'user_clientId', title: 'Client Id', hidden: true,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'user_email', title: 'Email', hidden: true}
    gridColumns.push { field: 'user_first_name', title: 'First Name', hidden: true}
    gridColumns.push { field: 'user_last_name', title: 'Last Name', hidden: true}
    gridColumns.push { field: 'user_mail_address', title: 'Mail Address', hidden: true}
    gridColumns.push { field: 'user_mail_city', title: 'Mail City', hidden: true}
    gridColumns.push { field: 'user_mail_country', title: 'Mail Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_mail_postal', title: 'Mail Postal', hidden: true}
    gridColumns.push { field: 'user_mail_state', title: 'Mail State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_phone_cell', title: 'Phone Cell', hidden: true}
    gridColumns.push { field: 'user_physical_address', title: 'Physical Address', hidden: true}
    gridColumns.push { field: 'user_physical_city', title: 'Physical City', hidden: true}
    gridColumns.push { field: 'user_physical_country', title: 'Physical Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_physical_postal', title: 'Physical Postal', hidden: true}
    gridColumns.push { field: 'user_physical_state', title: 'Physical State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }

    gridColumns = $scope.showGridColumns(gridColumns)
    $scope.gridColumns = gridColumns

    if $scope.user.isAdmin
      $scope.toolbar = ["excel", "Save Current View"]
    else
      $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "purchases.xlsx",
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
