APP = window.APP
APP.Controllers.controller('UserNotifications', ['$scope', '$location', 'Notification', 'PushNotifications', 'Storage', ($scope, $location, Notification, PushNotifications, Storage) ->

  $scope.init = ->
    PushNotifications.setBadgeNumber 0
    $scope.loadNotifications -> Notification.markAllRead(-> $scope.setUnread(0))

    $scope.$on 'app::resume', ->
      $scope.loadNotifications ->
        Notification.markAllRead(-> $scope.setUnread(0))

  $scope.showButtons = (notification, show) ->
    return
    notification.showButtons = show
    $scope.redraw()

  $scope.init.call(@)
])
