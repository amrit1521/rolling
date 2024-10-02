winston = require 'winston'

# CustomTransport implementation
class CustomTransport extends require('winston-transport')
  constructor: (opts) ->
    super(opts)
    @host = opts.host or 'localhost'
    @node_name = opts.node_name or 'gotmytag'
    @port = opts.port or 28777

  log: (info, callback) ->
    console.log "Logging to #{@host}:#{@port} - #{info.level}: #{info.message}"
    callback()

module.exports = CustomTransport
