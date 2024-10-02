_ = require "underscore"
async = require "async"

module.exports = (HuntinFoolState, logger) ->

  Clients = {

    read: (req, res) ->
      {userId, year} = req.params
      return res.json {error: 'userId required'}, 400 unless userId
      return res.json {error: 'year is required'}, 400 unless year

      HuntinFoolState.byUserIdYear userId, year, (err, result) ->
        return res.json({error: err}, 500) if err
        return res.json null unless result
        res.json result

  }

  _.bindAll.apply _, [Clients].concat(_.functions(Clients))
  return Clients
