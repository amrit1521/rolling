APP = window.APP
APP.Models.factory('Search', ['$resource', ($resource) ->
  Search = $resource(
    APIURL + '/searches',
    {},
    {
      application: { method: 'GET', url: APIURL + '/searches/application/:application/:range/:status' }
      applicationByUserHuntYear: { method: 'GET', url: APIURL + '/searches/application/latest/:userId/:huntId/:year' }
      find: { method: 'POST', isArray: true }
      card: { method: 'GET', url: APIURL + '/searches/card/:userId/:index' }

    }
  )

  return Search;
])
