mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db) ->

  TenantSchema = new Schema {
    isActive: Boolean
    commission: Number
    domain: String
    logo: String
    name: String
    url: String
    ssl_issuer: String
    ssl_key: String
    ssl_pem: String
    referralPrefix: String
    clientPrefix: String
    clientId_seq: { type: Number, default: 1 }
    cc_fee_percent: Number
    invoiceNumber_seq: { type: Number, default: 1 }
    logAPI: Boolean
    rrads_api_base_url: String
    rrads_use_production_token: Boolean
    email_from: String
    email_from_name: String
    email_template_prefix: String
    disableReps: Boolean
    whitelabelHuntsOnly: Boolean
  }

  TenantSchema.statics.delete = (id, cb) ->
    @findOne {_id: id}, (err, tenant) ->
      return cb err if err
      return cb 'Not Found' unless tenant

      tenant.remove (err) ->
        return cb err if err
        cb()

  TenantSchema.statics.findById = (id, cb) ->
    console.log "DEBUG: Tenant.coffee findbyID()...", id
    @findOne({_id: id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantSchema.statics.findByDomain = (domain, cb) ->
    search = new RegExp domain, 'i'
    @findOne({domain: search}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantSchema.statics.index = (cb) ->
    @find({}).sort({name:1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantSchema.statics.all = (type, cb) ->
    if type is "all"
      @find({}).sort({name:1}).lean().exec()
        .then (result) ->
          cb null, result
        .catch (err) ->
          cb(err)
    else
      @find({isActive: true}).sort({name:1}).lean().exec()
        .then (result) ->
          cb null, result
        .catch (err) ->
          cb(err)

  TenantSchema.statics.findByReferralPrefix = (prefix, cb) ->
    search = new RegExp prefix, 'i'
    console.log("SEARCH", search)
    @findOne({referralPrefix: search}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantSchema.statics.findByClientPrefix = (prefix, cb) ->
    search = new RegExp prefix, 'i'
    console.log("SEARCH", search)
    @findOne({clientPrefix: search}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  TenantSchema.statics.getNextClientId = (id, cb) ->
    query = {_id: id}
    data = { $inc: {clientId_seq:1} }
    options = {
      new: true,
      upsert: false
    }
    @findOneAndUpdate query, data, options, (err, tenant) ->
      if err
        return cb err
      if not tenant
        return cb "Tenant Not Found for id: #{id}"
      cb null, tenant.clientId_seq

  TenantSchema.statics.getNextInvoiceNumber = (tenantId, cb) ->
    query = {_id: tenantId}
    data = { $inc: {invoiceNumber_seq:1} }
    options = {
      new: true,
      upsert: false
    }
    @findOneAndUpdate query, data, options, (err, tenant) ->
      if err
        return cb err
      if not tenant
        return cb "Tenant Not Found for id: #{tenantId}"
      invoiceNumber = tenant.invoiceNumber_seq
      invoiceNumber = "#{tenant.clientPrefix}I#{tenant.invoiceNumber_seq}" if tenant.clientPrefix
      cb null, invoiceNumber

  Tenant = db.model "Tenant", TenantSchema
