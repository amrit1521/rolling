APP = window.APP
APP.Filters.filter('tl', ->
  (input) ->
    return unless input
    key = input.toLowerCase()
    return APP.language[key] if APP.language[key]
    if not APP.loadingLanguage and APP.locale isnt "en_US"
      console.log "missing translation:", key
    return input
)
