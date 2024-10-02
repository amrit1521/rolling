APP = window.APP
APP.Models.factory('Report', ['$resource', ($resource) ->
  Report = $resource(
    APIURL + '/report',
    {},
    {
      adminUsers:  { method: 'GET', url: APIURL + '/admin/report/users', isArray: true }
      adminUsersTree:  { method: 'GET', url: APIURL + '/admin/report/usersTree', isArray: true }
      adminPurchases:  { method: 'POST', url: APIURL + '/admin/report/purchases', isArray: true }
      adminOutfittersPurchases:  { method: 'GET', url: APIURL + '/admin/report/purchases/outfitter/:userId', isArray: true }
      adminTenantPurchases:  { method: 'GET', url: APIURL + '/admin/report/purchases/tenant/:userId', isArray: true }
      repPurchases:  { method: 'POST', url: APIURL + '/rep/report/purchases/rep', isArray: true }
      repCommissions:  { method: 'POST', url: APIURL + '/rep/report/commissions/rep', isArray: true }
      repUsers:  { method: 'POST', url: APIURL + '/rep/report/users/search', isArray: true }
      repUsersDownstream:  { method: 'GET', url: APIURL + '/rep/report/users/downstream/:userId'}
      adminStats:  { method: 'POST', url: APIURL + '/admin/report/stats'}
    }
  )

  return Report;
])
