mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  LicenseSchema = new Schema {
    stateId: ObjectId
    transactionId: String
    url: String
    userId: ObjectId
    year: String
  }

  LicenseSchema.statics.byId = (licenseId, cb) ->
    @findOne({_id: licenseId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  LicenseSchema.statics.byUserHunt = (userId, huntId, cb) ->
    @findOne({userId, huntId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  License = db.model "License", LicenseSchema
