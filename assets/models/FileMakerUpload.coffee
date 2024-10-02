APP = window.APP
APP.Models.factory('FileMakerUpload', ['$resource', ($resource) ->

  FileMakerUpload = $resource(
    APIURL + '/filemaker',
    {},
    {
      upload: { method: 'POST', url: APIURL + '/filemaker/upload' }
    }
  )

  return FileMakerUpload
])
