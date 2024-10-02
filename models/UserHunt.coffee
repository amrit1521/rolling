mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  UserHuntSchema = new Schema {
    huntId: ObjectId
    userId: ObjectId
    cid: String
  }

  UserHuntSchema.statics.byUser = (userId, cb) ->
    @find({userId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserHuntSchema.statics.byHuntAndUser = (data, cb) ->
    @find({userId: data.userId, huntId: data.huntId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserHuntSchema.statics.index = (cb) ->
    @find({}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserHuntSchema.statics.upsert = (data, cb) ->
    delete data._id if data._id
    @update {userId: data.userId, huntId: data.huntId}, data, {upsert: true}, (err, numberAffected, raw) ->
      return cb err if err
      return cb null, data

  UserHunt = db.model "UserHunt", UserHuntSchema
