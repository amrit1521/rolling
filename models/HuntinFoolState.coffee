mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  HuntinFoolStateSchema = new Schema {
    userId: ObjectId
    tenantId: ObjectId
    client_id: String
    modified: Date
    year: String
    gen_notes: String
    ak_check: String
    ak_comments: String
    ak_notes: String
    ak_species: String
    ak_species_picked: [String]
    az_check: String
    az_comments: String
    az_license: String
    az_notes: String
    az_species: String
    az_species_picked: [String]
    ca_check: String
    ca_comments: String
    ca_notes: String
    ca_species: String
    ca_species_picked: [String]
    co_check: String
    co_comments: String
    co_notes: String
    co_species: String
    co_species_picked: [String]
    fl_check: String
    fl_notes: String
    fl_species: String
    fl_species_picked: [String]
    ia_check: String
    ia_comments: String
    ia_notes: String
    ia_species: String
    ia_species_picked: [String]
    id_check: String
    id_comments: String
    id_notes: String
    id_species_1: String
    id_species_3: String
    id_species_picked: [String]
    ks_check: String
    ks_comments: String
    ks_mule_deer_stamp: String
    ks_notes: String
    ks_species: String
    ks_species_picked: [String]
    ky_check: String
    ky_notes: String
    ky_species: String
    ky_species_picked: [String]
    mt_check: String
    mt_comments: String
    mt_notes: String
    mt_species: String
    mt_species_picked: [String]
    nd_check: String
    nd_notes: String
    nd_species: String
    nd_species_picked: [String]
    nm_check: String
    nm_comments: String
    nm_notes: String
    nm_species: String
    nm_species_picked: [String]
    nv_check: String
    nv_comments: String
    nv_notes: String
    nv_species: String
    nv_species_picked: [String]
    ore_check: String
    ore_comments: String
    ore_notes: String
    ore_species: String
    ore_species_picked: [String]
    sd_check: String
    sd_notes: String
    sd_species: String
    sd_species_picked: [String]
    pa_check: String
    pa_notes: String
    pa_species: String
    pa_species_picked: [String]
    tx_check: String
    tx_notes: String
    tx_species: String
    tx_species_picked: [String]
    ut_check: String
    ut_comments: String
    ut_notes: String
    ut_species_1: String
    ut_species_2: String
    ut_species_picked: [String]
    vt_check: String
    vt_notes: String
    vt_species: String
    vt_species_picked: [String]
    wa_check: String
    wa_comments: String
    wa_notes: String
    wa_species: String
    wa_species_picked: [String]
    wy_check: String
    wy_comments: String
    wy_notes: String
    wy_species: String
    wy_species_picked: [String]
  }

  HuntinFoolStateSchema.statics.byTenantId = (tenantId, cb) ->
    @find({tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolStateSchema.statics.byClientId = (client_id, cb) ->
    @findOne({client_id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolStateSchema.statics.byClientIdYear = (clientId, year, cb) ->
    @findOne({client_id: clientId, year: year}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolStateSchema.statics.byUserIdYear = (userId, year, cb) ->
    @findOne({userId: userId, year: year}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolStateSchema.statics.byUserId = (userId, cb) ->
    @find({userId: userId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolStateSchema.statics.stateApplicants = (state, tenantId, cb) ->
    search = {}
    search[state + '_check'] = 'True'

    if not cb and typeof tenantId is 'function'
      cb = tenantId
      tenantId = null

    search.tenantId = tenantId if tenantId

    fields = {client_id: 1, year:1, tenantId:1, userId:1}
    if state is 'id'
      fields[state + '_species_1'] = 1
      fields[state + '_species_3'] = 1
    else if state is 'ut'
      fields[state + '_species_1'] = 1
      fields[state + '_species_2'] = 1
    else
      fields[state + '_species'] = 1
    fields[state + '_notes'] = 1
    @find(search, fields).lean().exec (err, results) ->
      console.log "found HuntinFoolState entries for state #{state}:", results.length if results?.length
      return cb err, results

  #Only run by script
  HuntinFoolStateSchema.statics.updateTenant = (userId, clientId, tenantId, cb) ->
    return cb "Error: HuntinFoolState::updateTenant, userId is required.  userId: #{userId}" unless userId
    return cb "Error: HuntinFoolState::updateTenant, tenantId is required.  tenantId: #{tenantId}" unless tenantId
    return cb "Error: HuntinFoolState::updateTenant, clientId is required.  clientId: #{clientId}" unless clientId
    console.log "Updating HuntinFoolClient for userId: #{userId}, to have tenantId: #{tenantId}"
    @update {"userId" : userId}, {$set: {tenantId: tenantId, client_id: clientId}}, {upsert: false, multi:true}, (err) ->
      logger.info "HuntinFoolState::updateTenant err:", err if err
      return cb err, userId

  HuntinFoolStateSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    huntinFoolStateId = data._id
    delete data._id if data._id

    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if data._id
      huntinFoolStateId = data._id
      query = {$and: [{_id: huntinFoolStateId}, {_id: {$ne: null}}]}
    else if data.userId and data.client_id
      query = {$or: [{userId: data.userId}, {client_id: data.client_id}]}
    else if data.userId
      query = {$and: [{userId: data.userId}, {userId: {$ne: null}}]}
    else if data.client_id
      query = {$and: [{client_id: data.client_id}, {client_id: {$ne: null}}]}

    if opts.honorYear
      query['year'] = data.year

    delete data._id if data._id
    return cb {error: "_id, client_id, or userId required to upsert HuntinFoolState"} unless query

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, huntinFoolState) =>
      return cb err if err
      return cb {error: "HuntinFoolState update/insert failed"} unless huntinFoolState
      cb null, huntinFoolState

  HuntinFoolState = db.model "HuntinFoolState", HuntinFoolStateSchema
