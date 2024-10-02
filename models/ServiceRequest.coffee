mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  ServiceFileSchema = new Schema {
    originalName: String
    extension: String
    mimetype: String
    url: String
    size: String
    encoding: String
  }


  ServiceRequestSchema = new Schema {
    external_id: String
    userId: ObjectId
    clientId: String
    memberId: String
    tenantId: ObjectId
    type: type: String, enum: ['Request Hunt Info', 'Support', 'Technical Support']
    subtype: String
    first_name: String
    last_name: String
    address: String
    city: String
    country: String
    postal: String
    state: String
    email: String
    phone: String
    species: String
    location: String
    weapon: String
    budget: String
    referral_source: String
    referral_ip: String
    referral_url: String
    message: String
    notes: String
    newsletter: Boolean
    specialOffers: Boolean
    external_date_created: Date
    updatedAt: Date
    lastFollowedUpAt: Date
    contactDiffs: String
    needsFollowup: Boolean
    status: String
    contactable: String

    purchase: {
      purchaseId: ObjectId
      huntCatalogId: ObjectId
      huntCatalogNumber: String
      huntCatalogTitle: String
      huntCatalogType: String
      purchaseNotes: String
      paymentMethod: String
    }
    purchase_hunt: {
      depositReceived: Date
      client_doc_sent: Date
      outfitter_doc_sent: Date
      outfitter_payment_sent: Date
    }

    files: [ServiceFileSchema]



  }

  ServiceRequestSchema.index {userId: 1}, {background:true}
  ServiceRequestSchema.index {external_id: 1}, {background:true}
  ServiceRequestSchema.index {clientId: 1}, {background:true}
  ServiceRequestSchema.index {memberId: 1}, {background:true}


  ServiceRequestSchema.statics.byId = (id, tenantId, cb) ->
    @findOne({_id: id, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ServiceRequestSchema.statics.byExternalId = (external_id, tenantId, cb) ->
    @findOne({external_id, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ServiceRequestSchema.statics.byTenant = (tenantId, cb) ->
    @find({tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ServiceRequestSchema.statics.byClientId = (clientId, tenantId, cb) ->
    @find({clientId, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ServiceRequestSchema.statics.byMemberId = (memberId, tenantId, cb) ->
    @find({memberId, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ServiceRequestSchema.statics.byUserId = (userId, tenantId, cb) ->
    @find({userId, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ServiceRequestSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    data.updatedAt = new Date();

    serviceRequestId = data._id
    delete data._id if data._id

    #insert new, or update if provided an _id, or externalId
    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if serviceRequestId
      query = {$and: [{_id: serviceRequestId}, {_id: {$ne: null}}]}
    else if data.external_id
      query = {$and: [{external_id: data.external_id}, {external_id: {$ne: null}}]}

    delete data._id if data._id
    return cb {error: "_id, or externalId required to upsert ServiceRequest"} unless query

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, serviceRequest) =>
      return cb err if err
      return cb {error: "ServiceRequest update/insert failed"} unless serviceRequest
      cb null, serviceRequest

  ServiceRequest = db.model "ServiceRequest", ServiceRequestSchema
