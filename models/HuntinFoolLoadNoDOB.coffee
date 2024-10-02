mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->



  HuntinFoolLoadNoDOBSchema = new Schema {
    memberId: String
    first_name: String
    last_name: String
    mail_address: String
    mail_city: String
    mail_state: String
    mail_postal: String
    dob: String

  }

  HuntinFoolLoadNoDOBSchema.statics.index = (cb) ->
    @find({}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)


  HuntinFoolLoadNoDOBSchema.statics.matchUser = (first_name, last_name, drawResult, cb) ->
    @findOne({ "first_name" : {$regex : new RegExp(first_name, "i")}, "last_name" : {$regex : new RegExp(last_name, "i")},  "mail_city" : {$regex : new RegExp(drawResult.city, "i")}}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)


  HuntinFoolLoadNoDOB = db.model "HuntinFoolLoadNoDOB", HuntinFoolLoadNoDOBSchema
