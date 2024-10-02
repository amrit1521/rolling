APP = window.APP
APP.Models.factory('ClientState', ['$resource', ($resource) ->

  ClientState = $resource(
    APIURL + '/clientstates',
    {},
    {
      get: { method: 'GET', url: APIURL + '/clientstates/:userId/:year' }
      update: { method: 'PUT', isArray: false }
    }
  )

  return ClientState
])
