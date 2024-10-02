APP = window.APP
APP.Controllers.controller('AdminReportsCharts', ['$scope', '$rootScope', '$location', '$modal', 'Storage', 'Report', 'View', 'Purchase', ($scope, $rootScope, $location, $modal, Storage, Report, View, Purchase) ->

  $scope.init = () ->
    $scope.GRID_SELECTOR_ID = '#salesChart'
    $scope.user = Storage.get 'user'
    $scope.loading = false;
    $scope.items = []
    $scope.item = null
    $scope.reportType = "individual"
    $scope.reportTypes = [
      { name: "Sum Volumes", value: "sum" }
      { name: "New Sales", value: "individual" }
    ]
    $scope.x_axises = [
      { name: "Day", value: "days" }
      { name: "Week", value: "weeks" }
      { name: "Month", value: "months" }
      { name: "Year", value: "years" }
    ]
    $scope.chartTypes = [
      { name: "Area", value: "area" }
      #{ name: "bar", value: "bar" }
      #{ name: "bubble", value: "bubble" }
      #{ name: "bullet", value: "bullet" }
      #{ name: "candlestick", value: "candlestick" }
      { name: "Column", value: "column" }
      { name: "Donut", value: "donut" }
      { name: "Funnel", value: "funnel" }
      { name: "Line", value: "line" }
      #{ name: "ohlc", value: "ohlc" }
      { name: "Pie", value: "pie" }
      #{ name: "polarArea", value: "polarArea" }
      #{ name: "polarLine", value: "polarLine" }
      #{ name: "polarScatter", value: "polarScatter" }
      #{ name: "radarArea", value: "radarArea" }
      #{ name: "radarColumn", value: "radarColumn" }
      #{ name: "radarLine", value: "radarLine" }
      #{ name: "rangeArea", value: "rangeArea" }
      #{ name: "rangeBar", value: "rangeBar" }
      #{ name: "rangeColumn", value: "rangeColumn" }
      #{ name: "scatter", value: "scatter" }
      #{ name: "scatterLine", value: "scatterLine" }
      { name: "Waterfall", value: "waterfall" }
      #{ name: "verticalArea", value: "verticalArea" }
      #{ name: "verticalBullet", value: "verticalBullet" }
      #{ name: "verticalLine", value: "verticalLine" }
      #{ name: "verticalRangeArea", value: "verticalRangeArea" }
    ]
    $scope.x_axis = "days"
    $scope.chartType = "line"
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

    $scope.startDate = new Date($scope.thisMonthStart)
    $scope.endDate = new Date($scope.thisMonthEnd)
    $scope.endDate = new Date() if $scope.endDate > new Date()

    if $scope.user?.isAdmin
      $scope.refreshChart()
    else
      alert "Unauthorized error"

  $scope.getNewDataSource = (items) ->

    dataSource = new kendo.data.DataSource({
        data: items
      })

  $scope.refreshChart = () ->
    $scope.loading = true;
    setItems = (results) ->
      items = []
      for item in results
        items.push item
      $scope.items = items
      $scope.loading = false;
      return items

    if $scope.user.isAdmin
      results = Report.adminStats {startDate: $scope.startDate, endDate: $scope.endDate}, (results) ->
        results = JSON.parse(JSON.stringify(results))
        items = setItems(results.daily)
        dataSource = $scope.getNewDataSource(items)
        $scope.setupChart(dataSource)
      , (err) ->
        console.log "loadAll errored:", err
        $scope.loading = false;


  $scope.setupChart = (dataSource) ->
    title = "New Sales"
    series_sums = [
      {
        field: "sum_total_sales",
        name: "Total Sales"
        aggregate: "max"
        visible: true
      }
      {
        field: "sum_total_rep_commissions",
        name: "Total Reps Commissions"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_overrides",
        name: "Total Overrides"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_rbo_margin",
        name: "Total RBO Margin"
        aggregate: "max"
        visible: true
      }
      {
        field: "sum_total_memberships",
        name: "Total Memberships"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_reps",
        name: "Total Reps"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_hunts",
        name: "Total Hunts"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_rifles",
        name: "Total Rifles"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_products",
        name: "Total Products"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_courses",
        name: "Total Courses"
        aggregate: "max"
        visible: false
      }
      {
        field: "sum_total_advertising",
        name: "Total Advertising"
        aggregate: "max"
        visible: false
      }

    ]
    series_individual = [
      {
        field: "sales",
        name: "Sales"
        aggregate: "max"
        visible: false
      }
      {
        field: "rep_commissions",
        name: "Rep Commissions"
        aggregate: "max"
        visible: false
      }
      {
        field: "overrides",
        name: "Overrides"
        aggregate: "max"
        visible: false
      }
      {
        field: "rbo_margin",
        name: "RBO Margin"
        aggregate: "max"
        visible: false
      }
      {
        field: "memberships",
        name: "Memberships"
        aggregate: "max"
        visible: true
      }
      {
        field: "reps",
        name: "Rep Subscriptions"
        aggregate: "max"
        visible: true
      }
      {
        field: "hunts",
        name: "Hunts"
        aggregate: "max"
        visible: false
      }
      {
        field: "rifles",
        name: "Rifles"
        aggregate: "max"
        visible: false
      }
      {
        field: "products",
        name: "Products"
        aggregate: "max"
        visible: false
      }
      {
        field: "courses",
        name: "Courses"
        aggregate: "max"
        visible: false
      }
      {
        field: "advertising",
        name: "Advertising"
        aggregate: "max"
        visible: false
      }
      {
        field: "number_new_memberships",
        name: "# New Memberships"
        aggregate: "max"
        visible: false
      }
      {
        field: "number_new_reps",
        name: "# New Reps"
        aggregate: "max"
        visible: false
      }

    ]
    if $scope.reportType is "sum"
      series = series_sums
    else if $scope.reportType is "individual"
      series = series_individual
    else
      series = series_individual
    angular.element($scope.GRID_SELECTOR_ID).kendoChart
      dataSource: dataSource
      title: title
      legend: {
        position: "bottom"
      }
      seriesDefaults: {
        type: $scope.chartType
        style: "smooth"
      },
      series: series
      valueAxis: {
        labels: {
          format: "{0}$"
          template: "#= kendo.format('{0:C}',value) #"
        }
      },
      categoryAxis: {
        field: "key"
        type: "date"
        baseUnit: $scope.x_axis
        min: $scope.startDate
        max: $scope.endDate
        roundToBaseUnit: true
      }
      tooltip: {
        visible: true,
        format: "{0}$",
        template: "#= series.name #: #= kendo.format('{0:C}',value) #"
      }

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

    $scope.startDate = new Date(startDate)
    $scope.endDate = new Date(endDate)

    $scope.endDate = new Date() if $scope.endDate > new Date()


  $scope.submit = ($event) ->
    $event.preventDefault() if $event
    $scope.refreshChart()

  $scope.init.call(@)
])
