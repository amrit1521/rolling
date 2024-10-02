_ = require "underscore"
moment = require "moment"

module.exports = (Token, User) ->

  class Auth

    constructor: ->
      # Constructor if needed

    user: (req, res, next) ->
      tokenStr = req.headers['x-ht-auth'] if req.headers['x-ht-auth']
      #tokenStr = "786b68058cbe183d295b9bc8f7be4822859dZd249cb367494c892a79ddd8f74298d4195668eaf890b33c0119ec100984c81a0f58a4492343a17907b8e806e44ec" #Hard code test for prod
      # tokenStr = "92ef6f91c1eb43868fb2570eac32597dc09262ee4fce27d8aa46d02c96d51b50e404f0c4fc662f5073d663f9ed4cf75ad56367b6f1b459e0e2929524ba5da56c" #Hard code for dev
      console.log "Error: User Authenticate called without x-ht-auth token." unless tokenStr
      return next() unless tokenStr

      Token.findOne({ token: tokenStr }).lean().exec()
        .then (token) ->
          console.log "New token generated: ", token

          unless token
            console.log "Error: User Authenticate failed to find user for token: ", tokenStr
            throw new Error('Token not found')

          console.log 'token:', token

          User.findOne({ _id: token.userId }).lean().exec()
            .then (user) ->
              req.user = user
              req.tokenExpires = token.expires
              tokenStr = null
              token = null
              user = null
              next()
              # console.log req.user
            .catch (err) ->
              console.log "This is catch..."
              next(err)

    authenticate: (req, res, next) ->
      return res.json({ error: "Unauthorized" }, 401) unless !!req.user
      next()

    authenticate2: (req, res, next) ->
      now = moment()
      expires = moment(req.tokenExpires)
      diff = now.diff(expires, "seconds")
      return res.json({ error: "Unauthorized" }, 401) unless diff <= 0
      return res.json({ error: "Unauthorized" }, 401) unless !!req.user
      next()

  new Auth()