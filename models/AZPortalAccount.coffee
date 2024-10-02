mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db, Secure) ->

  expand = (azAcct) ->
    return unless azAcct
    azAcct.azPassword = Secure.decrypt azAcct.azPassword if azAcct.azPassword
    return azAcct

  compress = (azAcct) ->
    return unless azAcct
    azAcct.azPassword = Secure.encrypt azAcct.azPassword if azAcct.azPassword
    return azAcct


  AZPortalAccountSchema = new Schema {
    userId: ObjectId
    clientId: String
    first_name: String
    last_name: String
    tenantId: ObjectId
    azUsername: String
    azPassword: String
    azAcctReqSent: Boolean
    azAcctLoginValidated: Boolean
    azAcctProfilePopulated: Boolean
    azAcctNeedsUpdated: Boolean
    azAcctNeedsReActivated: Boolean
    departmentId: String
    license_expiration: Date
    license_number: String
    license_type: String
    license_departmentId: String
    modified: Date
    notes: String
    updatePortalAccountStatus: String

  }

  AZPortalAccountSchema.statics.index = (tenantId, cb) ->
    @find({}).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
      cb null, results

  AZPortalAccountSchema.statics.findByTenant = (tenantId, cb) ->
    query = {tenantId: tenantId}
    @find(query).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
      cb null, results

  AZPortalAccountSchema.statics.needAZAcct = (tenantId, cb) ->
    query = {tenantId: tenantId, azUsername: {$exists: true}, azPassword: {$exists: true}, $or: [{azAcctReqSent: false}, {azAcctReqSent: {$exists: false}}]}
    @find(query).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
      cb null, results

  AZPortalAccountSchema.statics.validateLogins = (tenantId, skipValidated, cb) ->
    skipValidated = true unless skipValidated
    if skipValidated
      query = {tenantId: tenantId, azUsername: {$exists: true}, azPassword: {$exists: true}, $or: [{azAcctLoginValidated: false}, {azAcctLoginValidated: {$exists: false}}]}
    else
      query = {tenantId: tenantId, azUsername: {$exists: true}, azPassword: {$exists: true}}

    @find(query).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
      cb null, results

  AZPortalAccountSchema.statics.resetPasswords = (tenantId, cb) ->
    query = {tenantId: tenantId, azAcctNeedsReActivated: true}
    @find(query).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
      cb null, results

  AZPortalAccountSchema.statics.byClientId = (clientId, cb) ->
    @findOne({clientId}).exec (err, azAcct) ->
      return cb err, expand(azAcct)

  AZPortalAccountSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject
    data = compress(data)
    data.modified = new Date()

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if data._id
      query = {$and: [{_id: data._id}, {_id: {$ne: null}}]}
    else if data.userId
      query = {$and: [{userId: data.userId}, {userId: {$ne: null}}]}
    else if data.clientId and data.tenantId
      query = {$and: [{clientId: data.clientId}, {tenantId: data.tenantId}]}

    delete data._id if data._id
    delete data["__v"]

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, AZAcct) =>
      return cb err if err
      return cb {error: "AZPortalAccount update/insert failed"} unless AZAcct
      AZAcct = expand(AZAcct)
      cb null, AZAcct


  AZPortalAccount = db.model "AZPortalAccount", AZPortalAccountSchema
