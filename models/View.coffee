mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  ViewSchema = new Schema {
    tenantId: ObjectId        #views without tenantId will be available system wide
    userId: ObjectId          #views without userId will be available for all users
    selector: String          #only #id selectors are currently supported
    name: String
    admin_only: Boolean
    options: String
    description: String
  }

  ViewSchema.statics.byId = (id, cb) ->
    @findOne({_id: id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ViewSchema.statics.bySelector = (tenantId, selector, userId, isAdmin, cb) ->
    return cb {error: 'tenantId required'} unless tenantId
    return cb {error: 'selector required'} unless selector
    return cb {error: 'userId required'} unless selector
    conditions = {
      selector: selector,
      tenantId: tenantId,
      $or: [
        {userId: userId},
        {userId: {$exists: false}
        }
      ]
    }
    conditions.admin_only = false unless isAdmin
    @find(conditions).sort({name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ViewSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    data.updatedAt = new Date();

    viewId = data._id
    delete data._id if data._id

    #insert new, or update if provided an _id
    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if viewId
      query = {$and: [{_id: viewId}, {_id: {$ne: null}}]}

    delete data._id if data._id
    return cb {error: "_id required to update View"} unless query

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, savedView) =>
      return cb err if err
      return cb {error: "View update/insert failed"} unless savedView
      cb null, savedView

  View = db.model "View", ViewSchema
