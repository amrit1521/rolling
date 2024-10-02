_ = require "underscore"
async = require "async"
moment = require "moment"

mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db, logger) ->

  DrawResultSchema = new Schema {
    name: String
    unit: String
    status: String
    year: String
    stateId: ObjectId
    userId: ObjectId
    notified: Boolean
    tenantId: ObjectId
    notes: String
    createdAt: type: Date
  }


  DrawResultSchema.index {stateId: 1}, {background:true}
  DrawResultSchema.index {createdAt: 1}, {background:true}

  DrawResultSchema.statics.byId = (drawresultId, cb) ->
    @findOne({_id: drawresultId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  DrawResultSchema.statics.byUserStateYear = (userId, stateId, year, tenantId, cb) ->
    @find {userId, stateId, year, tenantId}, (err, drawresults) -> cb err, drawresults

  DrawResultSchema.statics.deleteByUserState = (userId, stateId, cb) ->
    @remove {userId, stateId}, (err) -> cb err

  DrawResultSchema.statics.deleteByUserStateYear = (userId, stateId, year, cb) ->
    @remove {userId, stateId, year}, (err) -> cb err

  DrawResultSchema.statics.byState = (stateId, cb) ->
    @find({stateId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  DrawResultSchema.statics.bySuccessfulState = (stateId, cb) ->
    conditions = {stateId, $and: [{status: {$ne: "Unsuccessful"}}, {status: {$ne: "unsuccessful"}}, {status: {$ne: "Preference Point"}}] , year: moment().year()}
    conditions.status = "Draw Successful" if stateId.toString() is "52aaa4cae4e055bf33db6499" #AZ

    @find(conditions).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)


  DrawResultSchema.statics.byStateResults = (stateId, tenantId, year, statusType, cb) ->
    if statusType is "successful"
      conditions = {stateId, tenantId, year, $and: [{status: {$ne: "Unsuccessful"}}, {status: {$ne: "unsuccessful"}}, {status: {$ne: "Preference Point"}}, {status: {$ne: "Not Drawn"}}, {status: {$ne: "Bonus Point"}}]}
    else if statusType is "unsuccessful"
      conditions = {stateId, tenantId, year, $and: [{status: {$ne: "Successful"}}, {status: {$ne: "successful"}}, {status: {$ne: "Draw Successful"}}, {status: {$ne: "Preference Point"}}, {status: {$ne: "Drawn"}}, {status: {$ne: "Bonus Point"}}]}
    else if statusType is "bonusPointOnly"
      conditions = {stateId, tenantId, year, $or: [{status: "Preference Point"}, {status:"Bonus Point"}]}
    else if statusType is "all"
      conditions = {stateId, tenantId, year}
    else
      cb "error: invalid statusType '#{}' encountered."
    @find(conditions).lean().exec (err, dResults) ->
      return cb err if err
      return cb err, dResults unless statusType is "unsuccessful"
      drawresults = []
      for drawresult in dResults
        tStatusArray = drawresult.status.split(' ') if drawresult.status?.length
        drawresults.push drawresult unless "Successful" in tStatusArray
      return cb err, drawresults


  DrawResultSchema.statics.byStateResultsDateRange = (stateId, tenantId, year, statusType, startDate, endDate, cb) ->
    startDate = new Date(startDate) if startDate
    endDate = new Date(endDate) if endDate
    createdAt_s = {createdAt: {$gte: startDate}}
    createdAt_e = {createdAt: {$lte: endDate}}
    if statusType is "successful"
      conditions = {stateId, tenantId, year, $and: [createdAt_s, createdAt_e], $and: [{status: {$ne: "Unsuccessful"}}, {status: {$ne: "unsuccessful"}}, {status: {$ne: "Preference Point"}}]}
      conditions.status = "Draw Successful" if stateId.toString() is "52aaa4cae4e055bf33db6499" #AZ
    else if statusType is "unsuccessful"
      conditions = {stateId, tenantId, year, $and: [createdAt_s, createdAt_e], $and: [{status: {$ne: "Successful"}}, {status: {$ne: "successful"}}, {status: {$ne: "Preference Point"}}]}
    else if statusType is "bonusPointOnly"
      conditions = {stateId, tenantId, year, status: "Preference Point", $and: [createdAt_s, createdAt_e]}
    else if statusType is "all"
      conditions = {stateId, tenantId, year, $and: [createdAt_s, createdAt_e]}
    else
      cb "error: invalid statusType '#{}' encountered."

    if stateId is "all"
      delete conditions.stateId

    #console.log "DEBUG: query", ".find(#{JSON.stringify(conditions)})"
    @find(conditions, {_id:true, stateId:true, userId:true}).lean().exec (err, dResults) ->
      return cb err if err
      return cb err, dResults unless statusType is "unsuccessful"
      drawresults = []
      for drawresult in dResults
        tStatusArray = drawresult.status.split(' ') if drawresult.status?.length
        drawresults.push drawresult unless "Successful" in tStatusArray
      return cb err, drawresults

  #Only run by script
  DrawResultSchema.statics.updateTenant = (userId, tenantId, cb) ->
    return cb "Error: DrawResult::updateTenant, userId is required.  userId: #{userId}" unless userId
    return cb "Error: DrawResult::updateTenant, tenantId is required.  tenantId: #{tenantId}" unless tenantId
    console.log "Updating DrawResult for userId: #{userId}, to have tenantId: #{tenantId}"
    @update {"userId" : userId}, {$set: {tenantId: tenantId}}, {upsert: false, multi:true}, (err) ->
      logger.info "DrawResult::updateTenant err:", err if err
      return cb err, userId

  DrawResultSchema.methods.upsert = (opts, cb) ->
    data = this.toJSON()
    delete data._id if this.isNew
    DrawResult.upsert data, opts, cb

  DrawResultSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject
    data = _.omit data, '__v', '$promise', '$resolved'

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    async.waterfall [

      # Find current DrawResult
      (next) =>
        drawResultId = data._id
        delete data._id if data._id
        if opts.query
          query = opts.query
        else if drawResultId
          query = {_id: drawResultId}
        else if data?.stateId and data?.userId and data?.name and data?.year
          query = {stateId: data.stateId, userId: data.userId, name: data.name, year: data.year}
        else
          return next()

        @findOne(query).lean().exec()
          .then (result) ->
            next null, result
          .catch (err) ->
            next(err)

      (drawResult, next) =>

        if not next
          next = drawResult
          drawResult = null

        for key, value of data
          delete data[key] if typeof value is 'undefined'

        data.createdAt = moment() unless drawResult?._id

        query = {_id: {$exists: false}}
        if opts.query
          query = opts.query
        else if drawResult?._id
          query = {_id: drawResult._id}

        @findOneAndUpdate query, {$set: data}, {upsert: opts.upsert, new: true}, next

    ], (err, drawResult) ->
      return cb err if err
      cb null, drawResult

  DrawResult = db.model "DrawResult", DrawResultSchema
