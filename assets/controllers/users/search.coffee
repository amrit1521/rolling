APP = window.APP
APP.Controllers.controller('UsersSearch', ['$scope', '$sce', '$rootScope', '$location', '$log', '$modal', '$timeout', 'HuntChoice', 'Point', 'Search', 'State', 'Storage', 'Stream', 'User', 'TenantEmail', '$routeParams', ($scope, $sce, $rootScope, $location, $log, $modal, $timeout, HuntChoice, Point, Search, State, Storage, Stream, User, TenantEmail, $routeParams) ->

  $scope.init = () ->
    $scope.outfitters = $routeParams.outfitter is "1"
    $scope.loadingUsers = false;
    $scope.user = Storage.get 'user'
    $scope.selectedUser = null
    $scope.myUsersOnly = false
    $scope.isHuntinFool = window?.tenant?._id?.toString() is "52c5fa9d1a80b40fd43f2fdd"
    $scope.isRBO = window?.tenant?._id?.toString() is "5684a2fc68e9aa863e7bf182" or window?.tenant?._id?.toString() is "5bd75eec2ee0370c43bc3ec7"
    $scope.$on "$destroy", ->
      Stream.disconnect()

    email = TenantEmail.adminByType {type: 'Welcome'}, ->
        if email?._id
          $scope.email = email
        else
          console.log "Failed to retrieve welcome email for this tenant."
      , (err) ->
        console.log "Failed to retrieve welcome email for this tenant.", err

    $scope.search = $rootScope.search

    console.log '$scope.search:', $scope.search
    $scope._search($scope.search) if $scope.search.text.length

    Stream.on 'connected', ->
      console.log "Stream connected"
      $scope.connected = true
      $scope.redraw()

    Stream.on 'disconnected', ->
      console.log "Stream disconnected"
      $scope.connected = false
      $scope.pingRunning = false
      $scope.redraw()

    Stream.connect()

  $scope.ping = ->
    console.log "ping called - status running:", !!$scope.pingRunning
    return if $scope.pingRunning
    $scope.pingRunning = true
    console.log "ping"
    Stream.ping (err, result) ->
      return alert(err) if err

      console.log "result:", result
      return alert('Bad result:' + result) unless result is 'pong'

      setTimeout ->
        $scope.pingRunning = false
        $scope.ping()
      , 1000

  $scope.toggleFilterMyUsersOnly = () ->
    if $scope.myUsersOnly
      $scope.myUsersOnly = false
    else
      $scope.myUsersOnly = true
    $scope.showAllUsers()


  $scope.showAllUsers = () ->
    $scope.loadingUsers = true;
    search = {
      type: "name",
      text: ""
    }
    $scope._search(search, true)

  $scope._search = (search, showAll) ->
    if !showAll
      return unless search?.text?.length > 2

    search.type = 'name'

    currentUser = Storage.get 'user'
    search.parentId = null
    if currentUser.tenantId
      search.parentId = currentUser._id unless currentUser.isAdmin
    search.parentId = currentUser._id if $scope.myUsersOnly
    search.outfitters = $scope.outfitters

    results = Search.find search, ->
      for result in results
        result.name = result.first_name + ' ' + result.last_name if not result.name and result.first_name and result.last_name
        if result?.devices?.length
          result.appUser = true
        else
          result.appUser = false
        result.contractEnd = new Date(result.contractEnd) if result.contractEnd
        result.createdAt = new Date(parseInt(result._id.substring(0, 8), 16) * 1000)
      $scope.results = results
      $scope.setupGrid(results)
      $scope.loadingUsers = false;
    , ->
      console.log "search errored"
      $scope.loadingUsers = false;

  $scope.sendMessage = ($event, user) ->
    alert "The message could not send. Please contact info@rollingbonesoutfitters.com." unless user
    return unless user
    message = prompt "Please enter the message you wish to send"
    return unless message

    User.message {userId: user._id, message}

  $scope.sendEmail = ($event, user) ->
    alert "The update email could not send. Please contact info@rollingbonesoutfitters.com." unless user
    return unless user
    return alert("Could not retrieve valid welcome email to send.") unless $scope.email?._id
    result = confirm "Confirm sending email to #{user.email}"
    if result
      params = {
        userId: user._id
        tenantEmailId: $scope.email._id
        sendAsTest: true
        task: "welcome_email.send"
      }
      TenantEmail.adminSendTest params, (rsp) ->
        alert "Welcome email resent"
      ,
        (err) ->
          if err.error
            msg = "Email failed to send with error " + err.error
          else
            msg = "Email failed to send with error " + err
          alert msg


  $scope.filterResults = (value) ->
    console.log "filterResults:", value

  $scope.runSearch = _.throttle($scope._search, 750)

  $scope.toggleAdmin = (user) ->
# pause for a tick to allow for the model to be updated
    setTimeout ->
      console.log "toggleAdmin user:", user
      User.setAdmin {userId: user._id, isAdmin: user.isAdmin}

  $scope.setupGrid = (users) ->
    TEMPLATE_formatDate = (fieldKey) ->
      return "#= (data.#{fieldKey}) ? kendo.toString(kendo.parseDate(#{fieldKey}), 'MM/dd/yyyy') : '' #"

    dataSource = new kendo.data.DataSource({
      data: users
      pageSize: 50
      sort: {
        field: "name",
        dir: "asc"
      }
      schema: {
        model: {
          fields: {
            isAppUser: { type: "boolean" }
            isMember: { type: "boolean" }
            isRep: { type: "boolean" }
            created: { type: "date" }
            createdAt: { type: "date" }
          }
        }
      }
    })

    gridColumns = []
    if $scope.outfitters
      gridColumns.push { field: 'name', title: 'Name', template: '# if(typeof name != "undefined") { # <a href="\\#!/admin/outfitter/#:_id#">#:name#</a> # } else { # #:name#  # } # ' }
    else
      gridColumns.push { field: 'name', title: 'Name', template: '# if(typeof name != "undefined") { # <a href="\\#!/admin/masquerade/#:_id#">#:name#</a> # } else { # #:name#  # } # ' }
    gridColumns.push { field: 'clientId', title: 'Client Id'} unless $scope.outfitters
    gridColumns.push { field: 'memberId', title: 'Member Id', hidden: true} unless $scope.outfitters
    gridColumns.push { field: 'memberType', title: 'Member Type', hidden: true} unless $scope.outfitters
    gridColumns.push { field: 'isMember', title: 'Is Member', hidden: false} unless $scope.outfitters
    if $scope.outfitters
      gridColumns.push { field: 'status', title: 'Status'}
      gridColumns.push { field: 'commission', title: 'Commission', hidden: false}
      gridColumns.push { field: 'contractEnd', title: 'Contract End', hidden: true}
      gridColumns.push { field: 'phone_cell', title: 'Phone Cell'}
      gridColumns.push { field: 'phone_day', title: 'Phone Day'}
      gridColumns.push { field: 'internalNotes', title: 'Admin Notes', hidden: false}
    else
      gridColumns.push { field: 'phone_cell', title: 'Phone Cell', hidden: true}
      gridColumns.push { field: 'phone_day', title: 'Phone Day', hidden: true}
    gridColumns.push { field: 'email', title: 'Email'}
    if $scope.user.isAdmin and !$scope.outfitters
      if $scope.isRBO
        gridColumns.push { field: 'isRep', title: 'Is Rep', hidden: false}
        gridColumns.push { field: 'repType', title: 'Rep Type', hidden: false}
      gridColumns.push { field: 'email', title: 'Send Update', filterable: false, template: '# if(typeof email != "undefined") { # <span class="btn btn-default sendEmail" href="\\#" style="display: block;">Email</span> # } # ' }
      gridColumns.push { field: 'appUser', title: 'App User', filterable: false, template: '# if(appUser) { # <span class="btn btn-default sendInAppMsg" href="\\#" style="display: block;">Message</span> # } # ' }
    gridColumns.push { field: 'createdAt', title: 'Created', hidden: true, template: TEMPLATE_formatDate('createdAt')}


    angular.element('#grid').kendoGrid
      dataSource: dataSource
      toolbar: ["excel"],
      excel: {
        fileName: "users.xlsx",
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

    angular.element(".sendInAppMsg").on('click', ($event) ->
      # pause for a tick to allow for the $scope model to be updated first by setSelected()
      setTimeout ->
        $scope.sendMessage($event, $scope.selectedUser)
    )

    angular.element(".sendEmail").on('click', ($event) ->
      # pause for a tick to allow for the $scope model to be updated first by setSelected()
      setTimeout ->
        $scope.sendEmail($event, $scope.selectedUser)
    )

    angular.element('#grid').delegate(' table tr', 'dblclick', () ->
      if $scope.outfitters
        window.location = "#!/admin/outfitter/#{$scope.selectedUser._id}"
      else
        window.location = "#!/admin/masquerade/#{$scope.selectedUser._id}"
    )


  $scope.setSelected = (args) ->
    $scope.selectedUser = null
    $scope.selectedUser = this.dataItem(this.select());

  $scope.init.call(@)
])
