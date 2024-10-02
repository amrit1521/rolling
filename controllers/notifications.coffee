_ = require "underscore"
async = require "async"
moment = require "moment"
util = require "util"

module.exports = (
  Notification
) ->

  class Module

    markAllRead: (req, res) ->
      Notification.markAllRead req.user._id, (err) ->
        return res.json {error: err}, 500 if err
        res.json {status: 'OK'}, 200

    read: (req, res) ->

      async.parallel [

        # Get notifications
        (done) ->
          Notification.byUserId req.user._id, done

        # Get count unread
        (done) ->
          Notification.unreadCount req.user._id, done

      ], (err, [messages, unread]) ->
        return res.json {error: err}, 500 if err
        #console.log "notifications:", {messages, unread}
        res.json {notifications: {messages, unread}}, 200

  return new Module()
