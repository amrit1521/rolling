APP = window.APP
APP.Models.factory('HuntChoice', ['$resource', ($resource) ->

  timeout = 1000 * 60 * 20 # 20 minutes

  HuntChoice = $resource(
    APIURL + '/hunt_choices',
    {},
    {
      get: { method: 'GET', url: APIURL + '/hunt_choices/:userId/:huntId' }
      run: { method: 'POST', url: APIURL + '/hunt_choices/run' }
      batchTest: { method: 'POST', url: APIURL + '/hunt_choices/batch/test', timeout }
      batchRun: { method: 'POST', url: APIURL + '/hunt_choices/batch/run', timeout }
      groupCheck: { method: 'GET', url: APIURL + '/hunt_choices/user/group/:userId/:huntId', isArray: true }
      groupLookup: { method: 'GET', url: APIURL + '/hunt_choices/group/:huntId/:groupId' }
    }
  )

  return HuntChoice
])
