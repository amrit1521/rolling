mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  UserStateSchema = new Schema {
    stateId: ObjectId
    userId: ObjectId
    cid: String
  }

  UserStateSchema.index { stateId: 1, userId: 1 }

  UserStateSchema.statics.byUser = (userId, cb) ->
    @find({userId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserStateSchema.statics.byStateUsers = (stateId, userIds, cb) ->
    @find({stateId, userId: {$in: userIds}, cid: {$ne: null}}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserStateSchema.statics.byStateAndUser = (userId, stateId, cb) ->
    @findOne({userId, stateId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserStateSchema.statics.byCIDState = (cid, stateId, cb) ->
    @findOne({cid, stateId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserStateSchema.statics.byCIDStateAll = (cid, stateId, cb) ->
    @find({cid, stateId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserStateSchema.statics.index = (cb) ->
    @find({}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserStateSchema.statics.clear = (userId, stateId, cb) ->
    @findOne {userId, stateId}, (err, userState) ->
      return cb err if err
      return cb 'Not Found' unless userState

      userState.remove (err) ->
        return cb err if err
        cb()

  UserStateSchema.statics.upsert = (data, cb) ->
    delete data._id if data._id
    @findOneAndUpdate({userId: data.userId, stateId: data.stateId}, {$set: data}, {upsert: true, new: true}).lean().exec (err, userState) ->
      cb err, userState


  UserState = db.model "UserState", UserStateSchema
