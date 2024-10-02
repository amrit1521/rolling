mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  ZipcodeSchema = new Schema {
    code: String
    state: String
    city: String
    county: String
    lat: Number
    lon: Number
  }

  ZipcodeSchema.statics.findByCode = (code, cb) ->
    @findOne {code}, cb

  Zipcode = db.model "Zipcode", ZipcodeSchema
