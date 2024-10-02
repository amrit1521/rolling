async = require 'async'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db, logger) ->

  HuntOptionSchema = new Schema {
    active: Boolean
    data: Mixed
    huntId: ObjectId
    stateId: type: ObjectId, index: true
  }

  HuntOptionSchema.statics.byId = (id, cb) ->
    @findOne({_id: id}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntOptionSchema.statics.byHuntId = (huntId, cb) ->
    @find({huntId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntOptionSchema.statics.byStateId = (stateId, cb) ->
    console.log "HuntOption.byStateId:", {stateId}
    @find({stateId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntOptionSchema.statics.parse = (cb) ->
    saveOption = (option, next) ->
      option.save ->
        next()

    @find().exec (err, options) ->
      for option in options
        data = option.get('data').replace(/(\w+):/g, '"$1":').replace(/'/g, '"')
        logger.info "BEFORE data:", data
        data = JSON.parse data
        logger.info "MIDDLE data:", data
        data = JSON.stringify data
        logger.info "AFTER data:", data
        option.set 'data', data

      async.map options, saveOption, (err) ->
        cb()

  HuntOption = db.model "HuntOption", HuntOptionSchema
