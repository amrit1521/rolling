APP = window.APP
APP.Models.factory('HuntCatalog', ['$resource', ($resource) ->
  HuntCatalog = $resource(
    APIURL + '/huntcatalog',
    {},
    {
      adminDelete: { method: 'DELETE', url: APIURL + '/admin/huntcatalog/:id' }
      adminIndex:  { method: 'GET',    url: APIURL + '/admin/huntcatalog/index', isArray: true }
      adminRead:   { method: 'GET',    url: APIURL + '/admin/huntcatalog/:id' }
      adminSave:   { method: 'POST',   url: APIURL + '/admin/huntcatalog' }
      adminUpdate: { method: 'PUT',    url: APIURL + '/admin/huntcatalog' }
      index:       { method: 'GET',    url: APIURL + '/huntcatalog/index', isArray: true }
      read:        { method: 'GET',    url: APIURL + '/huntcatalog/:id' }
      purchase:    { method: 'POST',   url: APIURL + '/huntcatalog/purchase/:id', params: {id: '@id'}}
    }
  )

  return HuntCatalog;
])
