APP = window.APP
APP.Models.factory('Hunt', ['$resource', ($resource) ->

  Hunt = $resource(
    APIURL + '/hunts',
    {},
    {
      adminAllApplications: { method: 'GET', url: APIURL + '/admin/hunts/all/applications', isArray: true }
      adminIndex: { method: 'GET', url: APIURL + '/admin/hunts/index/:stateId', isArray: true }
      adminRead: { method: 'GET', url: APIURL + '/admin/hunts/:id' }
      adminCreate: { method: 'POST', url: APIURL + '/admin/hunts' }
      adminUpdate: { method: 'PUT', url: APIURL + '/admin/hunts' }
      available: { method: 'GET', url: APIURL + '/hunts/available/:stateId' }
      byState: { method: 'GET', url: APIURL + '/hunts/by_state/:stateId', isArray: true }
      current: { method: 'GET', url: APIURL + '/hunts/current/:stateId', isArray: true }
      get: { method: 'GET', url: APIURL + '/hunts/:id' }
      options: { method: 'GET', url: APIURL + '/hunts/options/:id', isArray: true }
    }
  )

  return Hunt
])
