APP = window.APP
APP.Controllers.controller('Purchases', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'Purchase', 'View', ($scope, $rootScope, $location, $modal, Storage, Purchase, View) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#purchasesGrid'
    $scope.user = Storage.get 'user'
    $scope.loadingPurchases = false;
    $scope.adminShowAll = false;
    $scope.purchases = []
    $scope.purchase = null
    $scope.customView = null
    $scope.customViews = []
    $scope.toolbar = null
    $scope.loadAllPurchases()
    $scope.initGrid()
    $scope.loadSavedViews()

  $scope.loadAllPurchases = () ->
    $scope.loadingPurchases = true;
    setPurchases = (results) ->
      purchases = []
      for result in results
        result.userName = "" unless result.userName
        result.userName = "" if result.userName?.indexOf("undefined") > -1
        result.userName = result.user.name if !result.userName and result?.user?.name
        result.userName = result.user.first_name + " " + result.user.last_name if !result.userName and result?.user
        result.parentUserName = ""
        result.parentUserName = result.parent.first_name + " " + result.parent.last_name if result?.parent? and !result.parentUserName
        result.parentUserName = "" if result.parentUserName?.indexOf("undefined") > -1
        purchases.push result

      $scope.purchases = purchases
      $scope.loadingPurchases = false;
      $scope.setupGrid(JSON.parse(JSON.stringify($scope.purchases)))

    if $scope.user.isAdmin and $scope.adminShowAll
      results = Purchase.adminIndex (results) ->
        setPurchases(results)
      , (err) ->
        console.log "loadAllPurchases errored:", err
        $scope.loadingPurchases = false;
    else
      results = Purchase.byUserId {userId: $scope.user._id}, (results) ->
        setPurchases(results)
      , (err) ->
        console.log "loadAllPurchases errored:", err
        $scope.loadingPurchases = false;

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


  $scope.setupGrid = (purchases) ->
    dataSource = new kendo.data.DataSource({
      data: purchases
      pageSize: 50
      sort: {
        field: "createdAt",
        dir: "desc"
      }
      schema: {
        model: {
          fields: {
            userIsMember: { type: "boolean" }
            amount: { type: "number" }
            amountPaid: { type: "number" }
            minPaymentRequired: { type: "number" }
            basePrice: { type: "number" }
            monthlyPayment: { type: "number" }
            monthlyPaymentNumberMonths: { type: "number" }
            createdAt: { type: "date" }
          }
        }
      }
    })

    gridColumns = []
    if $scope.user.isAdmin
      gridColumns.push { field: 'userId', title: 'User Id', hidden: true }
      gridColumns.push { field: 'userName', title: 'User', template: '# if(userName && typeof userId != "undefined") { # <a href="\\#!/admin/masquerade/#:userId#">#:userName#</a> # } else if(userName && userName.indexOf("undefined") == -1) { # #:userName#  # } # ' }
      gridColumns.push { field: 'userIsMember', title: 'Member', hidden: true}
      gridColumns.push { field: 'userParentId', title: 'Parent Id', hidden: true}
      gridColumns.push { field: 'parentUserName', title: 'Parent', template: '# if(typeof userParentId != "undefined") { # <a href="\\#!/admin/masquerade/#:userParentId#">#:parentUserName#</a> # } else if(parentUserName.indexOf("undefined") == -1) { # #:parentUserName#  # } # ' }
      gridColumns.push { field: 'huntCatalogCopy.outfitter_name', title: 'Outfitter', hidden: true}


    gridColumns.push { field: 'huntCatalogCopy.huntNumber', title: 'Number'}
    gridColumns.push { field: 'huntCatalogCopy.title', title: 'Item'}
    gridColumns.push { field: 'amountPaid', title: 'Paid', template: "#= (data.amountPaid) ? kendo.toString(kendo.parseFloat(amountPaid), 'c') : '' #" }
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: false, template: "#= (data.createdAt) ? kendo.toString(kendo.parseDate(createdAt), 'MM/dd/yyyy') : '' #" }
    gridColumns.push { field: 'purchaseNotes', title: 'Purchase Notes', hidden: true }
    gridColumns.push { field: 'paymentMethod', title: 'Payment Method', hidden: true }
    gridColumns.push { field: 'basePrice', title: 'Price', template: "#= (data.basePrice) ? kendo.toString(kendo.parseFloat(basePrice), 'c') : '' #"  }
    gridColumns.push { field: 'monthlyPayment', title: 'Monthly', hidden: true, template: "#= (data.monthlyPayment) ? kendo.toString(kendo.parseFloat(monthlyPayment), 'c') : '' #"  }
    gridColumns.push { field: 'monthlyPaymentNumberMonths', title: '# Months', hidden: true}

    if $scope.user.isAdmin
      $scope.toolbar = ["excel", "Save Current View"]
    else
      $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
      excel: {
        fileName: "Purchases.xlsx",
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
    $scope.purchase = null
    $scope.purchase = this.dataItem(this.select());

  $scope.initGrid = () ->
    angular.element($scope.GRID_SELECTOR_ID).delegate(' table tr', 'dblclick', () ->
      console.log "Row double clicked."
      #window.location = "#!/purchase_receipt/#{$scope.purchase._id}" if $scope.purchase?._id
    )

  $scope.editRow = ($event) ->
    $event.preventDefault()
    purchase = angular.element($scope.GRID_SELECTOR_ID).data("kendoGrid").dataItem($($event.currentTarget).closest("tr"));
    console.log "Purchase Receipt selected"
    #window.location = "#!/purchase_receipt/#{purchase._id}"

  $scope.loadGridView = (customView) ->
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

  $scope.reloadAllPurchases = () ->
    $scope.customView = null
    $scope.loadAllPurchases()

  $scope.init.call(@)
])
