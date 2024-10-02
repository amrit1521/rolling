APP = window.APP
APP.Models.factory('View', ['$resource', ($resource) ->
  View = $resource(
    APIURL + '/view',
    {},
    {
      save:       { method: 'POST',   url: APIURL + '/view' }
      find:       { method: 'GET',    url: APIURL + '/view/find', isArray: true }
    }
  )

  return View;
])
