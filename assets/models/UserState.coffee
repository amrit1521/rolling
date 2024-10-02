APP = window.APP
APP.Models.factory('UserState', ['$resource', ($resource) ->
  UserState = $resource(
    APIURL + '/user_states',
    {},
    {
      clear: { method: 'DELETE', url: "/user_states/:userId/:stateId" }
    }
  )

  return UserState
])
