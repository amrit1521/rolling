APP = window.APP
APP.Controllers.controller('CaptchaStep', ['$scope', '$sce', '$modalInstance', 'pageSrc', 'resumeCb', 'application', ($scope, $sce, $modalInstance, pageSrc, resumeCb, application) ->

  $scope.init = ->
    console.log "DEBUG: init called!!!!", application
    $scope.user = Storage.get "user"
    $scope.application = application
    #$scope.pageUrl = $sce.trustAsResourceUrl("data:text/html;charset=utf-8," + encodeURI(pageSrc))
    $scope.resumeCb = resumeCb
    $scope.imgClicks = []

    console.log "gmtSocket listening on channel: #{$scope.user._id}"
    $scope.gmtSockets = socketCluster.connect({
      secure: false,
      autoReconnect: true,
      autoReconnectOptions: {
        initialDelay: 500,
        maxDelay: 5000,
        multiplier: 1.5,
        randomness: 100,
        rejectUnauthorized: false # Only necessary during debug if using a self-signed certificate
      },
      hostname: '0.0.0.0'
      port: 8000
    })
    gmtSocket = $scope.gmtSockets.subscribe($scope.user._id)
    gmtSocket.on 'subscribeFail', (err) ->
      console.log "gmtSocket subscribe to gmtUpdateClient failed", err
    gmtSocket.watch (message) ->
      $scope.handleSocketMessage(message)


  $scope.handleSocketMessage = (message) ->
    console.log "gmtSocket recieved message", message
    if application._id is message.userId
      application.appPurchaseMsg = message.message
      application.webPartition = message.webPartition
      application.tmpScreen = "data:image/png;base64," + message.file.data
      $scope.redraw()

  $scope.ok = ->
    console.log "DEBUG: init called!!!!", application, $scope.imgClicks
    if $scope.gmtSockets
      message = {
        imgClicks: $scope.imgClicks
        channelId: application.webPartition
      }
      console.log "sending gmtEvent message", message
      this.gmtSockets.emit("gmtEvent", message)

    $scope.resumeCb()
    $modalInstance.dismiss('cancel')

  $scope.cancel = ->
    console.log "DEBUG: init called!!!!", application, $scope.imgClicks
    $scope.resumeCb('stop')
    $modalInstance.dismiss('cancel')

  $scope.imgClick = ($event) ->
    console.log "img click", $event.offsetX, $event.offsetY
    $scope.imgClicks.push({x:$event.offsetX, y:$event.offsetY})


  $scope.init.call(@)
])
