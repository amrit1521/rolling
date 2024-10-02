_ = require "underscore"

module.exports = (logger) ->
  Utahs = { # just becase controllers are plural, and we don't want to conflict with the model name
    eligibility: (req, res) ->
      Utah.eligibility req.user, (err, results) ->
        return res.json({error: err}, 500) if err
        res.json results

    sportsmans: (req, res) ->
      #Utah.sportsmans req.user, (err, results) ->
      #  logger.info "err:", err if err
  }

  _.bindAll.apply _, [Utahs].concat(_.functions(Utahs))
  return Utahs
