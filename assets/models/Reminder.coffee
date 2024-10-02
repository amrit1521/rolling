APP = window.APP
APP.Models.factory('Reminder', ['$resource', ($resource) ->
  Reminder = $resource(
    APIURL + '/reminders'
    {}
    {
      byId: { method: 'GET', url: APIURL + '/admin/reminders/read/:_id' }
      adminIndex: { method: 'GET', url: APIURL + '/admin/reminders/index' }
      byStates: { method: 'POST', url: APIURL + '/reminders/states', isArray: true }
      delete: { method: 'DELETE', url: APIURL + '/admin/reminders/:_id' }
      save: { method: 'POST', url: APIURL + '/admin/reminders/save' }
      test: { method: 'POST', url: APIURL + '/admin/reminders/test' }
    }
  )

  return Reminder
])
