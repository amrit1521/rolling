APP = window.APP
APP.Models.factory('HuntOption', ['$resource', ($resource) ->

  HuntOption = $resource(
    APIURL + '/hunt_options',
    {},
    {
      get: { method: 'GET', url: APIURL + '/hunt_options/:huntId', isArray: true }
    }
  )

  return HuntOption
])
