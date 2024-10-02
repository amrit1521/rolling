APP = window.APP
APP.Models.factory('ServiceRequest', ['$resource', ($resource) ->
  ServiceRequest = $resource(
    APIURL + '/servicerequests',
    {},
    {
      adminDelete: { method: 'DELETE', url: APIURL + '/admin/servicerequests/:id' }
      adminIndex:  { method: 'GET',    url: APIURL + '/admin/servicerequests/index', isArray: true }
      adminRead:   { method: 'GET',    url: APIURL + '/admin/servicerequests/:id' }
      adminSave:   { method: 'POST',   url: APIURL + '/admin/servicerequests' }
      adminUpdate: { method: 'PUT',    url: APIURL + '/admin/servicerequests' }
    }
  )

  return ServiceRequest;
])
