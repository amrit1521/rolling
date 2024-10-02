APP = window.APP
APP.Controllers.controller('HuntCatalogEmail', ['$scope', '$sce', '$modalInstance', 'huntCatalog', 'currentUser', 'resumeCb', 'Storage', 'User', 'TenantEmail', ($scope, $sce, $modalInstance, huntCatalog, currentUser, resumeCb, Storage, User, TenantEmail) ->

  $scope.init = ->
    $scope.huntCatalog = huntCatalog
    $scope.user = currentUser
    $scope.clientIds = $scope.user.clientId
    $scope.customNote = ""
    $scope.emails = $scope.user.email

    email = TenantEmail.adminByType {type: 'Hunt'}, ->
      if email?._id
        $scope.email = email
      else
        console.log "Failed to retrieve hunt template email for this tenant."
    , (err) ->
      console.log "Failed to retrieve hunt template email for this tenant.", err


  $scope.sendEmail = (clientIds, emails, customNote) ->
    emailList = emails.split(",")
    if emailList?.length > 20
      alert "There are too many additional emails.  Please reduce the list to 20 or less and send again."
      return
    params = {
      clientIds: clientIds.trim() if clientIds
      customNote: customNote
      additionalEmails: emails
      huntCatalogId: $scope.huntCatalog._id
      tenantEmailId: $scope.email._id
      sendAsTest: true
      task: "huntcatalog_email.send"
      userId: $scope.user._id
    }
    console.log "sendEmail packet:", params
    TenantEmail.adminSendTest params, (rsp) ->
      alert "Hunt email sent"
      $modalInstance.dismiss('ok')
    ,
      (err) ->
        if err.error
          msg = "Email failed to send with error " + err.error
        else
          msg = "Email failed to send with error " + err
        alert msg
        $modalInstance.dismiss(err)

  $scope.updateEmailList = (clientIds) ->
    if clientIds
      User.getUserEmails {clientIds: clientIds}, (rsp) ->
        emails = []
        for email in rsp
          emails.push email.email
        $scope.emails = emails.join(", ")
      ,
        (err) ->
          if err.error
            msg = "One or more clientIds do not have a valid associated email address. " + err.error
          else
            msg = "One or more clientIds do not have a valid associated email address. " + err
          alert msg

  $scope.cancel = ->
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
