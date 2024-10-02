mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  StateSchema = new Schema {
    state: String
    cid: String
    notes: String
  }


  HuntinFoolUserSchema = new Schema {
    member_id: String
    first_name: String
    last_name: String
    mail_address: String
    mail_city: String
    mail_state: String
    mail_zip: String
    dob: String
    uniqueid: String
    residence: String
    userId: ObjectId
    clientId: String
    states: [StateSchema]

  }

  HuntinFoolUserSchema.statics.index = (cb) ->
    @find({}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolUserSchema.statics.byMemberId = (member_id, cb) ->
    @findOne({member_id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  HuntinFoolUserSchema.statics.addState = (member_id, newState, cb) ->
    @update({member_id}, {$push: {states:newState}}, {multi:false}).lean().exec (err, huntinFoolUser) =>
      return cb err if err
      return cb {error: "HuntinFoolUser state update failed"} unless huntinFoolUser
      cb null, huntinFoolUser

  HuntinFoolUserSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    huntinFoolUserId = data._id
    delete data._id if data._id

    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if data.member_id
      query = {$and: [{member_id: data.member_id}, {member_id: {$ne: null}}]}
    else if data._id
      huntinFoolUserId = data._id
      query = {$and: [{_id: huntinFoolUserId}, {_id: {$ne: null}}]}

    delete data._id if data._id
    return cb {error: "_id or member_id required to upsert HuntinFoolUser"} unless query

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, huntinFoolUser) =>
      return cb err if err
      return cb {error: "HuntinFoolUser update/insert failed"} unless huntinFoolUser
      cb null, huntinFoolUser


  HuntinFoolUser = db.model "HuntinFoolUser", HuntinFoolUserSchema
