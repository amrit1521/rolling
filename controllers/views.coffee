_ = require "underscore"
async = require "async"
moment = require "moment"


module.exports = (View, User) ->

  Views = {

    find: (req, res) ->
      viewData = {
        tenantId: req.param('tenantId')
        selector: req.param('selector')
        userId: req.param('userId')
      }
      return res.json {error: 'Tenant id required'}, 400 unless viewData.tenantId
      return res.json {error: 'Selector required'}, 400 unless viewData.selector

      isAdmin = false

      if viewData.userId
        User.byId viewData.userId, {}, (err, user) ->
          return res.json err, 500 if err
          isAdmin = user.isAdmin if user
          View.bySelector viewData.tenantId, viewData.selector, viewData.userId, isAdmin, (err, views) ->
            return res.json err, 500 if err
            res.json views
      else
        View.bySelector viewData.tenantId, viewData.selector, null, isAdmin, (err, views) ->
          return res.json err, 500 if err
          res.json views


    save: (req, res) ->
      viewData = req.body
      return res.json {error: 'Tenant id required'}, 400 unless viewData.tenantId
      return res.json {error: 'Selector required'}, 400 unless viewData.selector

      View.upsert req.body, (err, view) ->
        return res.json err, 500 if err
        res.json view

  }

  _.bindAll.apply _, [Views].concat(_.functions(Views))
  return Views
