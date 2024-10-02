mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  HuntinFoolLoadGenericSchema = new Schema {
    member_id: String
    state: String
    cid: String
    notes: String
  }

  HuntinFoolLoadGenericSchema.statics.index = (cb) ->
    @find({}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolLoadGeneric = db.model "HuntinFoolLoadGeneric", HuntinFoolLoadGenericSchema
