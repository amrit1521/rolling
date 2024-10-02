mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  GlobalSchema = new Schema {
    created: Date
    key: String
    modified: Date
    value: Mixed
  }

  GlobalSchema.statics.get = (key, cb) ->
    @findOne({key}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  GlobalSchema.statics.set = (key, value, cb) ->
    data = {key, value, modified: new Date()}

    @findOneAndUpdate({key}, {$set: data}, {upsert: true, new: true}).exec (err, result) =>
      return cb err if err
      return cb {error: "Global update/insert failed"} unless result

      if not result.created
        result.created = new Date()
        result.save (err) ->
          return cb err if err
          cb null, result.toObject()
      else
        cb null, result.toObject()

  Global = db.model "Global", GlobalSchema
