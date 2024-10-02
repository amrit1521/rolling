_ = require "underscore"
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db, logger) ->

  ModelSchema = new Schema {
    userId: ObjectId
    message: String
    created: Date
    read: Date
  }

  ModelSchema.statics.byUserId = (userId, cb) ->
    @find({userId}).sort({created: -1}).limit(100).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ModelSchema.statics.markAllRead = (userId, cb) ->
    return cb {message: "User ID required"} unless userId
    @update {userId, read: null}, {$set: {read: new Date()}}, {multi: true}, cb

  ModelSchema.statics.markAsRead = (id, cb) ->
    return cb {message: "ID required"} unless id
    @findOneAndUpdate {_id: id}, {$set: {read: new Date()}}, {upsert: false, new: true}, cb

  ModelSchema.statics.unreadCount = (userId, cb) ->
    @find({userId, read: null}).countDocuments().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ModelSchema.statics.upsert = (data, cb) ->
    data = data.toObject() if data.toObject
    data = _.omit data, '__v'

    data.created = new Date() unless data.created

    query = {_id: {$exists: false}}
    if data?._id
      query = {_id: data._id}
      delete data._id

    @findOneAndUpdate query, {$set: data}, {upsert: true, new: true}, cb

  db.model "Notification", ModelSchema
