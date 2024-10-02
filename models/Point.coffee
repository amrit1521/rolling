_ = require "underscore"
async = require "async"

mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db, logger) ->

  PointSchema = new Schema {
    area: String
    count: Number
    created: Date
    eligibleDate: String
    harvest: String
    lastPoint: String
    lastTagDate: String
    name: String
    reason: String
    stateId: ObjectId
    tenantId: ObjectId
    userId: ObjectId
    weight: Number
  }

  PointSchema.index {userId: 1, stateId: 1}

  PointSchema.statics.addToState = (userId) ->
    (state, cb) =>
      @find({userId, stateId: state._id}).lean().exec (err, points) ->
        return cb err if err
        state.points = points
        cb null, state

  PointSchema.statics.byUser = (userId, cb) ->
    @find({userId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PointSchema.statics.byUserAndState = (userId, stateId, cb) ->
    @find({userId, stateId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PointSchema.statics.byTenantAndState = (tenantId, stateId, cb) ->
    @find({stateId, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PointSchema.statics.index = (cb) ->
    @find {}, cb

  PointSchema.statics.save = (data, cb) ->
    @update {userId: data.userId, stateId: data.stateId, name: data.name, tenantId: data.tenantId}, data, {upsert: true}, (err) ->
      logger.info "Point::save err:", err if err
      return cb err, data

  #Only run by script
  PointSchema.statics.updateTenant = (userId, tenantId, cb) ->
    return cb "Error: Point::updateTenant, userId is required.  userId: #{userId}" unless userId
    return cb "Error: Point::updateTenant, tenantId is required.  tenantId: #{tenantId}" unless tenantId
    console.log "Updating points for userId: #{userId}, to have tenantId: #{tenantId}"
    @update {"userId" : userId}, {$set: {tenantId: tenantId}}, {upsert: false, multi:true}, (err) ->
      logger.info "Point::updateTenant err:", err if err
      return cb err, userId

  PointSchema.statics.saveGroup = (points, cb) ->
    return cb() if not points or not points.length

    save = (point, done) =>
      @save(point, done)

    #remove existing
    stateIds = _.uniq _.pluck(points, 'stateId')
    conditions = {
      stateId: {$in: stateIds}
      userId: points[0].userId
    }

    @remove conditions, (err) ->
      return cb err if err
      async.map points, save, cb

  Point = db.model "Point", PointSchema
