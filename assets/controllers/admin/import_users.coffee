APP = window.APP
APP.Controllers.controller('ImportUsers', ['$scope', 'Storage', 'User', ($scope, Storage, User) ->

  $scope.init = ->
    $scope.user = Storage.get 'user'
    $scope.tenant = window.tenant
    $scope.showGrid = false
    $scope.processing = false
    $scope.show_error = false
    $scope.errorMessage = ""
    $scope.GRID_SELECTOR_ID = '#UsersImportGrid'
    $scope.users_new = []
    $scope.users_alreadyExists_email = []
    $scope.users_alreadyExists_clientId = []
    $scope.users_alreadyExists_other = []
    $scope.users_missing_email = []
    $scope.total_entries = 0
    $scope.initUI()

  $scope.submit = ($event) ->
    $scope.processing = true
    $event.preventDefault()
    User.user_import {users: $scope.users_new}, (results) ->
      $scope.processing = false
      alert 'Users imported successfully.'
      window.location = "#!/admin/reports/users"
    , (err) ->
      console.log "Error: Failed user import with error:: ", err
      $scope.processing = false
      errMsg = ""
      errMsg = err.data if err?.data?
      alert "User import failed. #{errMsg}"

  $scope.cancel = ($event) ->
    $event.preventDefault()
    window.location = "#!/admin/reports/users"

  $scope.initUI = () ->
    files = []
    getFileInfo = (e) ->
      $.map(e.files, (file) ->
        info = file.name
        # File size is not available in all browsers
        if file.size > 0
          info += ' (' + Math.ceil(file.size / 1024) + ' KB)'
        info
      ).join ', '

    onSelect = (e) ->
      console.log 'Select :: ' + getFileInfo(e)
      return

    onUpload = (e) ->
      console.log 'Upload :: ' + getFileInfo(e)
      $scope.processing = true
      $scope.showGrid = false
      $scope.users_new = []
      $scope.$apply()
      return

    onSuccess = (e) ->
      console.log 'Success (' + e.operation + ') :: ' + getFileInfo(e)
      $scope.total_entries = e.response.total_entries if e.response?.total_entries
      for user in e.response.users
        $scope.users_new.push user if user
      for user in e.response.alreadyExists_email
        $scope.users_alreadyExists_email.push user if user
      for user in e.response.alreadyExists_clientId
        $scope.users_alreadyExists_clientId.push user if user
      for user in e.response.alreadyExists_id
        $scope.users_alreadyExists_other.push user if user
      for user in e.response.alreadyExists_username
        $scope.users_alreadyExists_other.push user if user
      for user in e.response.missing_email
        $scope.users_missing_email.push user if user

      $scope.processing = false
      $scope.showGrid = true
      $scope.setupGrid(JSON.parse(JSON.stringify($scope.users_new)))
      $scope.$apply()
      return

    onError = (e) ->
      console.log 'Error (' + e.operation + ') :: ' + getFileInfo(e)
      $scope.show_error = true
      $scope.errorMessage = e
      $scope.$apply()
      return

    onComplete = (e) ->
      console.log 'Complete'
      return

    onCancel = (e) ->
      console.log 'Cancel :: ' + getFileInfo(e)
      return

    onRemove = (e) ->
      console.log 'Remove :: ' + getFileInfo(e)
      return

    onProgress = (e) ->
      console.log 'Upload progress :: ' + e.percentComplete + '% :: ' + getFileInfo(e)
      return

    apitoken = "EgWiJixOwcemGuegUbitOudsishpyoshVafApDyovrypDyajboofjenekshecfecBeileds1olMywejnewcelfoarmejGhotteiptOowJatJenVemyor2SlujPavfalyiegyincyRyirDowsobCacceskUryowtUnadTehijfersetajortabhotorweuncatkafBinUtlagsirakWavegteorUzHeObJethDycsobBesutjocwentym"
    saveUrl = "users/admin/parseuserimport/#{$scope.user._id}/#{apitoken}"
    removeUrl = "na"
    angular.element('#files').kendoUpload
      async:
        saveUrl: saveUrl
        removeUrl: removeUrl
        autoUpload: false
      multiple: false
      dropZone: ".dropZone"
      localization:
        select: "Select File"
        uploadSelectedFiles: "Preview Users"
      cancel: onCancel
      complete: onComplete
      error: onError
      progress: onProgress
      remove: onRemove
      select: onSelect
      success: onSuccess
      upload: onUpload
      files: files if files
      validation: {
        maxFileSize: 10485760 #10MB
        allowedExtensions: [".csv", ".png"]
      }


  $scope.setupGrid = (users) ->
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
            isOutfitter: { type: "boolean" }
            isVendor: { type: "boolean" }
            needsWelcomeEmail: { type: "boolean" }
            modified: { type: "date" }
            createdAt: { type: "date" }
          }
        }
      }
    })

    gridColumns = []
    gridColumns.push { field: 'row', title: 'Row', hidden: false}
    gridColumns.push { field: 'email', title: 'Email', hidden: false}
    gridColumns.push { field: 'first_name', title: 'First Name', hidden: true}
    gridColumns.push { field: 'last_name', title: 'Last Name', hidden: true}
    gridColumns.push { field: 'middle_name', title: 'Middle Name', hidden: true}
    gridColumns.push { field: 'name', title: 'Name', hidden: false}
    gridColumns.push { field: 'clientId', title: 'Client Id', hidden: true}
    gridColumns.push { field: 'parentId', title: 'Parent Id', hidden: true, aggregates: ["count"], }
    gridColumns.push { field: 'parentName', title: 'Parent Name', hidden: false, aggregates: ["count"], }
    gridColumns.push { field: 'phone_cell', title: 'Phone Cell', hidden: false}
    gridColumns.push { field: 'active', title: 'Active', hidden: true}
    gridColumns.push { field: 'createdAt', title: 'Created At', hidden: true, template: TEMPLATE_formatDate('createdAt')}
    gridColumns.push { field: 'modified', title: 'Modified', hidden: true, template: TEMPLATE_formatDate('modified')}
    gridColumns.push { field: 'referredBy', title: 'Referred By', hidden: true}
    gridColumns.push { field: 'isOutfitter', title: 'Is Outfitter', hidden: true}
    gridColumns.push { field: 'isVendor', title: 'Is Vendor', hidden: true}
    gridColumns.push { field: 'imported', title: 'Imported', hidden: true}
    gridColumns.push { field: 'internalNotes', title: 'Internal Notes', hidden: true}
    gridColumns.push { field: 'needsWelcomeEmail', title: 'Needs Welcome Email', hidden: true}
    gridColumns.push { field: 'mail_address', title: 'Mail Address', hidden: true}
    gridColumns.push { field: 'mail_city', title: 'Mail City', hidden: true}
    gridColumns.push { field: 'mail_country', title: 'Mail Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'mail_postal', title: 'Mail Postal', hidden: true}
    gridColumns.push { field: 'mail_state', title: 'Mail State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'physical_address', title: 'Physical Address', hidden: true}
    gridColumns.push { field: 'physical_city', title: 'Physical City', hidden: true}
    gridColumns.push { field: 'physical_country', title: 'Physical Country', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }
    gridColumns.push { field: 'physical_postal', title: 'Physical Postal', hidden: true}
    gridColumns.push { field: 'physical_state', title: 'Physical State', hidden: true, aggregates: ["count"], groupHeaderTemplate: "#= data.field#: #=data.value# (total: #= count#)" }

    $scope.toolbar = ["excel"]

    angular.element($scope.GRID_SELECTOR_ID).kendoGrid
      dataSource: dataSource
      toolbar: $scope.toolbar
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

  $scope.init.call(@)
])
