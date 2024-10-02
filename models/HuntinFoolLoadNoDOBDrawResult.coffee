mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed
_ = require 'underscore'

module.exports = (db) ->

  HuntinFoolLoadNoDOBDrawResultSchema = new Schema {
    memberId: String
    hfLoadNoDOBId: ObjectId
    first_name: String
    last_name: String
    mail_address: String
    mail_city: String
    mail_state: String
    mail_postal: String
    city: String
    huntName: String
    unit: String
    status: String
    year: String
    stateId: ObjectId
    tenantId: ObjectId
    modified: Date
    userName: String

  }

  HuntinFoolLoadNoDOBDrawResultSchema.statics.index = (cb) ->
    @find({}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)


  HuntinFoolLoadNoDOBDrawResultSchema.statics.upsert = (data, cb) ->

    return cb {error: "hfLoadNoDOBId required to upsert HuntinFoolLoadNoDOBDrawResult"} unless data.hfLoadNoDOBId
    return cb {error: "huntName required to upsert HuntinFoolLoadNoDOBDrawResult"} unless data.huntName
    return cb {error: "year required to upsert HuntinFoolLoadNoDOBDrawResult"} unless data.year
    return cb {error: "stateId required to upsert HuntinFoolLoadNoDOBDrawResult"} unless data.stateId
    return cb {error: "tenantId required to upsert HuntinFoolLoadNoDOBDrawResult"} unless data.tenantId

    data = data.toObject() if data.toObject
    data = _.omit data, '__v'

    data.modified = new Date()

    query = {hfLoadNoDOBId: data.hfLoadNoDOBId, huntName: data.huntName, year: data.year, stateId: data.stateId, tenantId: data.tenantId}
    if data?._id
      query = {_id: data._id}
      delete data._id

    @findOneAndUpdate query, {$set: data}, {upsert: true, new: true}, cb


  HuntinFoolLoadNoDOBDrawResult = db.model "HuntinFoolLoadNoDOBDrawResult", HuntinFoolLoadNoDOBDrawResultSchema
