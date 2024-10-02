mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  HuntinFoolLoadDOBSchema = new Schema {
    member_id: String
    first_name: String
    last_name: String
    mail_address: String
    mail_city: String
    mail_state: String
    mail_zip: String
    dob: String
  }

  HuntinFoolLoadDOBSchema.statics.index = (cb) ->
    @find({}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolLoadDOB = db.model "HuntinFoolLoadDOB", HuntinFoolLoadDOBSchema
