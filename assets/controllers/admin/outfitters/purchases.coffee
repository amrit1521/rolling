APP = window.APP
APP.Controllers.controller('AdminOutfittersPurchases', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'Report', 'View', 'Purchase', ($scope, $rootScope, $location, $modal, Storage, Report, View, Purchase) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#outfittersPurchasesGrid'
    $scope.user = Storage.get 'user'
    $scope.loading = false;
    $scope.items = []
    $scope.item = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.dateFilterType = null
    if $scope.user?.isAdmin || $scope.user?.isOutfitter || $scope.user?.isVendor
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

  $scope.loadItems = () ->
    $scope.loading = true;
    setItems = (results) ->
      items = []
      for item in results
        #Apply any additional calculated fields or logic here
        item.huntCatalogCopy_updatedAt = item.huntCatalogCopy.updatedAt if item.huntCatalogCopy.updatedAt
        item.huntCatalogCopy_createdAt = item.huntCatalogCopy.createdAt if item.huntCatalogCopy.createdAt

        #Options Sum:
        item.options_rbo_commissions_total = 0 unless item.options_rbo_commissions_total? > 0
        item.options_total = 0
        if item.options?.length
          hasOptionAddOns = true
          inc = 0
          for option in item.options
            item.options_total += option.price
            item.options_rbo_commissions_total += option.commission if option.commission
            #option_desc = "#{option.title}: #{option.specific_type}"
            option_desc = "#{option.title}: $#{$scope.formatMoneyStr(option.price)} #{option.specific_type}"
            if inc is 0
              options_descriptions = "#{option_desc}"
            else
              options_descriptions = "#{options_descriptions}, \r\n\r\n #{option_desc}"
            inc++
        item.options_totalToOutfitter = item.options_total - item.options_rbo_commissions_total
        item.options_descriptions = options_descriptions if options_descriptions

        item.rbo_reps_commission = item.rbo_reps_commission + item.options_rbo_commissions_total


        item.commission_to_outfitter = 0
        item.commission_to_outfitter += item.rbo_commission_rep0 if item.rbo_commission_rep0
        item.commission_to_outfitter += item.rbo_commission_rep1 if item.rbo_commission_rep1
        item.commission_to_outfitter += item.rbo_commission_rep2 if item.rbo_commission_rep2
        item.commission_to_outfitter += item.rbo_commission_rep3 if item.rbo_commission_rep3
        item.commission_to_outfitter += item.rbo_commission_rep4 if item.rbo_commission_rep4
        item.commission_to_outfitter += item.rbo_commission_rep5 if item.rbo_commission_rep5
        item.commission_to_outfitter += item.rbo_commission_rep6 if item.rbo_commission_rep6
        item.commission_to_outfitter += item.rbo_commission_rep7 if item.rbo_commission_rep7
        item.commission_to_outfitter += item.rbo_commission_repOSSP if item.rbo_commission_repOSSP
        item.commission_to_outfitter += item.rbo_commission_rbo4 if item.rbo_commission_rbo4

        item.TOTAL_PRICE = item.basePrice
        item.TOTAL_PRICE += item.options_total if item.options_total
        item.TOTAL_PRICE += item.fee_processing if item.fee_processing
        item.TOTAL_PRICE += item.shipping if item.shipping
        item.TOTAL_PRICE += item.sales_tax if item.sales_tax
        item.TOTAL_PRICE += item.tags_licenses if item.tags_licenses
        item.clientOwes = item.TOTAL_PRICE - item.amountPaid
        item.percentPaid =  (item.amountPaid / item.TOTAL_PRICE).toFixed(2)

        items.push item
      $scope.items = results
      $scope.loading = false;
      $scope.setupGrid(JSON.parse(JSON.stringify(results)))

    if $scope.user?.isAdmin
      results = Report.adminTenantPurchases {userId: $scope.user._id}, (results) ->
        setItems(results)
      , (err) ->
        console.log "loadAll errored:", err
        $scope.loading = false;
    else if $scope.user?.isOutfitter || $scope.user?.isVendor
      results = Report.adminOutfittersPurchases {userId: $scope.user._id}, (results) ->
        setItems(results)
      , (err) ->
        console.log "loadAll errored:", err
        $scope.loading = false;
    else
      alert "Unauthorized error"

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
      if $scope.user?.isAdmin
        window.location = "#!/purchase_receipt/#{$scope.item._id}" if $scope.item?._id
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
    if $scope.user?.isAdmin
      window.location = "#!/purchase_receipt/#{$scope.item._id}" if $scope.item?._id


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
            amount: { type: "number" } #Amount Paid on initial deposit
            amountTotal: { type: "number" } #Total Amount Paid on initial deposit
            amountPaid: { type: "number" }  #Total payments summed up to date
            percentPaid: { type: "number" }
            basePrice: { type: "number" }
            options_total: { type: "number" }
            tags_licenses: { type: "number" }
            fee_processing: { type: "number" }
            shipping: { type: "number" }
            sales_tax: { type: "number" }
            TOTAL_PRICE: { type: "number" }
            commission_to_outfitter: { type: "number" }
            commission: { type: "number" }
            clientOwes: { type: "number" }
            commissionPercent: { type: "number" }
            createdAt: { type: "date" }
          }
        }
      }
      aggregate: [
        { field: "amount", aggregate: "sum" },
        { field: "amountTotal", aggregate: "sum" },
        { field: "amountPaid", aggregate: "sum" },
        { field: "basePrice", aggregate: "sum" },
        { field: "options_total", aggregate: "sum" },
        { field: "tags_licenses", aggregate: "sum" },
        { field: "fee_processing", aggregate: "sum" },
        { field: "shipping", aggregate: "sum" },
        { field: "sales_tax", aggregate: "sum" },
        { field: "TOTAL_PRICE", aggregate: "sum" },
        { field: "commission_to_outfitter", aggregate: "sum" },
        { field: "commission", aggregate: "sum" },
        { field: "clientOwes", aggregate: "sum" }
      ]
    })
    return dataSource


  $scope.setGridItems = (gridItems) ->
    #console.log "gridItems:", gridItems
    dataSource = $scope.getNewDataSource(gridItems)
    grid = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid")
    grid.setDataSource(dataSource)


  $scope.getGridColumns = () ->
    TEMPLATE_EDIT = '# if(typeof _id != "undefined") { # <a href="\\#!/admin/purchase_edit/#:_id#">EDIT</a> # } # '
    TEMPLATE_HCHuntNumberLink = '# if(typeof huntCatalogCopy.huntNumber != "undefined" && huntCatalogCopy.huntNumber) { # <a href="\\#!/admin/huntcatalog/#:huntCatalogCopy._id#">#:huntCatalogCopy.huntNumber#</a> # } else { # <a href="\\#!/admin/huntcatalog/#:huntCatalogCopy._id#">#:huntCatalogCopy.huntNumber#</a> # } # '
    TEMPLATE_HCTitleLink = '# if(typeof huntCatalogCopy.title != "undefined" && huntCatalogCopy.title) { # <a href="\\#!/admin/huntcatalog/#:huntCatalogCopy._id#">#:huntCatalogCopy.title#</a> # } else { # <a href="\\#!/admin/huntcatalog/#:huntCatalogCopy._id#">#:huntCatalogCopy.huntNumber#</a> # } # '
    TEMPLATE_Count = "#= data.field#: #=data.value# (count: #= count#)"
    TEMPLATE_Sum = (title) ->
      #return "#{title} Total: #=sum#"
      return "Total: #=kendo.toString(kendo.parseFloat(sum), 'c')#"
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"
    TEMPLATE_formatMoney = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseFloat(#{fieldKey}), 'c') : kendo.toString(kendo.parseFloat(0), 'c') #"
    TEMPLATE_formatPercent = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseFloat(#{fieldKey}), 'p') : kendo.toString(kendo.parseFloat(0), 'c') #"

    gridColumns = []

    gridColumns.push { selectable: true, width: "50px"}
    #default view
    gridColumns.push { field: 'invoiceNumber', title: 'Invoice #', hidden: false}
    gridColumns.push { field: 'huntCatalogCopy.huntNumber', title: 'Item Number', hidden: true,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'huntCatalogCopy.title', title: 'Item', hidden: false,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'TOTAL_PRICE', title: 'Total Price', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('TOTAL_PRICE'), footerTemplate: TEMPLATE_Sum("Total Price") }
    gridColumns.push { field: 'basePrice', title: 'Price', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('basePrice'), footerTemplate: TEMPLATE_Sum("Price") }
    gridColumns.push { field: 'options_total', title: 'Options', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('options_total'), footerTemplate: TEMPLATE_Sum("Options") }
    gridColumns.push { field: 'tags_licenses', title: 'Tags & Lic', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('tags_licenses'), footerTemplate: TEMPLATE_Sum("Tags & Lic") }
    gridColumns.push { field: 'fee_processing', title: 'Processing Fee', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('fee_processing'), footerTemplate: TEMPLATE_Sum("Processing Fee") }
    gridColumns.push { field: 'shipping', title: 'Shipping', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('shipping'), footerTemplate: TEMPLATE_Sum("Shipping") }
    gridColumns.push { field: 'sales_tax', title: 'Sales Tax', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('sales_tax'), footerTemplate: TEMPLATE_Sum("Sales Tax") }
    gridColumns.push { field: 'amount', title: 'Initial Deposit', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('amount'), footerTemplate: TEMPLATE_Sum("Initial Deposit") }
    gridColumns.push { field: 'amountPaid', title: 'Paid', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('amountPaid') , footerTemplate: TEMPLATE_Sum("Paid") }
    gridColumns.push { field: 'clientOwes', title: 'Client Owes', hidden: false, template: TEMPLATE_formatMoney('clientOwes') , footerTemplate: TEMPLATE_Sum("Owed") }
    gridColumns.push { field: 'user_name', title: 'Name', hidden: false}
    if $scope.isRBO()
      gridColumns.push { field: 'commission', title: 'Commission to RBO', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('commission'), footerTemplate: TEMPLATE_Sum("Commission")}
    #else
    #  gridColumns.push { field: 'commission_to_outfitter', title: 'Commission', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('commission_to_outfitter'), footerTemplate: TEMPLATE_Sum("commission_to_outfitter")}
    #purchase hunt catalog snapshot fields
    gridColumns.push { field: 'huntCatalogCopy.outfitter_name', title: 'Outfitter', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    if $scope.isRBO()
      gridColumns.push { field: 'huntCatalogCopy.state', title: 'State goods delivered', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}

    #purchase fields
    gridColumns.push { field: 'percentPaid', title: '% Paid', hidden: true, template: TEMPLATE_formatPercent('percentPaid') }
    gridColumns.push { field: 'purchaseNotes', title: 'Purchase Notes', hidden: false}
    #gridColumns.push { field: 'receipt', title: 'Receipt', hidden: true, template: TEMPLATE_ReceiptLink}
    gridColumns.push { field: 'paymentUsed', title: 'Payment Method', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}

    #user fields
    gridColumns.push { field: 'user_clientId', title: 'Client Id', hidden: true,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'user_email', title: 'Email', hidden: true}
    gridColumns.push { field: 'user_first_name', title: 'First Name', hidden: true}
    gridColumns.push { field: 'user_last_name', title: 'Last Name', hidden: true}
    gridColumns.push { field: 'user_shipping_address', title: 'Shipping Address', hidden: true}
    gridColumns.push { field: 'user_shipping_city', title: 'Shipping City', hidden: true}
    gridColumns.push { field: 'user_shipping_country', title: 'Shipping Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_shipping_postal', title: 'Shipping Postal', hidden: true}
    gridColumns.push { field: 'user_shipping_state', title: 'Shipping State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_mail_address', title: 'Mail Address', hidden: true}
    gridColumns.push { field: 'user_mail_city', title: 'Mail City', hidden: true}
    gridColumns.push { field: 'user_mail_country', title: 'Mail Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_mail_postal', title: 'Mail Postal', hidden: true}
    gridColumns.push { field: 'user_mail_state', title: 'Mail State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_phone_cell', title: 'Phone Cell', hidden: true}
    gridColumns.push { field: 'user_phone_day', title: 'Phone Day', hidden: true}
    gridColumns.push { field: 'user_phone_home', title: 'Phone Home', hidden: true}
    gridColumns.push { field: 'user_physical_address', title: 'Physical Address', hidden: true}
    gridColumns.push { field: 'user_physical_city', title: 'Physical City', hidden: true}
    gridColumns.push { field: 'user_physical_country', title: 'Physical Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_physical_postal', title: 'Physical Postal', hidden: true}
    gridColumns.push { field: 'user_physical_state', title: 'Physical State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: false, template: TEMPLATE_formatDate('createdAt')}

    gridColumns.push { field: 'edit', title: 'EDIT', hidden: false, template: TEMPLATE_EDIT}

    $scope.gridColumns = gridColumns
    return gridColumns

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

  $scope.init.call(@)
])
