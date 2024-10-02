APP = window.APP
APP.Services.factory('Stream', ['$rootScope', 'dnode', 'reconnectShoe', 'shoe', 'Storage', ($rootScope, dnode, reconnectShoe, shoe, Storage) ->
  stream = null

  class Stream

    maxTimeout: 4000

    constructor: () ->
      @monitoring = false
      Emitter(@)
      @isConnected = false

      @token = Storage.get('token').token

      $rootScope.$on 'change::token', @setToken
      $rootScope.$on 'remove::token', @setToken


    createKey: (method) ->
      return md5(method.toString())

    connect: ->
      reconnectShoe((stream) =>
        d = dnode()

        ##############
        ##  EVENTS  ##
        ##############

        # Event - Data
        # d.on "data", => @log 'data', arguments

        # Event - End
        d.on "end", =>
          @log 'end', arguments
          @disconnected()

        # Event - Error
        # d.on "error", => @log 'error', arguments

        # Event - Fail
        # d.on "fail", => @log 'fail', arguments

        # Event - Local
        # d.on "local", => @log 'local', arguments

        # Event - Ready
        # d.on "ready", => @log 'ready', arguments

        # Event - Remote
        d.on "remote", (connection) =>
          @log 'remote', arguments
          _.extend @, connection
          @monitorConnection()

          @auth @token, (err) ->
            if err
              @disconnected()
              return console.log "remote connect err:", err

        d.pipe(stream).pipe d
      ).connect "/dnode"

    disconnect: ->
      clearInterval @monitoring if @monitoring
      @isConnected = null
      @monitoring = null

    log: (event, data) -> console.log "Stream::event:", event

    setToken: (e, token) ->
      return @token = token.token if token
      @token = null

    disconnected: ->
      return unless @isConnected
      @isConnected = false
      @emit 'disconnected'

    connected: ->
      return if @isConnected

      @isConnected = true
      @emit 'connected'

    triggerDisconnect: ->
      setTimeout =>
        @disconnected()
      , @maxTimeout

    monitorConnection: ->
      @disconnect() if @monitoring
      @monitoring = setInterval =>
        disconnectTrigger = @triggerDisconnect()

        @hearbeat =>
          clearTimeout disconnectTrigger
          @connected()

      , @maxTimeout

  stream = new Stream() unless stream

  return stream
])


