APP = window.APP
APP.Models.factory('Utah', ['$resource', ($resource) ->
  Utah = $resource(
    APIURL + '/utah',
    {},
    {
      eligibility: { method: 'GET', url: APIURL + '/utah/sportsmans/eligibility', isArray: true }
      sportsmans: { method: 'POST', url: APIURL + '/utah/sportsmans' }
    }
  )

  return Utah;
])
