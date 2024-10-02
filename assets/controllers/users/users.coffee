APP = window.APP
APP.Controllers.controller('Users', ['$scope', '$location', '$routeParams', 'Format', 'Point', 'State', 'Storage', 'User', ($scope, $location, $routeParams, Format, Point, State, Storage, User) ->
  $scope.init = () ->
    $scope.showHeaderButtons($scope)
    $scope.user = Storage.get 'user'
    $scope.userBeforeUpdate = _.clone $scope.user
    $scope.adminUser = Storage.get 'adminUser'
    $scope.repChanged = false

    $scope.repTypes = []
    $scope.repStatuses = []
    $scope.memberStatuses = []
    $scope.memberTypes = []
    $scope.states = State.stateList
    $scope.countries = User.countryList
    $scope.sanitize()
    $scope.getParentAndRep()
    $scope.loadFiles()
    $scope.initUI()

    if window?.tenant?._id is "5684a2fc68e9aa863e7bf182" or window?.tenant?._id is "5bd75eec2ee0370c43bc3ec7"
      $scope.repTypes = [
        { name: "Outdoor Software Solutions Partner", value: "Outdoor Software Solutions Partner" }
        { name: "Associate Adventure Advisor", value: "Associate Adventure Advisor" }
        { name: "Adventure Advisor", value: "Adventure Advisor" }
        { name: "Senior Adventure Advisor", value: "Senior Adventure Advisor" }
        { name: "Regional Adventure Advisor", value: "Regional Adventure Advisor" }
        { name: "Agency Manager", value: "Agency Manager" }
        { name: "Senior Agency Manager", value: "Senior Agency Manager" }
        { name: "Executive Agency Manager", value: "Executive Agency Manager" }
        { name: "Senior Executive Agency Manager", value: "Senior Executive Agency Manager" }
      ]
      $scope.repStatuses = [
        { name: "auto renew tenant", value: "auto-renew-tenant" }
        { name: "auto renew monthly", value: "auto-renew-monthly" }
        { name: "auto renew retry", value: "auto-renew-retry" }
        { name: "cancelled", value: "cancelled" }
        { name: "expired", value: "expired" }
        { name: "CC expired", value: "cc_expired" }
        { name: "CC expiring Soon", value: "cc_expires_soon" }
        { name: "CC failed", value: "cc_failed" }
      ]
      $scope.memberStatuses = [
        { name: "auto renew monthly", value: "auto-renew-monthly" }
        { name: "auto renew yearly", value: "auto-renew-yearly" }
        { name: "auto renew retry", value: "auto-renew-retry" }
        { name: "cancelled", value: "cancelled" }
        { name: "expired", value: "expired" }
        { name: "CC expired", value: "cc_expired" }
        { name: "CC expiring Soon", value: "cc_expires_soon" }
        { name: "CC failed", value: "cc_failed" }
      ]
    $scope.memberTypes = [
        { name: "Silver", value: "silver" }
        { name: "Gold", value: "gold" }
        { name: "Platinum", value: "platinum" }
    ]
    $scope.outfitterStatus = [
      { name: "Potential", value: "potential" }
      { name: "Approved and Vetted", value: "approved" }
      { name: "Suspended", value: "suspended" }
      { name: "Expired", value: "expired" }
      { name: "Need more info", value: "need more info" }
      { name: "On Hold", value: "hold" }
    ]
    $scope.paymentProcess = [
      { name: "Net 30", value: "Net 30" }
      { name: "Due on Receipt", value: "Due on Receipt" }
      { name: "Trade", value: "Trade" }
    ]
    $scope.paymentMethods = [
      { name: "Sends invoice for payment", value: "invoice" }
      { name: "Auto charges credit card on file", value: "cc on file" }
    ]
    $scope.shippingMethods = [
      { name: "Vendor drop ships", value: "drop ship" }
    ]

    $scope.user.country = 'United States' if not $scope.user.mail_country or $scope.user.mail_country.toLowerCase() in ['us', 'usa']

    _.extend $scope, _.pick(User, 'eyes', 'genders', 'hairs')

#    $('#inputBirthDate').on 'blur', ->
#      return unless $scope.user
#      Format.checkDOB($scope.user)
#      $scope.redraw()


  $scope.logout = ->
    Storage.clear()

  $scope.sanitize = ->
    $scope.user.ssnx = $scope.user.ssn if $scope.user.ssn
    $scope.user.ssn = null
    #If coming back to the page, $scope.user.dob is already converted so don't do it again.
    tmpDOB = ""
    tmpDOB = $scope.user.dob.toString() if $scope?.user?.dob
    if isNaN(tmpDOB.substr(0,4)) is false
      $scope.user.dob = moment($scope.user.dob, 'YYYY-MM-DD').toDate()
    $scope.user.repExpires = new Date($scope.user.repExpires) if $scope.user.repExpires
    $scope.user.repStarted = new Date($scope.user.repStarted) if $scope.user.repStarted
    $scope.user.rep_next_payment = new Date($scope.user.rep_next_payment) if $scope.user.rep_next_payment
    $scope.user.memberStarted = new Date($scope.user.memberStarted) if $scope.user.memberStarted
    $scope.user.memberExpires = new Date($scope.user.memberExpires) if $scope.user.memberExpires
    $scope.user.payment_form_sent = new Date($scope.user.payment_form_sent) if $scope.user.payment_form_sent
    $scope.user.payment_form_received = new Date($scope.user.payment_form_received) if $scope.user.payment_form_received
    $scope.user.outfitter_vetted_date = new Date($scope.user.outfitter_vetted_date) if $scope.user.outfitter_vetted_date
    $scope.user.vendor_pricing_confirmed = new Date($scope.user.vendor_pricing_confirmed) if $scope.user.vendor_pricing_confirmed
    $scope.user.vendor_vetted_date = new Date($scope.user.vendor_vetted_date) if $scope.user.vendor_vetted_date

  $scope.getParentAndRep = () ->
    results = User.getParentAndRep {userId: $scope.user._id}, () ->
      $scope.user.parent_name = results.parent.name if results?.parent?.name
      $scope.user.parent_clientId = results.parent.clientId if results?.parent?.clientId
      $scope.user.rep_name = results.rep.name if results?.rep?.name
      $scope.user.rep_clientId = results.rep.clientId if results?.rep?.clientId
      #console.log " $scope.user.parent_name",  $scope.user.parent_name, results

  $scope.setOutfitterDefaults = () ->
    return
    #if !$scope.user.isOutfitter
    #  $scope.user.isVendor = false


  $scope.setVendorDefaults = () ->
    if $scope.user.isVendor
      $scope.user.vendor_rbo_order_process = "Default automated email from us" if !$scope.user.vendor_rbo_order_process?.length
      $scope.user.vendor_rbo_order_confirmed_process = "Email from vendor to customer and copy us" if !$scope.user.vendor_rbo_order_confirmed_process?.length
      $scope.user.vendor_rbo_return_process = "Customer notifies the Vendor, sends in the return.  Vendor notifies us, we refund the customer's money.  The Vendor refunds us. " if !$scope.user.vendor_rbo_return_process?.length
      #$scope.user.isOutfitter = true
    else
      $scope.user.vendor_rbo_order_process = ""
      $scope.user.vendor_rbo_order_confirmed_process = ""
      $scope.user.vendor_rbo_return_process = ""
      $scope.user.vendor_isFeatured = false
      #$scope.user.isOutfitter = false

  $scope.repInfoChanged = () ->
    $scope.repChanged = true

  $scope.validate = () ->
    missingFields = []
    if $scope.user.isOutfitter and $scope.user.status is "approved"
      missingFields.push "Vetted By" unless $scope.user.outfitter_vetted_by?.length
      missingFields.push "Vetted Date" unless $scope.user.outfitter_vetted_date
    if $scope.user.isVendor and $scope.user.status is "approved"
      missingFields.push "Approved By" unless $scope.user.vendor_vetted_by?.length
      missingFields.push "Approved Date" unless $scope.user.vendor_vetted_date
      missingFields.push "Orders Email" unless $scope.user.business_email
      missingFields.push "Contact Name" unless $scope.user.vendor_contact_name
      missingFields.push "Contact Email" unless $scope.user.vendor_contact_email
      missingFields.push "Contact Phone" unless $scope.user.business_phone
      missingFields.push "Written Confirmation of Vendor Pricing received" unless $scope.user.vendor_pricing_confirmed
      missingFields.push "Shipping Method" unless $scope.user.vendor_shipping_method
      missingFields.push "Vendor Payment Process" unless $scope.user.vendor_rbo_payment_process
      missingFields.push "Vendor Payment Method" unless $scope.user.vendor_rbo_payment_method
      missingFields.push "Vendor Order Process" unless $scope.user.vendor_rbo_order_process
      missingFields.push "Vendor Order Confirmation Process" unless $scope.user.vendor_rbo_order_confirmed_process
      missingFields.push "Vendor Returns Process" unless $scope.user.vendor_rbo_return_process

    if missingFields.length > 0
      msg = "Error: Profile not saved.  The following information is required:"
      fieldsStr = missingFields.join(",\n")
      alert "#{msg}\n#{fieldsStr}"
      return false
    else
      return true

  $scope.submit = (user) ->
    user.name = user.first_name + ' ' + user.last_name

    delete user.ssn if user?.ssn?.length < 9
    Format.checkSSN(user)

    #Password is ALWAYS updated separately.  This solves a problem with browsers and keychain auto populating non-encrypted password
    delete user.password if user.password

    #The password was encrypted already, so only re-save/encrypt it if it was changed
    #New Mexico
    if user.nmPasswordTmp == user.nmPassword || !user.nmPasswordTmp
      delete user.nmPassword
    else
      user.nmPassword = user.nmPasswordTmp
      user.needEncryptNMPassword = true
    delete user.nmPasswordTmp

    #Idaho
    if user.idPasswordTmp == user.idPassword || !user.idPasswordTmp
      delete user.idPassword
    else
      user.idPassword = user.idPasswordTmp
      user.needEncryptIDPassword = true
    delete user.idPasswordTmp

    #Arizona
    if user.azPasswordTmp == user.azPassword || !user.azPasswordTmp
      delete user.azPassword
    else
      user.azPassword = user.azPasswordTmp
      user.needEncryptAZPassword = true
    delete user.azPasswordTmp

    #South Dakota
    if user.sdPasswordTmp == user.sdPassword || !user.sdPasswordTmp
      delete user.sdPassword
    else
      user.sdPassword = user.sdPasswordTmp
      user.needEncryptSDPassword = true
    delete user.sdPasswordTmp

    #Washington
    if user.waPasswordTmp == user.waPassword || !user.waPasswordTmp
      delete user.waPassword
    else
      user.waPassword = user.waPasswordTmp
      user.needEncryptWAPassword = true
    delete user.waPasswordTmp

    #Colorado
    if user.coPasswordTmp == user.coPassword || !user.coPasswordTmp
      delete user.coPassword
    else
      user.coPassword = user.coPasswordTmp
      user.needEncryptCOPassword = true
    delete user.coPasswordTmp

    #Montana
    if user.mtPasswordTmp == user.mtPassword || !user.mtPasswordTmp
      delete user.mtPassword
    else
      user.mtPassword = user.mtPasswordTmp
      user.needEncryptMTPassword = true
    delete user.mtPasswordTmp

    #Nevada
    if user.nvPasswordTmp == user.nvPassword || !user.nvPasswordTmp
      delete user.nvPassword
    else
      user.nvPassword = user.nvPasswordTmp
      user.needEncryptNVPassword = true
    delete user.nvPasswordTmp


    user.country = 'United States' if user.mail_country?.toLowerCase() in ['us', 'usa']
    user = _.omit user, '__v', '$promise', '$resolved'

    #Whenever a profile is saved in NRADS we need to double make sure it get updated in RRADS
    user.needs_sync_nrads_rrads = true

    updateUserSuccess = ->
      user = _.omit result, '__v', '$promise', '$resolved'
      $scope.user = user
      $scope.sanitize()
      Storage.set 'user', user
      $scope.redraw()
      alert 'Profile saved successfully.'
      $scope.user.nmPasswordTmp = $scope.user.nmPassword
      $scope.user.idPasswordTmp = $scope.user.idPassword
      $scope.user.azPasswordTmp = $scope.user.azPassword
      $scope.user.sdPasswordTmp = $scope.user.sdPassword
      $scope.user.waPasswordTmp = $scope.user.waPassword
      $scope.user.coPasswordTmp = $scope.user.coPassword
      $scope.user.mtPasswordTmp = $scope.user.mtPassword
      $scope.user.nvPasswordTmp = $scope.user.nvPassword
      delete $scope.user.needEncryptAZPassword if $scope.user.needEncryptAZPassword
      delete $scope.user.needEncryptNMPassword if $scope.user.needEncryptNMPassword
      delete $scope.user.needEncryptSDPassword if $scope.user.needEncryptSDPassword
      delete $scope.user.needEncryptIDPassword if $scope.user.needEncryptIDPassword
      delete $scope.user.needEncryptWAPassword if $scope.user.needEncryptWAPassword
      delete $scope.user.needEncryptCOPassword if $scope.user.needEncryptCOPassword
      delete $scope.user.needEncryptMTPassword if $scope.user.needEncryptMTPassword
      delete $scope.user.needEncryptNVPassword if $scope.user.needEncryptNVPassword
      $scope.userBeforeUpdate = _.clone $scope.user
      console.log "Sending request to update RRADS..."
      User.user_upsert_rads {_id: user._id, tenantId: user.tenantId}, (results) ->
        console.log "RRADS updated."
        User.reassign_rep_downline_all {_id: user._id, parentId: user.parentId, tenantId: user.tenantId, clientId: user.clientId, reassign_rep_downline_all: $scope.repChanged}, (results) ->
          console.log "RRADS reps updated."
        , (err) ->
          console.log "Error: request to update RRADS reps failed with error: ", err
      , (err) ->
        console.log "Error: request to update RRADS failed with error: ", err

    updateUserErr = (res) ->
      if res?.data?.error
        alert "An error occurred while savingt"
      else
        alert "An error occurred while savingt"

    if $scope.validate()

      #username changed
      console.log 'user.username',user.username
      if $scope.userBeforeUpdate.username == user.username
        console.log 'user'
        result = User.update user, updateUserSuccess, updateUserErr
      else
        User.checkExists {type: "username", username: user.username, tenantId: user.tenantId},
          (res) ->
            if res.exists
              alert "The username '#{user.username}' is already in use.  Please enter a new username and try again."
            else
              console.log 'user update'
              result = User.update user, updateUserSuccess, updateUserErr
          ,
          updateUserErr

  $scope.loadFiles = () ->
    User.get {id: $scope.user._id}, (results) ->
      if results
        $scope.user.files = results.files
      else
        alert "Loading user files failed."
    , (err) ->
      console.log "Loading user files failed with error:", err

  $scope.initUI = () ->
    files = []
    if $scope.user.files?.length
      for file in $scope.user.files
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
      $scope.loadFiles()
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
    saveUrl = "users/admin/fileAdd/#{$scope.user._id}/#{apitoken}"
    removeUrl = "users/admin/fileRemove/#{$scope.user._id}/#{apitoken}"
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





  $scope.init.call(@)
])
