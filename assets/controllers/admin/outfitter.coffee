APP = window.APP
APP.Controllers.controller('Outfitter', ['$scope', '$rootScope', '$location', '$routeParams', 'Storage', 'User', 'State', ($scope, $rootScope, $location, $routeParams, Storage, User, State) ->

  $scope.init = () ->
    $scope.user = Storage.get 'user'
    $scope.needInitUI = true
    $scope.outfitter = null
    $scope.loadingOutfitter = false;
    $scope.serviceRequest = null
    $scope.isNewRequest = false
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.outfitterStatus = [
      { name: "On Hold", value: "hold" }
      { name: "Contract Yes", value: "contract_yes" }
      { name: "Contract No", value: "contract_no" }
      { name: "Archived", value: "archived" }
      { name: "Need more info", value: "need more info" }
    ]
    $scope.outfitterComissions = [
      { name: "0%", value: "0" }
      { name: "10%", value: "10" }
      { name: "12%", value: "12" }
      { name: "15%", value: "15" }
      { name: "25%", value: "25" }
      { name: "30%", value: "30" }
      { name: "50%", value: "50" }
      { name: "100%", value: "100" }
    ]
    $scope.loadOutfitter($routeParams.id)

    if !$scope.user.isAdmin
      window.location = "/#!/dashboard"


  $scope.loadOutfitter = (outfitterId) ->
    $scope.loadingOutfitter = true;
    if outfitterId is "new"
      $scope.isNewOutfitter = true
      $scope.outfitter = new User()
      $scope.outfitter.isOutfitter = true
      $scope.outfitter.tenantId = $scope.user.tenantId
      $scope.outfitter.parentId = $scope.user._id
      $scope.outfitter.active = true
      $scope.outfitter.type = 'local'
      $scope.outfitter.needsWelcomeEmail = false
      $scope.outfitter.needsPointsEmail = false
      $scope.outfitter.referral = {
        "referId" : $scope.user._id,
        "ip" : "0.0.0.0.",
        "referrer" : "outfitter",
        "modified" : Date.now
      }
      $scope.loadingOutfitter = false;

    else
      $scope.loadingOutfitter = true;
      $scope.isNewOutfitter = false
      User.get {id: outfitterId}, (results) ->
        $scope.loadingOutfitter = false;
        if results
          $scope.outfitter = results
          results.contractEnd = new Date(results.contractEnd) if results.contractEnd
        else
          alert "Outfitter not found."
        $scope.initUI($scope.outfitter) if $scope.needInitUI
        $scope.needInitUI = false


      , (err) ->
        console.log "loading outfitter error:", err
        $scope.loadingOutfitter = false;

  $scope.submit = (outfitter) ->
    outfitter.first_name = outfitter.name
    outfitter.last_name = outfitter.name
    error = (res) ->
      if res?.data?.error
        alert(res.data.error)
      else
        alert "An error occurred while saving"

    updateOutfitterSuccess = (result) ->
      outfitter = _.omit result, '__v', '$promise', '$resolved'
      $scope.outfitter = outfitter
      $scope.redraw()
      console.log "Sending request to update RRADS..."
      User.user_upsert_rads {_id: outfitter._id, tenantId: outfitter.tenantId}, (results) ->
        console.log "RRADS updated."
      , (err) ->
        console.log "Error: request to update RRADS failed with error: ", err
      alert 'Outfitter saved successfully.'
      window.location = "#!/users/search?outfitter=1"

    #update/insert Outfitter
    userData = _.omit outfitter, '__v', '$promise', '$resolved'
    if $scope.isNewOutfitter
      User.save userData, updateOutfitterSuccess, error
    else
      User.update userData, updateOutfitterSuccess, error

  $scope.initUI = (outfitter) ->
    outfitterId = outfitter._id if outfitter
    files = []
    if outfitter.files?.length
      for file in outfitter.files
        file.name = file.originalName
        files.push file

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
      return

    onSuccess = (e) ->
      console.log 'Success (' + e.operation + ') :: ' + getFileInfo(e)
      $scope.loadOutfitter($scope.outfitter._id) if $scope.outfitter._id
      return

    onError = (e) ->
      console.log 'Error (' + e.operation + ') :: ' + getFileInfo(e)
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
    saveUrl = "users/admin/fileAdd/#{outfitterId}/#{apitoken}"
    removeUrl = "users/admin/fileRemove/#{outfitterId}/#{apitoken}"
    angular.element('#files').kendoUpload
      async:
        saveUrl: saveUrl
        removeUrl: removeUrl
        autoUpload: false
      dropZone: ".dropZone"
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
      }


  $scope.cancel = () ->
    window.location = "#!/users/search?outfitter=1"

  $scope.init.call(@)
])
