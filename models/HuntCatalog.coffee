mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed
_ = require 'underscore'


module.exports = (db) ->


  HuntCatalogMediaSchema = new Schema {
    originalName: String
    extension: String
    mimetype: String
    url: String
    size: String
    encoding: String
  }

  HuntCatalogSchema = new Schema {
    huntNumber: String
    vendor_product_number: String
    title: String
    outfitter_userId: ObjectId
    outfitter_name: String
    tenantId: ObjectId
    isActive: Boolean
    isHuntSpecial: Boolean
    memberDiscount: Boolean
    country: String
    state: String
    area: String
    species: String
    weapon: String
    price: Number
    price_non_commissionable: Number        #Amount of the outfitter's prices that is non commissionable
    price_commissionable: Number        #Amount of the outfitter's prices that is RBO commissionable
    price_rep_commissionable: Number        #Amount the reps commissions will be calculated against
    fee_processing: Number
    price_total: Number
    price_nom: Number
    rbo_commission: Number
    rbo_reps_commission: Number
    #budgetStart: String
    #budgetEnd: String
    startDate: Date
    endDate: Date
    internalNotes: String
    pricingNotes: String
    description: String
    huntSpecialMessage: String
    classification: String
    createMember: Boolean
    createRep: Boolean
    createMemberType: String
    updatedAt: Date
    createdAt: Date
    status: String
    type: String
    paymentPlan: String
    refund_policy: String
    media: [HuntCatalogMediaSchema]
    rradsObj: String
  }

  HuntCatalogSchema.index {type: 1}, {background:true}
  HuntCatalogSchema.index {status: 1}, {background:true}
  HuntCatalogSchema.index {tenantId: 1}, {background:true}

  HuntCatalogSchema.statics.byId = (id, cb) ->
    @findOne({_id: id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntCatalogSchema.statics.byHuntNumber = (huntNumber, tenantId, cb) ->
    @findOne({huntNumber: huntNumber, tenantId: tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntCatalogSchema.statics.byTenant = (tenantId, cb) ->
    @find({tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntCatalogSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject
    data = _.omit data, '__v', '$promise', '$resolved'

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    data.updatedAt = new Date();

    huntCatalogId = data._id
    delete data._id if data._id

    #insert new, or update if provided an _id, or externalId
    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if huntCatalogId
      query = {$and: [{_id: huntCatalogId}, {_id: {$ne: null}}]}

    delete data._id if data._id
    return cb {error: "_id required to update HuntCatalog"} unless query

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, huntCatalog) =>
      return cb err if err
      return cb {error: "HuntCatalog update/insert failed"} unless huntCatalog
      cb null, huntCatalog

  HuntCatalog = db.model "HuntCatalog", HuntCatalogSchema
