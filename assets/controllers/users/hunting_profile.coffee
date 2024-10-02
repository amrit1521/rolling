APP = window.APP
APP.Controllers.controller('HuntingProfile', ['$scope', '$location', '$routeParams', 'Format', 'Point', 'State', 'Storage', 'User', 'ClientState', 'TenantEmail', ($scope, $location, $routeParams, Format, Point, State, Storage, User, ClientState, TenantEmail) ->
  $scope.init = () ->
    #$scope.showHeaderButtons($scope)
    $scope.user = Storage.get 'user'
    $scope.adminUser = Storage.get 'adminUser'
    $scope.userBeforeUpdate = _.clone $scope.user
    $scope.clientStateYear = "2018" #todo, make this part of the UI to pick
    $scope.applicationcheckbox = $scope.user.powerOfAttorney

    $scope.clientState = {}
    $scope.getUserClient($scope.clientStateYear)

    $scope.ApplicationServiceTentants = ["5684a2fc68e9aa863e7bf182","54a8389952bf6b5852000007", "5846ffc35dc6e3a21e45bcc3",
      "5866e8ef57fa4d2128046e0d", "5866e95a57fa4d2128046e0e", "5891935cd608012750c9bb55", "5891943ed608012750c9bb56"]
    #RollingBones, GotMyTagDev, Northwest Hunter, Bowhunting Safari, The Outdoor Insiders, GetNDrawn, HuntersDomain
    #$scope.ApplicationServiceTentants.push "53a28a303f1e0cc459000127"  #Test.GotMyTag.com
    $scope.ApplicationServiceTentants.push "56f44d39e680961c4b86f6f7"  #muleycrazy
    $scope.ApplicationServiceTentants.push "56abd3b716eb69800e8c6b5a"  #OGTV
    $scope.ApplicationServiceTentants.push "59dd52855cd13973b804cc0b"  #The Draw
    $scope.ApplicationServiceTentants.push "5bd75eec2ee0370c43bc3ec7"  #RBO VERDARD TEST
    $scope.getShowApplicationService()
    $scope.settenantOfficialName()

    email = TenantEmail.adminByType {type: 'Welcome'}, ->
      if email?._id
        $scope.email = email
      else
        console.log "Failed to retrieve welcome email for this tenant."
    , (err) ->
      console.log "Failed to retrieve welcome email for this tenant.", err

  $scope.settenantOfficialName = ->
    $scope.tenantOfficialName = ""
    if $scope.user?.tenantId
      $scope.tenantOfficialName = "GotMyTag LLC" if $scope.user.tenantId == "54a8389952bf6b5852000007" or $scope.user.tenantId.toString() == "54a8389952bf6b5852000007"
      $scope.tenantOfficialName = "Rolling Bones Outfitters" if $scope.user.tenantId == "5684a2fc68e9aa863e7bf182" or $scope.user.tenantId.toString() == "5bd75eec2ee0370c43bc3ec7"
      $scope.tenantOfficialName = "Northwest Hunter" if $scope.user.tenantId == "5846ffc35dc6e3a21e45bcc3" or $scope.user.tenantId.toString() == "5846ffc35dc6e3a21e45bcc3"

  $scope.sanitize = ->
    $scope.user.ssnx = $scope.user.ssn if $scope.user.ssn
    $scope.user.ssn = null
    #If coming back to the page, $scope.user.dob is already converted so don't do it again.
    tmpDOB = ""
    tmpDOB = $scope.user.dob.toString() if $scope?.user?.dob
    if isNaN(tmpDOB.substr(0,4)) is false
      $scope.user.dob = moment($scope.user.dob, 'YYYY-MM-DD').toDate()

  $scope.getShowApplicationService = ->
    $scope.showApplicationService = false
    if $scope?.user?.tenantId and ($scope.user.tenantId in $scope.ApplicationServiceTentants or $scope.user.tenantId.toString() in $scope.ApplicationServiceTentants)
      $scope.showApplicationService = true
    else if $scope.adminUser?.isAdmin and !$scope.adminUser?.tenantId
      $scope.showApplicationService = true
    else
      $scope.showApplicationService = false

  $scope.getUserClient = (year) ->
    return unless $scope.user?._id and year
    clientStateData = {
      userId: $scope.user._id,
      year: year
    }

    handleErr = (res) ->
      if res?.data?.error
        console.log res.data.error

    success = (clientState) ->
      return unless clientState
      for key, value of clientState
        clientState[key] = true if value?.toString().toLowerCase() == "true" and key.indexOf("check") != -1
      $scope.clientState = clientState
      $scope.clientState.client_id = $scope.user.clientId if $scope.user.clientId

    ClientState.get clientStateData, success, handleErr

  $scope.powerOfAttorneyCheck = (stateAbr) ->
    clientStateKey = "#{stateAbr}_check"
    if !$scope.user.powerOfAttorney
      for key, value of $scope.clientState
        $scope.clientState[key] = false if key.indexOf("check") != -1
      alert("You must first select the 'power of attorney' checkbox at the top of this page in order to use our application services.  Thank you.")
    #else if $scope.clientState[clientStateKey]
      #alert("Thank you.  Please add your state hunting preferences in the notes field.  For example: I'd like to apply for muzzleloader/rifle Mule Deer with best odds for an over 170 buck.")

  $scope.powerOfAttorneyClick = () ->
    if $scope.user.powerOfAttorney == false
      for key, value of $scope.clientState
        $scope.clientState[key] = false if key.indexOf("check") != -1
    if $scope.user.powerOfAttorney == true
      alert("Thank you. You may now select which states you want to apply in.")


  $scope.submit = (user) ->
    error = (res) ->
      if res?.data?.error
        alert(res.data.error)
      else
        alert "An error occurred while savinertyerg"

    updateUserSuccess = (result) ->
      user = _.omit result, '__v', '$promise', '$resolved'
      $scope.user = user
      $scope.sanitize()
      Storage.set 'user', user
      $scope.userBeforeUpdate = _.clone $scope.user
      $scope.redraw()
      alert 'Hunting Profile saved successfully.'

    updateClientStateSuccess = (clientState) ->
      #Set the clientId on the user if the client id was newly assigned in the updateClient call
      $scope.clientState.client_id = clientState.client_id if clientState.client_id

      #Now update the user if powerOfAttorney was changed
      if $scope.user.powerOfAttorney != $scope.userBeforeUpdate.powerOfAttorney
        userData = {
          _id: user._id,
          powerOfAttorney: $scope.user.powerOfAttorney
        }
        result = User.update userData, updateUserSuccess, error
      else
        $scope.redraw()
        alert 'Hunting Profile saved successfully.'

    #update Client State
    clientStateData = $scope.clientState
    clientStateData.powerOfAttorney = user.powerOfAttorney
    clientStateData.userId = user._id
    clientStateData.client_id = user.clientId if user.clientId
    clientStateData.year = $scope.clientStateYear
    clientStateData.nmfst = user.first_name
    clientStateData.nmlt = user.last_name
    clientStateData.tenantId = user.tenantId
    clientStateData.allSpecies = true if $scope.showApplicationService

    User.updateClient clientStateData, updateClientStateSuccess, error


  $scope.sendEmail = ($event) ->
    $event.preventDefault()
    return alert("Could not retrieve valid welcome email to send.") unless $scope.email?._id
    result = confirm "Confirm sending email to #{$scope.user.email}"
    if result
      params = {
        userId: $scope.user._id
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


  $scope.pageIsReadOnly = () ->
    readOnlyTenants = ['59dd52855cd13973b804cc0b']
    if $scope.user?.tenantId?.toString() in readOnlyTenants and !$scope.adminUser
      return true
    else
      return false


  $scope.huntCatalog = ($event) ->
    $event.preventDefault()
    window.location = "#!/huntcatalogs"


  $scope.cancel = () ->
    window.location = "#!/dashboard"


  $scope.init.call(@)
])
