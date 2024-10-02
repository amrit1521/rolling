_ = require 'underscore'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  HuntSchema = new Schema {
    active: Boolean
    name: String
    params: Mixed
    match: String
    groupable: Boolean
    stateId: type: ObjectId, index: true
  }

  HuntSchema.statics.byId = (huntId, cb) ->
    @findOne({_id: huntId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntSchema.statics.byStateId = (stateId, opts, cb) ->
    if not cb and typeof opts is 'function'
      cb = opts
      opts = null

    conditions = {stateId: stateId, active: true}
    _.extend conditions, opts.conditions if opts?.conditions

    @find(conditions).sort({name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntSchema.statics.index = (cb) ->
    @find({active: true}).sort({stateId:1, name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntSchema.statics.byStateIdAndMatch = (stateId, match, cb) ->
    @find({stateId, match}).sort({stateId:1, name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntSchema.statics.byStateIdAndParam = (stateId, param, cb) ->
    @find({stateId, params: param}).sort({stateId:1, name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  Hunt = db.model "Hunt", HuntSchema
