APP = window.APP
APP.Filters.filter('nospace', ->
  (input) ->
    return unless input
    return input.replace(/\s/g, '')
)
