_ = require "underscore"
async = require "async"
moment = require "moment"

module.exports = (DrawResult, logger, State, User) ->

  DrawResults = {

    adminReport: (req, res) ->

      return res.json "tenantId is required", 500 unless req.tenant._id

      State.byName req.param('state'), (err, state) ->

        #ALL draw results
        if req?.query?.type is "all"
          DrawResult.byStateResults state._id, req.tenant._id, moment().year(), "all", (err, drawResults) ->
            return res.json err, 500 if err
            userIds = _.pluck drawResults, 'userId'
            User.find({_id: {$in: userIds}}).lean().exec (err, users) ->
              return res.json err, 500 if err

              for drawResult in drawResults
                for user in users
                  if user._id.toString() is drawResult.userId.toString()
                    if user.name
                      user.userName = user.name
                    else
                      user.userName = user.first_name + " " + user.last_name
                    _.extend drawResult, _.pick(user, 'userName', 'clientId', 'suffix', 'phone_day', 'email', 'tenantId', 'first_name', 'last_name')
                    break

              res.json drawResults

        #UNSUCCESSFUL draw results
        else if req?.query?.type is "unsuccessful"
          DrawResult.byStateResults state._id, req.tenant._id, moment().year(), "unsuccessful", (err, drawResults) ->
            return res.json err, 500 if err
            userIds = _.pluck drawResults, 'userId'
            User.find({_id: {$in: userIds}}).lean().exec (err, users) ->
              return res.json err, 500 if err

              for drawResult in drawResults
                for user in users
                  if user._id.toString() is drawResult.userId.toString()
                    if user.name
                      user.userName = user.name
                    else
                      user.userName = user.first_name + " " + user.last_name
                    _.extend drawResult, _.pick(user, 'userName', 'clientId', 'suffix', 'phone_day', 'email', 'tenantId', 'first_name', 'last_name')
                    break

              res.json drawResults

        #BONUS POINT ONLY draw results
        else if req?.query?.type is "bonusPointOnly"
          DrawResult.byStateResults state._id, req.tenant._id, moment().year(), "bonusPointOnly", (err, drawResults) ->
            return res.json err, 500 if err
            userIds = _.pluck drawResults, 'userId'
            User.find({_id: {$in: userIds}}).lean().exec (err, users) ->
              return res.json err, 500 if err

              for drawResult in drawResults
                for user in users
                  if user._id.toString() is drawResult.userId.toString()
                    if user.name
                      user.userName = user.name
                    else
                      user.userName = user.first_name + " " + user.last_name
                    _.extend drawResult, _.pick(user, 'userName', 'clientId', 'suffix', 'phone_day', 'email', 'tenantId', 'first_name', 'last_name')
                    break

              res.json drawResults

        #SUCCESSFUL draw results
        else
          DrawResult.byStateResults state._id, req.tenant._id, moment().year(), "successful", (err, drawResults) ->
            return res.json err, 500 if err
            userIds = _.pluck drawResults, 'userId'
            User.find({_id: {$in: userIds}}).lean().exec (err, users) ->
              return res.json err, 500 if err

              for drawResult in drawResults
                for user in users
                  if user._id.toString() is drawResult.userId.toString()
                    if user.name
                        user.userName = user.name
                    else
                        user.userName = user.first_name + " " + user.last_name
                    _.extend drawResult, _.pick(user, 'userName', 'clientId', 'suffix', 'phone_day', 'email', 'tenantId', 'first_name', 'last_name')
                    break

              res.json drawResults
  }

  _.bindAll.apply _, [DrawResults].concat(_.functions(DrawResults))
  return DrawResults
