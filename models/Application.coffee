_ = require 'underscore'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  ApplicationSchema = new Schema {
    clientId: String
    huntId: ObjectId # This is deprecated. Use the huntIds field as an Array
    huntIds: [ObjectId]
    license: String
    licenses: Mixed
    name: String
    receipt: String
    resultBody: String
    review_html: String
    review_file: String
    stateId: ObjectId
    timestamp: {type: Date, default: Date.now}
    tenantId: ObjectId
    total: Number
    transactionId: String
    userId: ObjectId
    year: String
    cardIndex: String
    cardTitle: String
    status: type: String, enum: ['saved', 'review_requested', 'review_ready', 'reviewed', 'purchase_requested', 'purchased', 'error']
    error: String
    lastPage: String
  }

  MAX_TIME = 300000

  ApplicationSchema.index {userId: 1, stateId: 1, receipt: 1}

  ApplicationSchema.index {timestamp: 1}, {background:true}

  ApplicationSchema.statics.byId = (applicationId, cb) ->
    @findOne({_id: applicationId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.byUserHunt = (userId, huntId, cb) ->
    @findOne({userId, $or: [{huntId}, {huntIds: huntId}]}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.byUserHuntYear = (userId, huntId, year, cb) ->
    @findOne({userId, year, $or: [{huntId}, {huntIds: huntId}]}).sort( { timestamp: -1 } ).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.byUserHunts = (userId, huntIds, cb) ->
    @find({userId, $or: [{huntId: {$in: huntIds}}, {huntIds: {$in: huntIds}}]}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.byUsersHunts = (userIds, huntIds, cb) ->
    @find({userId: {$in: userIds}, $or: [{huntId: {$in: huntIds}}, {huntIds: {$in: huntIds}}]}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.byUsersHuntsYear = (userIds, huntIds, year, sort, cb) ->
    if not cb and typeof sort is "function"
      cb = sort
      @find({year, userId: {$in: userIds}, $or: [{huntId: {$in: huntIds}}, {huntIds: {$in: huntIds}}]}).lean().exec()
        .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)
      @find({year, userId: {$in: userIds}, $or: [{huntId: {$in: huntIds}}, {huntIds: {$in: huntIds}}]}).sort(sort).lean().exec()
        .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.byUserState = (userId, stateId, cb) ->
    @find({userId, stateId}).lean().exec (err, applications) ->
      return cb err if err

      for application, index in applications
        applications[index] = _.omit application, 'resultBody'

      cb null, applications

  ApplicationSchema.statics.byUserStateYear = (userId, stateId, year, cb) ->
    @find({userId, stateId, year}).lean().exec (err, applications) ->
      return cb err if err

      for application, index in applications
        applications[index] = _.omit application, 'resultBody'

      cb null, applications

  ApplicationSchema.statics.findLicense = (stateId, userId, year, cb) ->
    @findOne({stateId, userId, year, license: {$ne: null}}).exec
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.findLicenses = (stateId, userIds, year, cb) ->
    @find({stateId, userId: {$in: userIds}, year, license: {$ne: null}}).lean().exec
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ApplicationSchema.statics.receiptsByUserState = (userId, stateId, cb) ->
    @find({userId, stateId, $or: [{receipt: {$ne: null}}, {license: {$ne: null}}]}).lean().exec (err, applications) ->
      return cb err if err

      for application, index in applications
        applications[index] = _.omit application, 'resultBody'

      cb null, applications

  ApplicationSchema.statics.byPurchasedTenantDateRange = (tenantId, startDate, endDate, cb) ->
    startDate = new Date(startDate) if startDate
    endDate = new Date(endDate) if endDate
    year = startDate.getFullYear()
    createdAt_s = {timestamp: {$gte: startDate}}
    createdAt_e = {timestamp: {$lte: endDate}}
    conditions = {tenantId, year, status: "purchased", $and: [createdAt_s, createdAt_e]}

    #EXAMPLE WITH OBJECTID AND DATES: db.getCollection('applications').find({"tenantId":ObjectId("53a28a303f1e0cc459000127"),"year":"2017","status":"purchased", "$and":[{"timestamp":{"$gte":ISODate("2017-06-01T00:00:00.000Z")}},{"timestamp":{"$lte":ISODate("2017-06-30T23:59:59.999Z")}}]},{stateId:true, status:true, userId: true, huntIds: true})
    #console.log "DEBUG QUERY: db.getCollection('applications').find(#{JSON.stringify(conditions)},{stateId:true, status:true, userId: true, huntIds: true})"
    @find(conditions,{_id:true, huntIds: true}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  #Only run by script
  ApplicationSchema.statics.updateTenant = (userId, clientId, tenantId, cb) ->
    return cb "Error: Application::updateTenant, userId is required.  userId: #{userId}" unless userId
    return cb "Error: Application::updateTenant, tenantId is required.  tenantId: #{tenantId}" unless tenantId
    return cb "Error: Application::updateTenant, clientId is required.  clientId: #{clientId}" unless clientId
    console.log "Updating Applications for userId: #{userId}, to have tenantId: #{tenantId}"
    @update {"userId" : userId}, {$set: {tenantId: tenantId, clientId: clientId}}, {upsert: false, multi:true}, (err) ->
      logger.info "Application::updateTenant err:", err if err
      return cb err, userId


  Application = db.model "Application", ApplicationSchema
