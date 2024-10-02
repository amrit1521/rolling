APP = window.APP
APP.Models.factory('Tenant', ['$resource', ($resource) ->
  Tenant = $resource(
    APIURL + '/tenants',
    {},
    {
      adminDelete: { method: 'DELETE', url: APIURL + '/admin/tenants/:id' }
      adminBilling:  { method: 'POST',    url: APIURL + '/admin/tenants/billing/:id'}
      adminIndex:  { method: 'GET',    url: APIURL + '/admin/tenants/index', isArray: true }
      adminRead:   { method: 'GET',    url: APIURL + '/admin/tenants/:id' }
      adminSave:   { method: 'POST',   url: APIURL + '/admin/tenants' }
      adminUpdate: { method: 'PUT',    url: APIURL + '/admin/tenants' }
      adminPushRRADS: { method: 'POST', url: APIURL + '/admin/tenants/pushrrads' }
    }
  )

  return Tenant;
])
