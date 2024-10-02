_ = require "underscore"
request = require "request"

module.exports = (logger) ->

  Home = {

    index: (req, res) ->
      logger.info "render home/index"
      res.render('home/index', {title: "home", language: req.language})

    ping: (stream, cb) ->
      cb null, 'pong'

  }

  _.bindAll.apply _, [Home].concat(_.functions(Home))
  return Home
