APP = window.APP
APP.Services.factory('Storage', ['$rootScope', '$cookieStore', 'webStorage', ($rootScope, $cookieStore, webStorage) ->
  state = {}
  store = if webStorage.isSupported then webStorage # else $cookieStore

  if not store.add
    store.add = store.put
    store.clear = ->
      store.remove 'user'
      store.remove 'adminUser'

  return  {
    upperFirst: (input) ->
      input.charAt(0).toUpperCase() + input.slice(1)

    getLocalStorage: (key) ->
      return store.get(key) if store.get(key)
      return null

    setLocalStorage: (key, value) ->
      store.add(key, value)

    get: (key) ->
      # console.log "Storage::get:", arguments
      throw new Error("key is empty") if not key

      if state[key]
        return state[key]
      else if @getLocalStorage(key)
        return state[key] = @getLocalStorage(key)
      else if @['get' + @upperFirst(key)]
        return state[key] = @['get' + @upperFirst(key)]()

      return null

    remove: (key) ->
      state[key] = null
      store.remove(key, true)
      $rootScope.$broadcast('remove::' + key.toLowerCase())

    set: (key, value, silent = false) ->
      state[key] = value
      @setLocalStorage(key, value)
      $rootScope.$broadcast('change::' + key.toLowerCase(), value) unless silent

    clear: ->
      state = {}
      store.clear()
  }
])
