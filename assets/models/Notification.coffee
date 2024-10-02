APP = window.APP
APP.Models.factory('Notification', ['$resource', ($resource) ->
  Model = $resource(
    APIURL + '/notifications',
    {},
    {
      markAllRead: { method: 'GET', url: APIURL + '/notifications/allread' }
      read: { method: 'GET', url: APIURL + '/notifications' }
    }
  )

  return Model;
])
