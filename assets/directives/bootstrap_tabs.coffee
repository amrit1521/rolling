APP = window.APP
APP.Directives.directive('toggle2', ->
  link: (scope, element, attrs) ->
    console.log "element:", element
    element.click (e) ->
      e.preventDefault()
      state = {type: 'tab', hash: element.attr('href')}
      history.pushState(state, "", element.attr('href'));
      $(element).tab "show"
)
