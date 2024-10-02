mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  TokenSchema = new Schema {
    userId: ObjectId
    token: type: String
    expires: type: Date
  }

  TokenSchema.statics.findById = (_id, cb) ->
    @findOne {_id}, cb

  TokenSchema.statics.findById = (token, cb) ->
    @findOne {token}, cb

  TokenSchema.statics.findBytoken = (token, cb) ->
    @findOne {token}, cb

  TokenSchema.statics.findByUserId = (userId, cb) ->
    @findOne {userId}, cb

  Token = db.model "Token", TokenSchema
