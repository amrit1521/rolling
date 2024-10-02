_ = require "underscore"
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (
  db
  logger
) ->

  StateSchema = new Schema {
    active: Boolean
    applicationReady: Boolean
    applicationUrl: String
    abbreviation: String
    hasPoints: Boolean
    idTitle: String
    idRequired: Boolean
    name: String
    oddsUrl: String
    pointsUrl: String
    url: String
  }

  StateSchema.statics.active = (cb) ->
    @find({active: true}).sort({name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  StateSchema.statics.hasPoints = (cb) ->
    @find({active: true, hasPoints: true}).sort({name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)
    #@find({active: true, hasPoints: true, abbreviation: "TX"}).sort({name:1}).lean().exec cb

  StateSchema.statics.adminIndex = (cb) ->
    @find().sort({name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  StateSchema.statics.byId = (stateId, cb) ->
    @findOne({_id: stateId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  StateSchema.statics.byName = (state, cb) ->
    @findOne({name: state}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  StateSchema.statics.findByAbbreviation = (abbreviation, cb) ->
    @findOne({abbreviation}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  StateSchema.statics.getModelByAbbreviation = (abbreviation, cb) ->
    return cb "Invalid abbreviation" unless abbreviation?.length

    @findByAbbreviation abbreviation, (err, state) =>
      return cb "Invalid abbreviation" unless state

      @initModel state.name, (err, model) ->
        return cb err if err
        model.stateId = state._id
        cb null, model

  StateSchema.statics.getModelByName = (state, cb) ->
    @findOne({name: state}).exec (err, stateObj) =>
      return cb err if err
      @getModelByStateId  stateObj._id, cb

  StateSchema.statics.getModelByStateId = (stateId, cb) ->
    @byId stateId, (err, state) =>
      return cb err if err
      return {error: "State not found", code: 404} unless state

      @initModel state.name, (err, model) ->
        return cb err if err
        model.stateId = state._id
        cb null, model

  StateSchema.statics.index = (cb) ->
    @find({active: true}).sort({name:1}).lean().exec (err, states) ->
      return cb err, states

  StateSchema.statics.initModel = (name, cb) ->
    try
      model = eval(name.replace(/\s+/g, ''))
    catch error
      logger.error "Failed to find a model for:", name
      return cb {error: "Failed to find a model for #{name}", code: 404}

    cb null, model

  StateSchema.statics.upsert = (data, cb) ->
    stateId = data._id
    delete data._id if data._id
    data = _.omit data, '__v', '$promise', '$resolved'

    query = {_id: {$exists: false}}
    query = {_id: stateId} if stateId

    @findOneAndUpdate query, data, {upsert: true, new: true}, (err, result) ->
      return cb err if err
      cb null, result

  State = db.model "State", StateSchema
