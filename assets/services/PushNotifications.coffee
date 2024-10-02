APP = window.APP
APP.Services.factory('PushNotifications', [  ->

  # handle APNS notifications for iOS
  window.onNotificationAPN = (e) ->
#    console.log "onNotificationAPN.e:", e

    if e.n_message
      notification = {
        userId: e.n_userId
        message: e.n_message
        created: e.n_created
        read: e.n_read
      }

      module.trigger 'message', {platform: 'ios', data: notification, e}

    module.trigger 'sound', {platform: 'ios', data: e.sound, e} if e.sound
    if e.badge
      module.setBadgeNumber e.badge
      module.trigger 'badge', {platform: 'ios', data: e.badge, e}
    else if e.unread
      module.setBadgeNumber e.unread
      module.trigger 'badge', {platform: 'ios', data: e.unread, e}

    return

  # handle GCM notifications for Android
  window.onNotification = (e) ->
#    console.log "onNotification.e:", e
#    console.log 'onNotification'
    switch e.event
      when "registered"
        module.trigger 'token', {platform: 'android', data: e.regid, e} if e.regid.length > 0

      when "message"
        module.trigger 'message', {platform: 'android', data: e.payload.message, e} if e.payload?.message
        module.trigger 'sound', {platform: 'android', data: e.soundname or e.payload.sound, e} if e.soundname or e.payload.sound
        module.trigger 'badge', {platform: 'android', data: e.payload.unread, e} if e.payload?.unread

      when "error"
        module.trigger 'error', {platform: 'android', data: e.msg, e}
      else
        module.trigger 'error', {platform: 'android', data: 'Unknown event', e}

  class Module

    callbacks: {}
    platform: null
    pushNotification: undefined

    ready: (opts) ->
      try
        @pushNotification = window.plugins.pushNotification
        if opts.device.platform.toLowerCase() is "android"
          @platform = 'android'
          @pushNotification.register @successHandler, @errorHandler, # required!
            senderID: opts.senderID
            ecb: "onNotification"

        else
          @platform = 'ios'
          @pushNotification.register @tokenHandler, @errorHandler, # required!
            badge: "true"
            sound: "true"
            alert: "true"
            ecb: "onNotificationAPN"

      catch err
        alert "There was an error on this page.\n\n Error description: #{err.message}\n\n"

      return

    errorHandler: (error) =>
      @trigger 'error', {platform: @platform, data: error}
      return

    on: (event, cb) ->
      @callbacks[event] ?= []
      @callbacks[event].push cb

    setBadgeNumber: (number) ->
      return unless @pushNotification?.setApplicationIconBadgeNumber
#      console.log 'setBadgeNumber:', number
      @pushNotification.setApplicationIconBadgeNumber(module.successHandler, number)

    successHandler: (result) =>
#      console.log 'successHandler'
      @trigger 'success', {platform: @platform, data: result}

      return

    tokenHandler: (result) =>
#      console.log 'tokenHandler: ' + result
      @trigger 'token', {platform: @platform, data: result}
      return

    trigger: ->
      args = [].slice.call(arguments)
      event = args.shift()
#      console.log 'trigger:', event
#      console.log 'trigger args:', args
      if @callbacks?[event] instanceof Array
        for cb in @callbacks[event]
          cb.apply @, args

      return

  module = new Module()
  return module
])
