_ = require 'underscore'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed
async = require "async"

module.exports = (db) ->

  ReferSchema = new Schema {
    ip: String
    modified: type: Date, "default": Date.now, index: true
    referrer: String

  }

  ReferSchema.statics.byId = (referId, opts, cb) ->
    if not cb and typeof opts is "function"
      cb = opts
      opts = {}
    @findOne({_id: referId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReferSchema.statics.byIP = (ip, opts, cb) ->
    if not cb and typeof opts is "function"
      cb = opts
      opts = {}

    @findOne({ip: ip}).exec (err, user) ->
      return cb err if err
      return cb null, user

  ReferSchema.statics.index = (cb) ->
    @find({active: true}).sort({stateId:1, name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReferSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject
    data = _.omit data, '__v', '$promise', '$resolved'

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    async.waterfall [

      # Find current Refer
      (next) =>
        referId = data._id
        delete data._id if data._id
        if opts.query
          query = opts.query
        else if referId
          query = {_id: referId}
        else if data?.ip
          query = {ip: data.ip}
        else
          return next()

        @findOne(query).lean().exec()
          .then (result) ->
            next null, result
          .catch (err) ->
            next(err)

      (refer, next) =>

        if not next
          next = refer
          refer = null

        for key, value of data
          delete data[key] if typeof value is 'undefined'

        query = {_id: {$exists: false}}
        if opts.query
          query = opts.query
        else if refer?._id
          query = {_id: refer._id}

        @findOneAndUpdate query, {$set: data}, {upsert: opts.upsert, new: true}, next

    ], (err, refer) ->
      return cb err if err
      cb null, refer

  Refer = db.model "Refer", ReferSchema
