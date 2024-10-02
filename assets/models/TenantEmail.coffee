APP = window.APP
APP.Models.factory('TenantEmail', ['$resource', ($resource) ->
  TenantEmail = $resource(
    APIURL + '/admin/emails',
    {},
    {
      adminByType: { method: 'GET',    url: APIURL + '/admin/emails/type/:type' }
      adminDelete: { method: 'DELETE', url: APIURL + '/admin/emails/:id' }
      adminIndex:  { method: 'GET',    url: APIURL + '/admin/emails/index', isArray: true }
      adminRead:   { method: 'GET',    url: APIURL + '/admin/emails/:id' }
      adminSave:   { method: 'POST',   url: APIURL + '/admin/emails' }
      adminSend:   { method: 'GET',    url: APIURL + '/admin/emails/send/:id' }
      adminUpdate: { method: 'PUT',    url: APIURL + '/admin/emails' }
      adminSendTest: { method: 'POST',    url: APIURL + '/admin/emails/sendTest' }
    }
  )

  return TenantEmail;
])
