APP = window.APP
APP.Filters.filter('ucfirst', ->
  (input) ->
    return unless input
    input.charAt(0).toUpperCase() + input.substr(1)
)
