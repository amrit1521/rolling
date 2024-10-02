APP = window.APP
APP.Controllers.controller('AdminSearch', ['$scope', '$sce', '$rootScope', '$location', '$log', '$modal', '$timeout', 'HuntChoice', 'Point', 'Search', 'State', 'Storage', 'Stream', 'Pubnub', 'User', ($scope, $sce, $rootScope, $location, $log, $modal, $timeout, HuntChoice, Point, Search, State, Storage, Stream, Pubnub, User) ->
  $scope.loadingApplications = false
  $scope.state = null
  $scope.montana = {}
  pageLimit = 40
  $scope.menu = {}
  $scope.user = Storage.get 'user'

  $scope.applications = {
    alaska: "Alaska"
    arizona_fall: "Arizona Fall Buffalo"
    arizona_buffalo_deer_sheep: "Arizona Buffalo/Deer/Sheep"
    arizona_antelope_elk: "Arizona Antelope/Elk"
    california: "California"
    colorado: "Colorado"
    florida: "Florida"
#    idaho_deer_elk_antelope: "Idaho Deer/Elk/Antelope"
    idaho_antelope_deer_elk: "Idaho Antelope/Deer/Elk"
    idaho_goat_moose_sheep: "Idaho Goat/Moose/Sheep"
    iowa: "Iowa"
    kentucky: "Kentucky"
    montana_deer_elk: "Montana Deer/Elk"
    montana_antelope_buffalo_goat_moose_sheep: "Montana Antelope/Buffalo/Goat/Moose/Sheep"
    nevada: "Nevada"
    new_mexico: "New Mexico Antelope/Deer/Elk/Ibex/Javelina/Oryx/Sheep"
    north_dakota: "North Dakota"
    south_dakota: "South Dakota"
    oregon: "Oregon"
#    oregon_points_only: "Oregon Points only"
    pennsylvania: "Pennsylvania"
    texas: "Texas"
    utah_spring: "Utah Spring"
    vermont: "Vermont"
    washington: "Washington"
    wyoming_elk_goat_moose_sheep: "Wyoming Elk/Goat/Moose/Sheep"
    wyoming_antelope_deer: "Wyoming Antelope/Deer"
    wyoming_points: "Wyoming Points"
  }

  $scope.searchRanges = {
    a_b: "A - B"
    c_d: "C - D"
    e_f: "E - F"
    g_h: "G - H"
    i_j: "I - J"
    k_l: "K - L"
    m_n: "M - N"
    o_p: "O - P"
    q_r: "Q - R"
    s_t: "S - T"
    u_v: "U - V"
    w_x: "W - X"
    y_z: "Y - Z"
  }
  $scope.search.range = "a_b"

  $scope.searchStatuses = {
    all: "All"
    #saved: "Saved"
    #review_requested: "Review Requested"
    #review_ready: "Review Ready"
    #reviewed: "Reviewed"
    purchase_requested: "Purchase Requested"
    purchased: "Purchased"
    error: "Error"
  }
  $scope.search.status = "all"


  $scope.init = () ->

    Pubnub.init()
    if $scope?.user?._id
      console.log "Pubnub listening on channel: #{$scope.user._id.toString()}"
      Pubnub.subscribe $scope, $scope.user._id.toString(), 100
      $scope.$on 'PUBNUB-purchase-app-update', ($event, message) ->
        $scope.handleUpdateMessage(message)
    else
      console.log "$scope.user._id is not currently set.", $scope.user
      alert "Status update messages when running applications are temporarily unavailable.  Please refresh this page to re-enable them, or contact info@rollingbonesoutfitters.com for assistance. Thank You"

    $scope.$on "$destroy", ->
      Stream.disconnect()
      Pubnub.unsubscribe $scope, $scope.user._id.toString()

    $scope.search = $rootScope.search

    $scope.$watch 'search.application', (newVal) ->
      $scope.applicationSearch newVal

    $scope.$watch 'search.range', (newVal) ->
      $scope.applicationSearch $scope.search.application

    $scope.$watch 'search.status', (newVal) ->
      $scope.applicationSearch $scope.search.application

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

  $scope.handleUpdateMessage = (message) ->
    console.log "PUBNUB-purchase-app-update message:", message
    for application in $scope.allApplications
      continue unless application._id is message.data.appUserId
      application.appPurchaseMsg = message.data.message
      $scope.redraw()
      break

  $scope.hideMemberHunt = (leader, member, targetHunt, value) ->

    for application in $scope.allApplications
      continue unless application._id is member._id

      for hunt in application.hunts
        continue unless hunt._id is targetHunt._id
        if value
          hunt.storedChoices = hunt.choices
          hunt.choices = {group_id: leader._id}
          hunt.groupLeader = leader
        else
          hunt.choices = hunt.storedChoices
          hunt.storedChoices = null
          hunt.groupLeader = null

  $scope._search = (search) ->
    return unless search?.text?.length > 2

    search.type = 'name'

    results = Search.find search, ->
      for result in results
        result.name = result.first_name + ' ' + result.last_name if not result.name and result.first_name and result.last_name
      $scope.results = results
    , ->
      console.log "search errored"

  $scope.sendMessage = ($event, user) ->
    message = prompt "Please enter the message you wish to send"
    return unless message

    User.message {userId: user._id, message}

  $scope.showTransaction = ($event, application, hunt) ->
    $event.preventDefault()
    if hunt.status
      if hunt.status == "error"
        results = Search.applicationByUserHuntYear {userId: application._id, huntId: hunt._id, year: moment().year().toString()},
          ->
            console.log "app results:", results
            if results.lastPage
              modal = $modal.open
                templateUrl: 'templates/partials/search_lastpage.html'
                controller: 'LastPage'
                resolve: {
                  pageSrc: -> return results.lastPage
                  error: -> return results.error
                }
                scope: $scope

              modal.result.then ->
                console.log "modal end1"
              , ->
                console.log "modal end2"
            else
              alert "Error: #{results.error}"
      else if hunt.status == "review_ready" or hunt.status == "purchase_requested"
        results = Search.applicationByUserHuntYear {userId: application._id, huntId: hunt._id, year: moment().year().toString()},
          ->
            console.log "app results:", results
            $scope.showReview($event, results) if results
      else
        alert "This hunt is in application transaction id: #{hunt.transactionId}, with status: #{hunt.status}, cc: #{hunt.cardTitle}"

  $scope.huntNotEditable = (hunt) ->
    if hunt.status == "purchased"
      return true
    else
      return false

  $scope.applicationSearch = (application) ->
    return unless application

    if application.indexOf('new') > -1 or application.indexOf('south') > -1 or application.indexOf('north') > -1
      $scope.state = "#{application.split('_')[0]}_#{application.split('_')[1]}"
    else
      $scope.state = "#{application.split('_')[0]}"

    # Clear out current results
    $scope.allApplications = null
    $scope.drawingApplications = false
    $scope.huntOptions = null
    $scope.loadingApplications = false
    $scope.userApplications = null
    $scope.montana = {}

    $scope.loadingApplications = true
    range = if $scope.search.range then $scope.search.range else "a_z"
    status = if $scope.search.status then $scope.search.status else "all"
    results = Search.application {application, range, status},
      ->
        $scope.huntOptions = {}

        console.log "results:", results
        for option in results.options
          $scope.huntOptions[option.huntId] ?= []
          $scope.huntOptions[option.huntId].push if typeof option.data is 'string' then JSON.parse(option.data) else option.data

        results.users = results.users.sort (a, b) ->
          aFirst = a.first_name.toLowerCase()
          bFirst = b.first_name.toLowerCase()

          aLast = a.last_name.toLowerCase()
          bLast = b.last_name.toLowerCase()

          if aLast > bLast
            1
          else if aLast is bLast
            if aFirst > bFirst
              1
            else if aFirst is bFirst
              0
            else
              -1
          else
            -1

        currentLetter = null
        pageCount = 0
        page = 1
        for user in results.users
          user.review = false
          user.name = "#{user.first_name} #{user.last_name}" unless user.name

          #set application licenseNumber and licenseYear for those state that require a previous year's license number to apply:
          if user.hunts?.length
            stateId = user.hunts[0].stateId.toString()
            if stateId is "547fee39ac604956f8b14370"
              user.licenseNumber = user.alaska_license
              user.licenseNumberYear = user.alaska_license_year
            else if stateId is "52aaa4cbe4e055bf33db649b"
              user.licenseNumber = user.idaho_license
              user.licenseNumberYear = user.idaho_license_year

          cards = user.postal2.split(' ') if user.postal2
          user.cards = []
          lastIndex = 0
          for key, index in ['1', '2']
            user.cards.push {index: key, title: '#' + key + ' XXXX-XXXX-XXXX-' + cards[index]} if cards and cards[index].length
            lastIndex = index
          user.cards.push {index: (parseInt(lastIndex, 10) + 1), blank: true, title: 'Use another card'}

          user.hasReceipt = !!user.receipts?.length

          filterKey = user.last_name.substr(0, 1).toUpperCase()
          if currentLetter isnt filterKey

            currentLetter = filterKey
            pageCount = 0
            page = 1

          user.page = page
          user.filterKey = filterKey
          pageCount++

          $scope.menu[filterKey] = page
          if pageCount > pageLimit
            pageCount = 0
            page++

          if user?.hunts
            for hunt in user.hunts
              hunt.members = []

        $scope.allApplications = results.users

        console.log "Set filterKey"
        $scope.search.filterKey = Object.keys($scope.menu)[0]
        $scope.setPages()
        $scope.setApplications()

        console.log "$scope.filterKey:", $scope.search.filterKey
        console.log "$scope.search.pages:", $scope.search.pages

        $scope.$watch 'search.filterKey', (newVal, oldVal) ->
          if newVal isnt oldVal
            $scope.setPages()
            $scope.setApplications()

        $scope.loadingApplications = false

      (res) ->
        $scope.loadingApplications = false
        return alert(res.data.error) if res?.data?.error
        alert "search errored"

  $scope.setApplications = ->
    console.log "setApplications called"
    return unless $scope.allApplications
    $scope.startTime = new Date()

    $timeout ->

      console.log "Start load"
      $scope.drawingApplications = true

      $timeout ->
        currentApps = []
        for application in $scope.allApplications
          # {filterKey: filterKey, page: page}
          if application.filterKey is $scope.search.filterKey and application.page is $scope.search.page
            application.notesAsHTML = application.notes.replace(/(?:\r\n|\r|\n)/g, '<br/>')
            application.notesAsHTML = $sce.trustAsHtml(application.notesAsHTML);

            currentApps.push application

        $scope.userApplications = currentApps
        console.log "apps set:", (new Date() - $scope.startTime) / 1000
        Stream.on 'connected', ->
          for application in $scope.userApplications
            if application.running
              console.log "On stream reconnect found an application running."
              #application.running = false
              #application.errors = "Connection lost"

          $scope.redraw()

        $timeout ->
          $scope.drawingApplications = false
          console.log "content loaded:", (new Date() - $scope.startTime) / 1000

  $scope.setPages = ->
    console.log "setPages"
    $scope.search.pages = (num for num in [1..$scope.menu[$scope.search.filterKey]])
    $scope.search.page = 1

  $scope.turnPage = (page) ->
    $scope.search.page = page
    $scope.redraw()
    $scope.setApplications()

  $scope.filterResults = (value) ->
    console.log "filterResults:", value

  $scope.getInclude = (hunt) ->
    fileName = hunt.toLowerCase().replace(/[^\w]+/g, '_').replace(/^_+|_+$/g, '').trim()
    fullFile = "templates/hunts/states/#{$scope.state}/search/#{fileName}.html"
    return fullFile

  $scope.runSearch = _.throttle($scope._search, 750)

  $scope.toggleAdmin = (user) ->
    # pause for a tick to allow for the model to be updated
    setTimeout ->
      console.log "toggleAdmin user:", user
      User.setAdmin {userId: user._id, isAdmin: user.isAdmin}

  $scope.prepChoice = (hunt, userId) ->
    pointOnly = false
    choices = {}

    for name, choice of hunt.choice
      continue unless choice

      choices[name] = ''
      if typeof choice is 'string'
        choices[name] = choice
      else
        choices[name] = choice.value
      pointOnly = choice.hunterChoice.replace(/[^\d]/g) isnt choice.hunterChoice if choice.hunterChoice

      #Only needed to clear Nevada 2016 choices to 2017 options
      if hunt.stateId is "52aaa4cbe4e055bf33db649d" and typeof choice is 'string'
        lastPart =  choice.slice(choice.length-8, choice.length) if choice.length > 7
        isNumber = !isNaN(choice.charAt(choice.length-1))
        if lastPart
          delete choices[name] if isNumber and lastPart.indexOf("Answer") > -1

    if hunt.members
      hunt.members = hunt.members.filter (member) ->
        return member

    {
      choices
      hunt: hunt.params
      huntId: hunt._id
      members: hunt.members
      userId: userId
      stateId: hunt.stateId
      name: hunt.name
      pointOnly
    }

  $scope.checkCard = (application) ->
    console.log "card:", application.cardIndex
    if application.cardIndex.blank
      console.log "open modal"
      $modal.open
        templateUrl: 'templates/partials/search_credit_card.html'
        controller: 'SearchCreditCard'
        resolve: application: -> return application
        scope: $scope

  $scope.editCard = ($event, application) ->
    $event.preventDefault()
    $modal.open
      templateUrl: 'templates/partials/search_credit_card.html'
      controller: 'SearchCreditCard'
      resolve: application: -> return application
      scope: $scope

  $scope.saveApplication = (application) ->
    return alert('Please wait until the connection to the server is restored.') unless $scope.connected
    alert "This application is currently running and cannot be saved until it completes." if application.running
    return if application.running

    application.saveOnly = true
    application.status = "saved"
    $scope.purchase(application)
    alert "Application saved successfully"

  $scope.purchase = (application) ->
    return alert('Please wait until the connection to the server is restored.') unless $scope.connected
    return if application.running
    application.results = null
    application.errors = null
    application.running = true
    cardIndex = application.cardIndex

    application.running = false unless cardIndex
    if application.status != "saved" and application.tenantId != "5734f80007200edf236054e6"
      return alert('Please enter or select a credit card before purchasing and try again.') unless cardIndex

    if not application.hunts.length
      application.running = false
      return

    hunts = []
    userId = application._id
    stateId = application.hunts[0].stateId

    blankHunts = []
    akStateId = "547fee39ac604956f8b14370"
    wyStateId = "52aaa4cbe4e055bf33db64a0"
    azStateId = "52aaa4cae4e055bf33db6499"
    utStateId = "52aaa4cbe4e055bf33db649f"
    nmStateId = "52aaa4cbe4e055bf33db649e"
    coStateId = "52aaa4cae4e055bf33db649a"
    nvStateId = "52aaa4cbe4e055bf33db649d"
    mtStateId = "52aaa4cbe4e055bf33db649c"
    idStateId = "52aaa4cbe4e055bf33db649b"
    orStateId = "52aaa4cbe4e055bf33db64a1"
    caStateId = "52aaa4cbe4e055bf33db64a2"
    sdStateId = "548a11fb94a663719435738e"


    if stateId is azStateId or stateId is utStateId or stateId is nmStateId or stateId is nvStateId or stateId is mtStateId or stateId is idStateId or stateId is orStateId or stateId is caStateId or stateId is akStateId
      for hunt in application.hunts

        ###
        # Check if hunt was 'cleared' in the UI
        # vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
        ###

        choice = $scope.prepChoice(hunt, application._id)
        #console.log "Choice", choice
        unless Object.keys(choice.choices).length
          blankHunts.push hunt._id
          continue
        foundValidChoice = false
        for key in Object.keys(choice.choices)
          # Check to see if the key exists and has a truthy value
          if choice.choices[key]
            foundValidChoice = true
            break
        blankHunts.push hunt._id unless foundValidChoice

        ###
        # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        ###


        #handle if hunt option changed and model still has old choice but it doesn't show in the select dropdown and looks blank
        validHuntOptions = {}
        foundValidHuntOptions = true
        if foundValidChoice
          tHuntOptions = $scope.huntOptions[hunt._id]
          #console.log "Hunt Options:", tHuntOptions
          for key in Object.keys(choice.choices)
            # Ignore input option fields that start with '_option' for ??
            # Ignore input option fields that start with '_num' for ??
            # Ignore input option fields that start with 'Guide' for Alaska - 2017
            continue if key is "choices" or key.indexOf("_option") > -1 or key.indexOf("_num") > -1 or key.indexOf("Guide") is 0
            foundValidHuntOption = false
            tHuntChoice = choice.choices[key]
            for hOption in tHuntOptions
              if tHuntChoice is hOption.value
                foundValidHuntOption = true
                break
            validHuntOptions[tHuntChoice] = foundValidHuntOption
          for fvhoKey, fvhoValue of validHuntOptions
            foundValidHuntOptions = false unless fvhoValue is true and fvhoKey != "choices"
            alert("This user's hunt choices contain old data.  Please reset the hunt choices by selecting a non-empty option from the dropdown selection for hunt #{hunt.name}") unless foundValidHuntOptions
          blankHunts.push hunt._id unless foundValidHuntOptions
        hunts.push choice if foundValidChoice and hunt.status != "purchased" and foundValidHuntOptions
    else if stateId is wyStateId or stateId is coStateId or stateId is sdStateId
      for hunt in application.hunts
        choice = $scope.prepChoice(hunt, application._id)
        #console.log "Choice:", choice
        foundValidChoice = false
        keys = Object.keys(choice.choices)
        if keys?.length
          for key in keys
            foundValidChoice = true if choice.choices[key] and (key.indexOf("comboHuntArea") > -1 or key.indexOf("hunt_code") > -1 or key.indexOf("option") > -1 or key.indexOf("general") > -1)
        else
          blankHunts.push hunt._id
          continue

        blankHunts.push hunt._id unless foundValidChoice
        hunts.push choice if foundValidChoice and hunt.status != "purchased"
    else
      application.running = false
      for hunt in application.hunts
        choice = $scope.prepChoice(hunt, application._id)
        #console.log "Choice:", choice
      alert "State hunt save error encountered. Please contact info@rollingbonesoutfitters.com for assistance."
      return

    if not hunts.length
      application.running = false
      alert "All selected hunts have either been purchased or are blank.  Please enter new hunt options and try again."
      return

    if stateId is azStateId and hunts?.length > 1 and application.newToState
      application.running = false
      alert "Please select only one species to apply as a new user.  Once that application is complete, the user will exist in AZ and have a department id.  You may then apply for additional application.  AFTER the first new application is complete, be sure to UNCHECK the 'new to state' option, as the user will now exist in AZ. Then continue applying for additional species.  Thank you."
      return
    if (stateId is azStateId or stateId is idStateId) and hunts?.length > 1 and (application.review is 'true' or application.review is true)
      alert "This state requires purchasing an application separately for each species.  The first application will run, then stop for review.  After seleting 'OK' on the review page, the next application will immediately start running for review.  This will repreat until each application has run and been reviewed."

    review = false
    if application.review is 'true' or application.review is true
      application.status = "review_requested"
      review = $scope.reviewPage(application)
    else
      application.status = "purchase_requested"
    application.package = {hunts, userId, stateId, cardIndex, review, prompt: $scope.prepPrompt(application)}
    application.package.status = application.status if application.status
    application.package.saveOnly = application.saveOnly if application.saveOnly
    application.package.blankHunts = blankHunts if blankHunts?.length
    application.package.newToState = application.newToState if application.newToState
    application.package.purchaseLicenseOnly = application.purchaseLicenseOnly if application.purchaseLicenseOnly
    application.package.mentoredYouth = application.mentoredYouth if application.mentoredYouth
    application.package.licenseNumber = application.licenseNumber if application.licenseNumber
    application.package.licenseNumberYear = application.licenseNumberYear if application.licenseNumberYear
    console.log "package:", application.package

    $scope.captcha(null, application) if stateId is orStateId
    Stream.purchase application.package, (err, result) ->
      application.running = false
      application.saveOnly = false
      console.log "result returned from server:", err, result

      if result?.fileURL?.status and !result.receipts
        result.receipts = [result.fileURL]
        result.fileURL = null
        console.log "result2:", result

      newStatus = null
      newCardTitle = null
      newLastPage = null
      newTransactionId = null
      if result?.receipts
        for applicationReceipt in result.receipts
          #States that run a seperate app for each animal return an array of receipts.
          if applicationReceipt instanceof Array
            for seperateApp in applicationReceipt
              newStatus = seperateApp.status if seperateApp.status
              newCardTitle = seperateApp.cardTitle if seperateApp.cardTitle
              newLastPage = seperateApp.lastPage if seperateApp.lastPage
              newTransactionId = seperateApp.transactionId if seperateApp.transactionId

          newStatus = applicationReceipt.status if applicationReceipt.status
          newCardTitle = applicationReceipt.cardTitle if applicationReceipt.cardTitle
          newLastPage = applicationReceipt.lastPage if applicationReceipt.lastPage
          newTransactionId = applicationReceipt.transactionId if applicationReceipt.transactionId
        if newStatus
          for hunt in application.package.hunts
            for appHunt in application.hunts
              if hunt.huntId is appHunt._id
                appHunt.status = newStatus
                appHunt.cardTitle = newCardTitle if newCardTitle
                appHunt.transactionId = newTransactionId if newTransactionId
        $scope.redraw()

      if newLastPage
        application.lastPageSrc = newLastPage

      if err
        if err.error
          application.errors = err.error
        else if err is 'stop'
          application.errors =  "Stopped by administrator"
        else
          application.errors =  "An error occurred while running the application"

        for hunt in application.package.hunts
          for appHunt in application.hunts
            if hunt.huntId is appHunt._id
              appHunt.status = 'error'


        $scope.redraw()
        return

      return unless result?.status is 'OK'

      if result.fileURL
        for hunt in application.package.hunts
          for appHunt in application.hunts
            if hunt.huntId is appHunt._id

              if result.fileURL?.length
                appHunt.receipt = result.fileURL
                application.hasReceipt = true

              if result.licenseUrls?.length
                appHunt.licenses ?= []
                appHunt.licenses = appHunt.licenses.concat result.licenseUrls if result.licenseUrls
                application.hasReceipt = true

      else if result.receipts
        if (stateId is azStateId or stateId is idStateId) and result.receipts instanceof Array and result.receipts?.length
          tReceipts = result.receipts[0]
          for receipt in tReceipts
            for user in $scope.allApplications
              if receipt.userId is user._id
                user.receipts ?= []
                user.receipts.push receipt
                user.hasReceipt = true
                #if receipt.license
                #  appHunt.licenseUrls ?= []
                #  appHunt.license = appHunt.licenseUrls.concat receipt.license
                break

        for receipt in result.receipts
          for user in $scope.allApplications
            if receipt.userId is user._id
              user.receipts ?= []
              user.receipts.push receipt
              user.hasReceipt = true
              break

      $scope.redraw()

  $scope.reviewPage = (application) ->
    (pageSrc, resumeCb) ->
      application.reviewContent = {pageSrc, resumeCb}
      console.log "Ready for review:", application.reviewContent
      $scope.redraw()


  $scope.prepPrompt = (application) ->
    (prompt, resumeCb) ->
      application.promptContent = {prompt, resumeCb}
      $scope.redraw()

  $scope.viewErrors = ($event, application) ->
    $event.preventDefault()
    alert application.errors

  $scope.review = ($event, application) ->
    $event.preventDefault()
    console.log "show results:", application

    modal = $modal.open
      templateUrl: 'templates/partials/review_step.html'
      controller: 'ReviewStep'
      resolve: {
        pageSrc: -> return application.reviewContent.pageSrc
        resumeCb: -> return application.reviewContent.resumeCb
      }
      scope: $scope

    modal.result.then ->
      application.reviewContent = null
      $scope.redraw()
    , ->
      application.reviewContent = null
      $scope.redraw()

  $scope.showReview = ($event, application) ->
    $event.preventDefault()
    console.log "show results:", application

    modal = $modal.open
      templateUrl: 'templates/partials/review_step.html'
      controller: 'ReviewStep'
      resolve: {
        pageSrc: -> return application.review_html
        resumeCb: -> return () -> console.log "review done"
      }
      scope: $scope

    modal.result.then ->
      application.reviewContent = null
      $scope.redraw()
    , ->
      application.reviewContent = null
      $scope.redraw()

  $scope.prompt = ($event, application) ->
    $event.preventDefault()

    modal = $modal.open
      templateUrl: 'templates/partials/prompt.html'
      controller: 'Prompt'
      resolve: {
        prompt: -> return application.promptContent.prompt
        resumeCb: -> return application.promptContent.resumeCb
      }
      scope: $scope

    modal.result.then ->
      application.promptContent = null
    , ->
      application.promptContent = null

  $scope.viewReceipts = ($event, application) ->
    $event.preventDefault()
    $modal.open
      templateUrl: 'templates/partials/view_receipts.html'
      controller: 'ViewReceipts'
      resolve: application: -> return application
      scope: $scope

  $scope.captcha = ($event, application) ->
    $event.preventDefault() if $event
    console.log "captcha application:", application
    if !application.captcha?.resumeCb
      application.captcha = {
        resumeCb: ""
      }
    application.captcha.resumeCb = (err) ->
      console.log "CALLBACK FROM CAPTCHA MODAL!", err

    modal = $modal.open
      templateUrl: 'templates/partials/captcha_step.html'
      controller: 'CaptchaStep'
      resolve: {
        application: -> return application
        resumeCb: -> return application.captcha.resumeCb
        pageSrc: -> return "none"
      }
      scope: $scope

    modal.result.then ->
      console.log "Return successful from CaptchaStep Modal"
      application.xxxxx = null
    , (err) ->
      console.log "Return err from CaptchaStep Modal", err
      application.xxxxx = null

  $scope.showPages = ->
    return $scope.menu[$scope.search.filterKey] > 1 and not $scope.drawingApplications

  $scope.showGroup = (application, hunt) ->
    application.group and hunt.groupable and not hunt.choices?.group_id

  $scope.showHunt = (application, hunt) ->
    return true unless hunt.groupable
    return true if application.group or not application.inGroup
    false

  $scope.showNewUser = (application) ->
    return false unless application?.hunts?.length

    stateId = application.hunts[0].stateId
    if stateId is "52aaa4cbe4e055bf33db649e" or stateId is "52aaa4cae4e055bf33db649a" or stateId is "52aaa4cbe4e055bf33db649d" or stateId is "52aaa4cbe4e055bf33db649c" or stateId is "52aaa4cbe4e055bf33db64a0" or stateId is "52aaa4cbe4e055bf33db64a2" or stateId is "52aaa4cbe4e055bf33db649b" or stateId is "547fee39ac604956f8b14370" or stateId is "548a11fb94a663719435738e"
      return false
    else
      return true

  $scope.showPurchaseLicenseOnly = (application) ->
    return false

    stateId = application.hunts[0].stateId
    if stateId is "52aaa4cbe4e055bf33db649b"
      return true
    else
      return false

  #Allows us to disable the purchase button and only allow them to hit save until we are ready with the applications for that season.
  $scope.showPurchase = (application) ->
    return false unless application?.hunts?.length

    stateId = application.hunts[0].stateId
    if stateId is "52aaa4cbe4e055bf33db64a0" or stateId is "52aaa4cbe4e055bf33db649f" or stateId is "52aaa4cae4e055bf33db649a"
      return true
    else
      return false

  $scope.showLicense = (application) ->
    return false unless application?.hunts?.length

    stateId = application.hunts[0].stateId
    if stateId is "547fee39ac604956f8b14370" or stateId is "52aaa4cbe4e055bf33db649b"
      return true
    else
      return false


  $scope.huntFilter = (options, search) -> options.filter (item) -> ~item.name.search search

  $scope.init.call(@)
])
