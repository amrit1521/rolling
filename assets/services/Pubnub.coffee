APP = window.APP
APP.Services.service('Pubnub', [->
  channel = null
  pubnub = null

  init: ->
    console.log "pubnub init:", PUBNUB_SUBSCRIBE_KEY
    return if pubnub
    pubnub = PUBNUB.init {
      subscribe_key : PUBNUB_SUBSCRIBE_KEY
      origin        : 'pubsub.pubnub.com'
      ssl           : true
    }

  history: (scope, limit) ->
    @init()

    pubnub.history(
      {
        channel: channel
        limit: limit
      }
      (messages) ->
        # Broadcast messages
        for index, message of messages[0]
          scope.$broadcast('program-all', message)
    )

  subscribe: (scope, channel, historyLimit) ->
    @init()

    pubnub.subscribe {
      channel

      connect: ->
        scope.$broadcast('PUBNUB-connect', {type: 'connect', channel})
        scope.$broadcast('PUBNUB-all', {type: 'connect', channel})

      callback: (message) ->
        scope.$broadcast('PUBNUB-' + message.type, message)
        scope.$broadcast('PUBNUB-all', message)
    }

    # @history(scope, historyLimit)

  unsubscribe: (scope, channel) ->
    pubnub.unsubscribe { channel }
    scope.$broadcast('PUBNUB-unsubscribe', {type: 'unsubscribe', channel})
    scope.$broadcast('PUBNUB-all', {type: 'unsubscribe', channel})
])
