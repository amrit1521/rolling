mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  TenantEmailSchema = new Schema {
    tenantId: ObjectId
    email_html: String
    email_text: String
    subject: String
    timestamp: Date
    type: String
    enabled: Boolean
    testUserId: ObjectId
  }

  TenantEmailSchema.statics.delete = (id, tenantId, cb) ->
    @findOne {_id: id, tenantId}, (err, tenantEmail) ->
      return cb err if err
      return cb 'Not Found' unless tenantEmail

      tenantEmail.remove (err) ->
        return cb err if err
        cb()

  TenantEmailSchema.statics.findById = (id, cb) ->
    @findOne({_id: id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantEmailSchema.statics.findByType = (type, tenantId, cb) ->
    @findOne({type, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantEmailSchema.statics.findEnabledByType = (type, tenantId, cb) ->
    @findOne({type, tenantId, enabled: true}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantEmail = db.model "TenantEmail", TenantEmailSchema
