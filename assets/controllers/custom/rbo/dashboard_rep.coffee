APP = window.APP
APP.Controllers.controller('RBO_REP_COMMISSIONS', ['$scope', '$rootScope', '$routeParams','$location', '$modal', 'Storage', 'Report', 'View', ($scope, $rootScope, $routeParams, $location, $modal, Storage, Report, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#repCommissionsGrid'
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
      results = Report.repCommissions {startDate: $scope.startDate, endDate: $scope.endDate, userId: $scope.user._id}, (results) ->
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
      item.total_commissions = 0
      item.total_commissions += item.comm_r0 if item.comm_r0
      item.total_commissions += item.comm_r1 if item.comm_r1
      item.total_commissions += item.comm_r2 if item.comm_r2
      item.total_commissions += item.comm_r3 if item.comm_r3
      item.total_commissions += item.comm_r4 if item.comm_r4
      item.total_commissions += item.comm_r5 if item.comm_r5
      item.total_commissions += item.comm_r6 if item.comm_r6
      item.total_commissions += item.comm_r7 if item.comm_r7
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
            amount: { type: "number" }
            amountPaid: { type: "number" }
            basePrice: { type: "number" }
            createdAt: { type: "date" }
            comm_r0: { type: "number" }
            comm_r1: { type: "number" }
            comm_r2: { type: "number" }
            comm_r3: { type: "number" }
            comm_r4: { type: "number" }
            comm_r5: { type: "number" }
            comm_r6: { type: "number" }
            comm_r7: { type: "number" }
            total_commissions: { type: "number" }
            TOTAL_PRICE: { type: "number" }
            commissionsPaid: { type: "date" }
            #percentPaid: { type: "number" }
            user_leveldown: { type: "number" }
          }
        }
      }
      aggregate: [
        { field: "basePrice", aggregate: "sum" },
        { field: "amountPaid", aggregate: "sum" }
        { field: "comm_r0", aggregate: "sum" }
        { field: "comm_r1", aggregate: "sum" }
        { field: "comm_r2", aggregate: "sum" }
        { field: "comm_r3", aggregate: "sum" }
        { field: "comm_r4", aggregate: "sum" }
        { field: "comm_r5", aggregate: "sum" }
        { field: "comm_r6", aggregate: "sum" }
        { field: "comm_r7", aggregate: "sum" }
        { field: "total_commissions", aggregate: "sum" }
        { field: "TOTAL_PRICE", aggregate: "sum" },

      ]
    })
    return dataSource

  $scope.setupGrid = (dataSource) ->
    TEMPLATE_UserNameLink = '# if(typeof user_name != "undefined" && user_name) { # <a href="\\#!/admin/masquerade/#:userId#">#:user_name#</a> # } else if (typeof user_first_name != "undefined" && typeof user_last_name != "undefined") { # <a href="\\#!/admin/masquerade/#:userId#">#:user_first_name# #:user_last_name#</a> # } else { # <a href="\\#!/admin/masquerade/#:userId#">#:userId#</a> # } # '
    TEMPLATE_ParentNameLink = '# if(typeof parent_name != "undefined" && parent_name && typeof userParentId != "undefined") { # <a href="\\#!/admin/masquerade/#:userParentId#">#:parent_name#</a> # } else if (typeof parent_first_name != "undefined" && typeof parent_last_name != "undefined" && typeof userParentId != "undefined") { # <a href="\\#!/admin/masquerade/#:userParentId#">#:parent_first_name# #:parent_last_name#</a> # } else if (typeof userParentId != "undefined") { # <a href="\\#!/admin/masquerade/#:userParentId#">#:userParentId#</a> # } #'
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
    gridColumns.push { field: 'huntCatalogCopy.title', title: 'Item', hidden: false,  aggregates: ["count"]}
    #gridColumns.push { field: 'user_leveldown', title: 'Level', hidden: true,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'user_name', title: 'Name', hidden: false, template: TEMPLATE_UserNameLink}
    #gridColumns.push { field: 'basePrice', title: 'Price', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('basePrice'), footerTemplate: TEMPLATE_Sum("Price") }
    gridColumns.push { field: 'TOTAL_PRICE', title: 'Total Price', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('TOTAL_PRICE'), footerTemplate: TEMPLATE_Sum("Total Price") }
    gridColumns.push { field: 'percentPaid', title: '% Paid', hidden: false, template: TEMPLATE_formatPercent('percentPaid') }
    gridColumns.push { field: 'total_commissions', title: 'Your Total Commissions', hidden: false, aggregates: ["sum"], template: TEMPLATE_formatMoney('total_commissions'), footerTemplate: TEMPLATE_Sum("Commissions Total") } if $scope.user.repType in ["Outdoor Software Solutions Partner","Associate Adventure Advisor","Adventure Advisor","Senior Adventure Advisor","Regional Adventure Advisor","Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r0', title: 'Commission AAA', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r0'), footerTemplate: TEMPLATE_Sum("Commission AAA") } if $scope.user.repType in ["Associate Adventure Advisor","Adventure Advisor","Senior Adventure Advisor","Regional Adventure Advisor","Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r1', title: 'Commission AA', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r1'), footerTemplate: TEMPLATE_Sum("Commission AA") } if $scope.user.repType in ["Adventure Advisor","Senior Adventure Advisor","Regional Adventure Advisor","Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r2', title: 'Commission SAA', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r2'), footerTemplate: TEMPLATE_Sum("Commission SAA") } if $scope.user.repType in ["Senior Adventure Advisor","Regional Adventure Advisor","Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r3', title: 'Commission RAA', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r3'), footerTemplate: TEMPLATE_Sum("Commission RAA") } if $scope.user.repType in ["Regional Adventure Advisor","Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r4', title: 'Commission AM', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r4'), footerTemplate: TEMPLATE_Sum("Commission AM") } if $scope.user.repType in ["Agency Manager","Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r5', title: 'Commission SAM', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r5'), footerTemplate: TEMPLATE_Sum("Commission SAM") } if $scope.user.repType in ["Senior Agency Manager","Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r6', title: 'Commission EAM', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r6'), footerTemplate: TEMPLATE_Sum("Commission EAM") } if $scope.user.repType in ["Executive Agency Manager","Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_r7', title: 'Commission SEAM', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_r7'), footerTemplate: TEMPLATE_Sum("Commission SEAM") } if $scope.user.repType in ["Senior Executive Agency Manager"]
    gridColumns.push { field: 'comm_rOSSP', title: 'Commission OSSP', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('comm_rOSSP'), footerTemplate: TEMPLATE_Sum("Commission OSSP") } if $scope.user.repType in ["Outdoor Software Solutions Partner"]
    #gridColumns.push { field: 'parent_name', title: 'Parent', hidden: true,  aggregates: ["count"], template: TEMPLATE_ParentNameLink, groupHeaderTemplate: TEMPLATE_Count}
    gridColumns.push { field: 'commissionsPaid', title: 'Commission Paid', hidden: false, template: TEMPLATE_formatDate('commissionsPaid')}
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: false, template: TEMPLATE_formatDate('createdAt')}
    #purchase hunt catalog snapshot fields
    gridColumns.push { field: 'huntCatalogCopy.huntNumber', title: 'Catalog Number', hidden: true,  aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    #purchase fields
    gridColumns.push { field: 'amountPaid', title: 'Paid', hidden: true, aggregates: ["sum"], template: TEMPLATE_formatMoney('amountPaid'), footerTemplate: TEMPLATE_Sum("Paid") }
    gridColumns.push { field: 'purchaseNotes', title: 'Purchase Notes', hidden: true}
    #gridColumns.push { field: 'paymentMethod', title: 'Payment Method', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count}
    #gridColumns.push { field: 'monthlyPayment', title: 'Monthly', hidden: true, template: TEMPLATE_formatMoney('monthlyPayment') }
    #gridColumns.push { field: 'monthlyPaymentNumberMonths', title: '# Months', hidden: true}
    #CC Fields
    gridColumns.push { field: 'cc_description', title: 'CC Desc', hidden: true}
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
    gridColumns.push { field: 'user_memberId', title: 'Member Id', hidden: true}
    gridColumns.push { field: 'user_memberType', title: 'Member Type', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_phone_cell', title: 'Phone Cell', hidden: true}
    gridColumns.push { field: 'user_physical_address', title: 'Physical Address', hidden: true}
    gridColumns.push { field: 'user_physical_city', title: 'Physical City', hidden: true}
    gridColumns.push { field: 'user_physical_country', title: 'Physical Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    gridColumns.push { field: 'user_physical_postal', title: 'Physical Postal', hidden: true}
    gridColumns.push { field: 'user_physical_state', title: 'Physical State', hidden: true, aggregates: ["count"], groupHeaderTemplate: TEMPLATE_Count }
    $scope.gridColumns = gridColumns

    if $scope.user.isAdmin
      $scope.toolbar = ["excel", "Save Current View"]
    else
      $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "commissions.xlsx",
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
    angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid").refresh()

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

  $scope.showGridColumns = (gridColumns) ->
    showColumns = []
    #Fill showColumns with override columns to show based on the custom view as desired
    #if $scope.view is "booking"

    if showColumns?.length
      for gridColumn in gridColumns
        if showColumns.indexOf(gridColumn.field) > -1
          gridColumn.hidden = false
        else
          gridColumn.hidden = true

    return gridColumns


  $scope.init.call(@)
])
