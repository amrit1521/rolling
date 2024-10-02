_ = require "underscore"
async = require "async"

module.exports = (UserState, logger) ->

  UserStates = {

    delete: (req, res) ->
      {userId, stateId} = req.params

      UserState.clear userId, stateId, (err) ->
        return res.json err, 500 if err
        res.json {message: "UserState deleted"}

  }

  _.bindAll.apply _, [UserStates].concat(_.functions(UserStates))
  return UserStates
