APP = window.APP
APP.Controllers.controller('AdminState', ['$scope', '$routeParams', '$location', 'State', ($scope, $routeParams, $location, State) ->
  $scope.init = ->

    if $routeParams.id
      state = State.adminRead $routeParams, ->
        $scope.state = _.omit state, '__v', '$promise', '$resolved'

  $scope.submit = (state) ->

    done = ->
      alert 'State saved'
      $location.path '/admin/states'
      $scope.redraw()

    if state._id
      State.adminUpdate state, done
    else
      State.create state, done

  $scope.initState = ($event, state) ->
    $event.preventDefault()

    State.init {id: state._id}, ->
      alert 'State initialized'

  $scope.init.call(@)
])
