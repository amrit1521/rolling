APP = window.APP
APP.Filters.filter('nicedate', ->
  (input) ->
    return unless input
    if input instanceof Date
      return moment(input).format('MM/DD/YYYY')
    else
      return moment(input, 'YYYY-MM-DD').format('MM/DD/YYYY')
)
