APP = window.APP
APP.Models.factory('Point', ['$resource', ($resource) ->
  Point = $resource(
    APIURL + '/points',
    {},
    {
      all: { method: 'GET', url: APIURL + '/points/all/:userId' }
      update: { method: 'PUT' }
      index: { method: 'GET' }
      getMontanaPoints: { method: 'POST', url: APIURL + '/points/montana' }
      byState: { method: 'GET', url: APIURL + '/points/:userId/state/:stateId/:cid/:refresh', isArray: true }
    }
  )

  return Point;
])
