APP = window.APP
APP.Controllers.controller(
  'Main',
  ['$rootScope', '$scope', '$http', '$location', 'Notification', 'PushNotifications', 'Storage', 'Tenant', 'User',
    ($rootScope, $scope, $http, $location, Notification, PushNotifications, Storage, Tenant, User) ->

      $scope.device = null

      ###
      # Controller properties
      ###
      $scope.footerHidden = false
      $scope.isPhonegap = isPhonegap
      $scope.languages = APP.languages
      $scope.mainNav = "partials/navs/public.html"
      $scope.pageTitle = 'main'
      $scope.public = ["/", "/register"]
      $scope.shortMenus = false
      $scope.notifications = {
        messages: []
        unread: 0
      }

      ###
      # Controller methods
      ###

      $scope.init = ->

        if $scope.isPhonegap
          $scope.gaCode = 'UA-53664344-1' # Mobile analytics code
        # else
        #   $scope.gaCode = 'UA-53664344-2' # Web analytics code

        $rootScope.search ?= {
          application: ''
          filterKey: null
          page: 1
          text: ''
          type: 'name'
        }

        if window.tenant
          $scope.tenant = window.tenant
          $scope.redraw()
        else
          tenant = Tenant.get -> $scope.tenant = tenant
        tenant = Tenant.get ->
          $scope.tenant = tenant
        $scope.shortMenus = ($scope.tenant.name == 'HuntinTool.com' || $scope.tenant.name == 'The Draw');

        $scope.prepDevice()

        if ~['', '/'].indexOf($location.$$path) and Storage.get('user')
          $location.path '/dashboard'

        user = Storage.get 'user'
        $scope.navUsers = []

        $rootScope.$on 'change::user', $scope.setUser
        $rootScope.$on 'remove::user', $scope.setUser

        $rootScope.$on 'change::adminuser', $scope.setAdmin
        $rootScope.$on 'remove::adminuser', $scope.setAdmin

        $rootScope.$on 'change::token', $scope.setToken
        $rootScope.$on 'remove::token', $scope.setToken

        PushNotifications.on 'error', (event) ->
           event.type = 'error'
           $scope.onNotification event

        PushNotifications.on 'message', $scope.onNotification
        PushNotifications.on 'badge', $scope.onBadge
        PushNotifications.on 'sound', $scope.onSound
        PushNotifications.on 'success', (data) -> console.log "PushNotifications.success:", data
        PushNotifications.on 'token', $scope.onToken

        if ga and $scope.gaCode
          $rootScope.$on 'analytics::setup', ->
            $scope.sendReferrer()

        $scope.loadLocale()
        $scope.setAdmin(null, Storage.get('adminUser') )
        $rootScope.$broadcast 'change::user', user
        $rootScope.$broadcast 'change::token', Storage.get('token') if Storage.get('token')

        $scope.loadNotifications()

        ## Below here always needs to be last in init since we change paths here.
        $scope.setupAnalytics() if $scope.gaCode
        if $scope.isPhonegap and $location.path() in ["", "/"]
          if user
            $scope.setAdmin(null, Storage.get('adminUser') )
            $scope.setUser null, user

          $location.path '/dashboard'

      $scope.loadNotifications = (cb = ->) ->
        return unless $scope.user
        $scope.notifications = Storage.get 'notifications'

        Notification.read(
          (res) ->
            $scope.notifications = res.notifications
            Storage.set 'notifications', $scope.notifications

            $scope.redraw()
            cb()
          (res) ->
            cb()
        )

        $scope.redraw()

      $scope.onNotification = (event) ->
#        console.log 'onNotification:', event
        $scope.loadNotifications()

      $scope.onSound = (event) ->
        media = new Media("sounds/#{event.platform}/" + event.data)
        media.play()

      $scope.onToken = (event) ->

        newDevice = {token: event.data, platform: event.platform, deviceId: md5($scope.device.uuid)}
        console.log "newDevice: {token: #{event.data}, platform: #{event.platform}}"

        saveDeviceToken = ((data) ->
          ->
            # We only need to run this once
            $rootScope.$off 'change::token', saveDeviceToken
            User.registerDevice(data)
        )(newDevice)

        userToken = Storage.get 'token'
        if not userToken
          $rootScope.$on 'change::token', saveDeviceToken
          return

        saveDeviceToken()

      $scope.changeLocale = (locale) ->
        APP.locale = locale
        Storage.set("locale", APP.locale)
        if Storage.get("language." + APP.locale)
          APP.language = Storage.get("language." + APP.locale)

        APP.loadingLanguage = true
        jQuery.ajax({
          url: "/i18n/" + locale
          type: "GET"
          dataType: "JSON"
          success: (result) ->
            $scope.$apply ->
              APP.loadingLanguage = false
              APP.language = result
              Storage.set("language." + APP.locale, APP.language)
        })

      $scope.formatDOB = (dob) ->
        date = moment(dob, 'YYYY-MM-DD')
        return 'MM/DD/YYYY' unless date.isValid()
        date.format('MM/DD/YYYY')

      $scope.isPhone = -> $scope.isPhonegap

      $scope.isPhoneAuthed = -> $scope.isPhonegap and $scope.user

      $scope.isPhoneNotAuthed = -> $scope.isPhonegap and not $scope.user

      $scope.sendReferrer = ->
        referrer = Storage.get 'referrer'
        return unless referrer
        ga 'set', 'campaignName', referrer.campaign
        ga 'set', 'campaignSource', referrer.source
        ga 'set', 'campaignMedium', referrer.medium
        ga 'send', 'event', 'referral', 'install', referrer.campaign
        Storage.remove 'referrer'

      $scope.loadLocale = ->
        baseLang = jQuery('html').attr('lang')

        switch baseLang
          when 'es'
            language = 'es_US'
          else
            language = 'en_US'

        if Storage.get("locale")
          $scope.changeLocale(Storage.get("locale"))
        else
          $scope.changeLocale(language)

      $scope.logout = ->
        Storage.remove('user')
        Storage.remove('adminUser')
        Storage.remove('prevUser')
        Storage.remove('navUsers')
        Storage.remove('token')
        Storage.remove('topToken')
        Storage.clear()
        return $location.path '/dashboard' if $scope.isPhonegap
        $location.path '/'

      $scope.gotoRRADS = ($event, currentUser) ->
        $event.preventDefault() if $event
        currentUser = Storage.get 'user' unless currentUser
        if $scope.navUsers?.length
          topUser = $scope.navUsers[0]
        else
          topUser = $scope.user

        User.user_upsert_rads {_id: currentUser._id, tenantId: currentUser.tenantId}, (results) ->
          try
            updatedUser = JSON.parse(results.results).user
          catch ex
            console.log "Error: failed to update RRADS with this user. ", ex
            console.log "RRAD Server results: ", results
            return
          if updatedUser?.client_id
            clientId = updatedUser.client_id
          else
            clientId = currentUser.clientId
          User.getStamp {clientId: clientId, originalClientId: topUser.clientId},
            (results) ->
              url = "#!"
              tUser = Storage.get 'user'
              if tUser?.tenantId?.toString() is "5684a2fc68e9aa863e7bf182"
                url = "https://rads.rollingbonesoutfitters.com/dashboard"
              #else if tUser?.tenantId?.toString() is "5bd75eec2ee0370c43bc3ec7"
                #url = "https://rolling-bones-rls-staging.herokuapp.com/dashboard"
                #url = "https://verdadcameron.ngrok.io/dashboard"
              else if $scope.tenant?.rrads_api_base_url
                url = "https://#{$scope.tenant.rrads_api_base_url}/dashboard"
              queryStr = "stamp=#{encodeURIComponent(results.eStamp)}"
              console.log "Switching to url location: ", url
              console.log "$scope tenant: ", $scope.tenant
              #window.open("#{url}?#{queryStr}", '_blank')
              #window.open("#{url}?#{queryStr}")
              window.location = "#{url}?#{queryStr}"
        , (err) ->
          console.log "Error: refresh RRADS user failed with error: ", err

      $scope.masquerade = (userId, cb = ->) ->
        currentUser = Storage.get 'user'
        #return unless currentUser.isAdmin
        $scope.adminUser = currentUser if currentUser.isAdmin
        Storage.set 'adminUser', $scope.adminUser if currentUser.isAdmin

        $scope.prevUser = currentUser
        Storage.set 'prevUser', $scope.prevUser

        $scope.navUsers = Storage.get 'navUsers'
        $scope.navUsers = [] unless $scope.navUsers
        $scope.navUsers.push currentUser
        Storage.set 'navUsers', $scope.navUsers

        $scope.navTokens = Storage.get 'navTokens'
        $scope.navTokens = [] unless $scope.navTokens
        $scope.navTokens.push Storage.get 'token'
        Storage.set 'navTokens', $scope.navTokens

        params = {id: userId}
        params.topToken = Storage.get('topToken').token if Storage.get('topToken')
        user = User.getMQ params,
          ->
            $rootScope.activeState = null
            user.masquerading = true
            Storage.set 'user', user
            cb()

          , (err) ->
            cb err

      $scope.hideFooter = (hidden) ->
        $scope.footerHidden = hidden

      $scope.hideExtraMenus = -> $scope.shortMenus

      $scope.waitForDeviceReady = ->
        jQuery(document).ready ->
          document.addEventListener("deviceready", $scope.prepDevice, false)
          # document.addEventListener("pause", yourCallbackFunction, false)
          document.addEventListener(
            "resume"
            ->
              $scope.$broadcast 'app::resume'
            false
          )


      $scope.prepDevice = ->
        try
          return $scope.waitForDeviceReady() unless device
        catch error
          return $scope.waitForDeviceReady()

        $scope.device = device
        $scope.deviceVersion = $scope.device.platform.toLowerCase() + parseInt($scope.device.version, 10)
        $scope.$emit 'deviceready', device
        $scope.redraw()

        PushNotifications.ready {device: $scope.device, senderID: window.senderID}

        try # Prevent errors if gmtReceiver doesn't exist
          if gmtReceiver
            gmtReceiver.onReceive "referrer", ((value) ->
              params = {}

              decodeURIComponent(value).split("&").map (item) ->
                parts = item.split "="
                params[parts[0].replace('utm_', '')] = parts[1]

              Storage.set 'referrer', params
              $scope.sendReferrer()
              return
            ), (error) ->
              # alert "Error! " + JSON.stringify(error)
              return

      $scope.redraw = -> $scope.$apply() unless $scope.$$phase

      $scope.setAdmin = (event, user) ->
        return delete $scope.adminUser unless user
        $scope.adminUser = user

      $scope.setLocation = (url) ->
        $location.path(url)

      $scope.setUnread = (unread) ->
        $scope.notifications.unread = unread
        Storage.set 'notifications', $scope.notifications

      $scope.setToken = (e, token) ->
        return $http.defaults.headers.common['x-ht-auth'] = token.token if token
        delete $http.defaults.headers.common['x-ht-auth']

      $scope.setupAnalytics = ->
        return if not $scope.gaCode or $scope.analytics

        if $scope.user?._id
          ga 'create', $scope.gaCode, {
            'storage': 'none'
            'userId': $scope.user._id
          }
        else
          ga 'create', $scope.gaCode, {
            'storage': 'none'
          }

        $scope.analytics = ga

        if not $scope.isPhonegap
          $scope.$on '$routeChangeSuccess', ->
            ga 'send', 'pageview', {
              'page': $location.absUrl()
            }

        $rootScope.$broadcast('analytics::setup')
        return

      $scope.setUser = (event, user) ->
        if user
          $scope.user = user
          $scope.setupAnalytics() if $scope.gaCode
          return
        delete $scope.user

      $scope.showHeaderButtons = (scope) ->
        $('body').addClass('show-header')
        scope.$on "$destroy", -> $('body').removeClass('show-header')

      $scope.switchBack = ->
        navUsers = Storage.get 'navUsers'
        user = navUsers.pop()
        $scope.navUsers = navUsers
        Storage.set 'navUsers', $scope.navUsers

        navTokens = Storage.get 'navTokens'
        token = navTokens.pop()
        $scope.navTokens = navTokens
        Storage.set 'navTokens', $scope.navTokens
        $scope.setToken(null, token) if token

        $scope.prevUser = navUsers[navUsers.length - 1]
        Storage.set 'prevUser', $scope.prevUser
        Storage.set 'user', user
        Storage.remove 'adminUser' if user.isAdmin

        $rootScope.activeState = null
        user.masquerading = true

      $scope.switchBackAdmin = ->
        $scope.navUsers = []
        Storage.set 'navUsers', $scope.navUsers

        $scope.navTokens = []
        Storage.set 'navTokens', $scope.navTokens

        $scope.prevUser = null
        Storage.set 'prevUser', $scope.prevUser

        user = Storage.get 'adminUser'
        Storage.set 'user', user
        Storage.remove 'adminUser'
        $rootScope.activeState = null
        user.masquerading = false

        Storage.remove 'adminUser' if user.isAdmin
        $rootScope.activeState = null

        topToken = Storage.get('topToken') if Storage.get('topToken')
        $scope.setToken(null, topToken) if topToken

      $scope.adminFullEdit = () ->
        if $scope.user?.isAdmin and $scope.user?.userType is "super_admin"
          return true
        else if $scope.adminUser?.isAdmin and $scope.adminUser?.userType is "super_admin"
          return true
        else
          return false

      $scope.adminTenantEdit = () ->
        if $scope.user?.isAdmin and $scope.user?.userType is "super_admin"
          return true
        else if $scope.adminUser?.isAdmin and $scope.adminUser?.userType is "super_admin"
          return true
        else if $scope.adminUser?.isAdmin and $scope.adminUser?.userType is "tenant_admin"
          return true
        else
          return false

      $scope.isRBO = () ->
        if window?.tenant?._id is "5684a2fc68e9aa863e7bf182" or window?.tenant?._id is "5bd75eec2ee0370c43bc3ec7" or window?.tenant?._id is "53a28a303f1e0cc459000127"
          return true
        else
          return false

      $scope.adminEdit = (userType) ->
        if $scope.user?.isAdmin #and $scope.user?.userType is userType
          return true
        else if $scope.adminUser?.isAdmin #and $scope.adminUser?.userType is userType
          return true
        else
          return false

      $scope.successHandler = (result) ->


      $scope.tokenHandler = (result) ->

      # Initialize the controller
      $scope.init.call(@)
  ]
)
