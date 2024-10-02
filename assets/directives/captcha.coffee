APP = window.APP
APP.Directives.directive('captcha', ['State', 'Storage', (State, Storage) ->
  {
    restrict: 'E'
    templateUrl: 'templates/partials/captcha.html'
    replace: true

    link: ($scope, element, attrs) ->

      $scope.init = ->
        $scope.getCaptcha()

      # _.extend data, {captcha: _.pick($scope.montana.captcha, 'JSESSIONID', 'text')} if typeof $scope.montana?.captcha is 'object'


      $scope.getCaptcha = ->
        $scope.user ?= {}

        captcha = Storage.get 'captcha'

        if captcha
          $scope.user.captcha = captcha
        else
          captcha = State.montanaCaptcha ->
            captcha = _.pick captcha, 'image', 'JSESSIONID'
            captcha.image = 'data:image/jpg;base64,' + captcha.image
            Storage.set 'captcha', captcha
            $scope.user.captcha = captcha
            console.log "captcha:", captcha

          , (res) ->
            console.log "captcha err:", res

      $scope.resetCaptcha = ($event) ->
        $event.preventDefault()
        Storage.remove('captcha')
        $scope.getCaptcha()


      $scope.init()
  }
])
