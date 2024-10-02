APP = window.APP
APP.Models.factory('Postal', ['$resource', ($resource) ->
  Postal = $resource(
    APIURL + '/postals',
    {},
    {
      getState: { method: 'GET', url: APIURL + '/postals/state/:mail_postal' }
    }
  )

  return Postal;
])
