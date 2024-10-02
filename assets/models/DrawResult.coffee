APP = window.APP
APP.Models.factory('DrawResult', ['$resource', ($resource) ->

  DrawResult = $resource(
    APIURL + '/drawresults',
    {},
    {
      report: { method: 'GET', url: APIURL + '/admin/drawresults/report/:state', isArray: true }
    }
  )

  return DrawResult
])
