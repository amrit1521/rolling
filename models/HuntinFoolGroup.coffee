mongoose = require 'mongoose'
Schema = mongoose.Schema

module.exports = (db) ->
  HuntinFoolGroupSchema = new Schema {
    leader: String
    members: Array
  }

  HuntinFoolGroupSchema.statics.byLeader = (leader, cb) ->
    @findOne({leader}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolGroupSchema.statics.byClientId = (clientId, cb) ->
    @findOne({members: clientId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolGroupSchema.statics.index = (cb) ->
    @find().lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolGroup = db.model "HuntinFoolGroup", HuntinFoolGroupSchema
