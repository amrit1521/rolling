APP = window.APP
APP.Filters.filter('filesize', ->
  (input) ->
    return filesize(input, true)
)
