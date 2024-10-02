APP = window.APP
APP.Controllers.controller('ReminderSend', ['$scope', '$rootScope', '$location', '$routeParams', 'Storage', 'Reminder', 'DrawResult', 'User', ($scope, $rootScope, $location, $routeParams, Storage, Reminder, DrawResult, User) ->

  $scope.init = () ->
    $scope.loading = false;
    $scope.user = Storage.get 'user'
    $scope.reminder = null
    $scope.drawresults = []
    $scope.total = ""
    $scope.counter = 0
    $scope.getReminderAndDrawresults($routeParams.id)


  $scope.getReminderAndDrawresults = (reminderId) ->
    Reminder.byId {_id: reminderId}, (rsp) ->
      $scope.reminder = rsp.reminder
      $scope.loadAllDrawResults($scope.reminder)
    , (err) ->
      console.log "getReminder errored:", err


  $scope.loadAllDrawResults = (reminder) ->
    return unless reminder.isDrawResultSuccess or reminder.isDrawResultUnsuccess
    if reminder.isDrawResultSuccess and reminder.isDrawResultUnsuccess
      statusType = "all"
    else if reminder.isDrawResultSuccess
      statusType = "successful"
    else if reminder.isDrawResultUnsuccess
      statusType = "unsuccessful"
    else
      return

    $scope.loading = true;
    DrawResult.report {state: reminder.state, type: statusType}, (rsp) ->
      $scope.drawresults = []
      $scope.total = rsp.length
      for drawresult in rsp
        $scope.counter = $scope.counter++
        $scope.drawresults.push drawresult
        #Get User
#        User.get {_id: drawresult.userId}, (rsp) ->
#          drawresult._extend(rsp, "name", "email")
#          $scope.drawresults.push drawresult
#        ,
#          (err) ->
#            console.log "Failed to get user for draw results. Error: ", err
#            console.log "Drawresult", drawresult
      $scope.loading = false;
      $scope.initGrid($scope.drawresults)
      $scope.redraw()
    ,
      (err) ->
        $scope.loading = false;
        console.log "Failed to get list of draw results. Error: ", err

  $scope.initGrid = (drawResults) ->
    dataSource = new kendo.data.DataSource({
      data: drawResults
      pageSize: 50
      sort: {
        field: "userName",
        dir: "asc"
      }
      #filter: { field: "type", operator: "eq", value: "Request Hunt Info" }
    })

    hidden = true
    hidden = false if $scope.reminder.isDrawResultSuccess
    gridColumns = [
      { field: 'userName', title: 'User'}
      { field: 'userId', title: 'User Id', hidden: true}
      { field: 'name', title: 'Name'}
      { field: 'unit', title: 'Unit', hidden: hidden}
      { field: 'status', title: 'Status'}
      { field: 'notes', title: 'Notes', hidden: true}
      { field: 'year', title: 'Year', hidden: true}
      { field: 'email', title: 'Email'}
      { field: 'phone_day', title: 'Phone'}
    ]
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: true, type:"datetime", template: "#= (data.createdAt) ? kendo.toString(kendo.parseDate(createdAt), 'MM/dd/yyyy') : '' #" }

    angular.element('#grid').kendoGrid
      dataSource: dataSource
      toolbar: ["excel"],
      excel: {
        fileName: "DrawResults.xlsx",
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


    angular.element('#grid').kendoTooltip
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

  $scope.init.call(@)
])
