mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  HuntinFoolClientSchema = new Schema {
    billing1_address: String
    billing1_address2: String
    billing1_city: String
    billing1_state: String
    billing1_zip: String
    billing1_country: String
    billing1_phone: String
    billing2_address: String
    billing2_address2: String
    billing2_city: String
    billing2_state: String
    billing2_zip: String
    billing2_country: String
    billing2_phone: String
    ca_id: String
    client_id: String
    co_conservation: String
    contact_email: String
    driver_license: String
    driver_license_state: String
    duals_last: String
    duals_name: String
    duals_number: String
    eyes: String

    field1: String # ssn/dob part1
    field2: String # ssn/dob part2
    field3: String # ssn last4

    field4: String # cc1 name
    field5: String # cc1 code
    field6: String # cc1/exp part1
    field7: String # cc1/exp part2
    field8: String # cc1 last4

    field9: String # cc2 name
    field10: String # cc2 code
    field11: String # cc2/exp part1
    field12: String # cc2/exp part2
    field13: String # cc2 last4

    needEncryptCC: Boolean

    gender: String
    hair: String
    height: String
    hunter_ed: String
    hunter_ed_state: String
    hunting_comments: String
    ia_conservation: String
    ks_number: String
    mail_address: String
    mail_city: String
    mail_country: String
    mail_county: String
    mail_state: String
    mail_zip: String
    physical_address: String
    physical_city: String
    physical_country: String
    physical_county: String
    physical_state: String
    physical_zip: String
    member_id: String
    modified: Date
    mtals: String
    nm_cin: String
    nmfst: String
    nmlt: String
    nmmd: String
    ore_hunter: String
    phone_cell: String
    phone_day: String
    phone_evening: String
    tl: String
    tx_id: String
    userId: ObjectId
    tenantId: ObjectId
    weapons_mstr: String
    weight: String
    wild: String
    wy_id: String
  }

  HuntinFoolClientSchema.statics.byIds = (clientIds, cb) ->
    @find({client_id: {$in: clientIds}}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolClientSchema.statics.byUserId = (userId, cb) ->
    @findOne({userId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolClientSchema.statics.byClientId = (clientId, cb) ->
    @findOne({client_id: clientId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolClientSchema.statics.byMemberId = (member_id, cb) ->
    @findOne({member_id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolClientSchema.statics.byClientId = (client_id, cb) ->
    @findOne({client_id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolClientSchema.statics.byNeedEncryptCC = (needEncrypt, cb) ->
    @find({needEncryptCC: needEncrypt}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  #Only run by script
  HuntinFoolClientSchema.statics.updateTenant = (userId, clientId, tenantId, cb) ->
    return cb "Error: HuntinFoolClient::updateTenant, userId is required.  userId: #{userId}" unless userId
    return cb "Error: HuntinFoolClient::updateTenant, tenantId is required.  tenantId: #{tenantId}" unless tenantId
    return cb "Error: HuntinFoolClient::updateTenant, clientId is required.  clientId: #{clientId}" unless clientId
    console.log "Updating HuntinFoolClient for userId: #{userId}, to have tenantId: #{tenantId}"
    @update {"userId" : userId}, {$set: {tenantId: tenantId, client_id: clientId}}, {upsert: false, multi:true}, (err) ->
      logger.info "HuntinFoolClient::updateTenant err:", err if err
      return cb err, userId

  HuntinFoolClientSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    huntinFoolClientId = data._id
    delete data._id if data._id

    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if data.client_id
      query = {$and: [{client_id: data.client_id}, {client_id: {$ne: null}}]}
    else if data._id
      huntinFoolClientId = data._id
      query = {$and: [{_id: huntinFoolClientId}, {_id: {$ne: null}}]}

    delete data._id if data._id
    return cb {error: "_id or client_id required to upsert HuntinFoolClient"} unless query

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, huntinFoolClient) =>
      return cb err if err
      return cb {error: "HuntinFoolClient update/insert failed"} unless huntinFoolClient
      cb null, huntinFoolClient

  HuntinFoolClient = db.model "HuntinFoolClient", HuntinFoolClientSchema
