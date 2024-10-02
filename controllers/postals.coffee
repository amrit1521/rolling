_     = require "underscore"
async = require "async"

module.exports = (logger, NavTools, State, Zipcode) ->

  Postals = {

    getState: (req, res) ->
      Zipcode.findByCode req.param('code'), (err, postal) ->
        return res.json err, 500 if err
        return res.json {error: "Zip code not found", code: 9462}, 404 unless postal
        res.json {state: NavTools.stateFromAbbreviation(postal.state)}
  }

  _.bindAll.apply _, [Postals].concat(_.functions(Postals))
  return Postals
