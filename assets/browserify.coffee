dnode         = require 'dnode'
reconnectShoe = require 'reconnect-shoe'
shoe          = require 'shoe'

APP = window.APP
APP.Services.factory('dnode', ->
  return dnode
)

APP.Services.factory('reconnectShoe', ->
  return reconnectShoe
)

APP.Services.factory('shoe', ->
  return shoe
)
