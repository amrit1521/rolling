APP = window.APP
APP.Services.factory('Users', [ 'Storage', 'User', (Storage, User) ->

  class Users
    primary: ''
    scope: null

    init: (scope) ->
      @scope = scope
      @scope.users = Storage.get 'users'

      if not @scope.users
        @scope.users = []

        @addUser (user) =>
          user.isPrimary = true
          @primary = user.profile._id
          @updateUser user
          return
      else
        @setActive Storage.get 'user'
        for user in @scope.users
          if user.isPrimary
            @primary = user.profile._id
            break

      return

    addUser: (cb = ->) ->
      result = User.defaultUser =>

        if result.user
          result.profile = result.user
          delete result.user

        user = @baseUser result

        @scope.users.push user
        @storeUsers()
        console.log 'createUser setUsers.1'

        @setActive user.profile._id

        cb @scope.users[@scope.users.length - 1]

    baseUser: (data) ->
      profile = {}
      token = ''

      profile = data.profile if data.profile
      token = data.token if data.token

      return {
        points: []
        profile: profile
        reminders: []
        results: []
        token: token
      }

    byId: (id) ->
      for user in @scope.users
        if user.profile._id is id
          return user

    getActive: -> Storage.get('user')

    getActiveUser: -> @byId Storage.get('user')

    length: -> return @scope.users.length

    setActive: (id) ->
      Storage.set 'user', id

      for user in @scope.users
        if id is user.profile._id
          @scope.user = user
          break

      console.log "Users::setActive @scope.user:", @scope.user
      @scope.$emit('change::token', @scope.user.token) if @scope.user?.token

    storeUsers: ->
      Storage.set 'users', @scope.users

    updateProfile: (profile) ->
      for user, key in @scope.users
        if user.profile._id is profile._id

          profile.setupComplete = !!@scope.users[key].profile.setupComplete unless profile.setupComplete
          @scope.users[key].profile = profile
          break

      @storeUsers()

    updatePoints: (id, update) ->
      user = @byId id
      found = false

      update.show = update.active && not update.error
      if update.hunts?.length
        for hunt in update.hunts
          if hunt.point?.count
            update.userHasPoints = true
            break

      for state, key in user.points
        if state._id is update._id
          user.points[key] = update
          found = true
          break

      user.points.push update unless found

      @storeUsers()

      @setActive(user.profile._id) if user.profile._id is @getActive()

    updateReminders: (id, reminders) ->
      user = @byId id
      user.reminders = reminders


    updateUser: (update) ->
      for user, key in @scope.users
        if user.profile._id is update.profile._id
          @scope.users[key] = update
          break

      @storeUsers()

  users = new Users()
  return users
])
