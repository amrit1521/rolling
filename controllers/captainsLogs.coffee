_ = require "underscore"

module.exports = (logger) ->

  CaptainsLogs = {
    log: (req, res) ->
      type = if req.body?.type in ['debug', 'error', 'handled', 'info', 'log', 'warning'] then req.body.type else 'info'
      logger[type] "Captains Log: ", req.body.value
      res.status(200).end 'logged'
  }

  _.bindAll.apply _, [CaptainsLogs].concat(_.functions(CaptainsLogs))
  return CaptainsLogs
