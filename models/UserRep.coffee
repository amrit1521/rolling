mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed
moment = require "moment"
_ = require 'underscore'
async = require 'async'


module.exports = (db) ->

  UserRepSchema = new Schema {
    createdAt: Date
    modifiedAt: Date
    tenantId: ObjectId
    userId: ObjectId
    rbo_rep0: ObjectId
    rbo_rep1: ObjectId
    rbo_rep2: ObjectId
    rbo_rep3: ObjectId
    rbo_rep4: ObjectId
    rbo_rep5: ObjectId
    rbo_rep6: ObjectId
    rbo_rep7: ObjectId
  }

  UserRepSchema.index {tenantId: 1}, {background:true}
  UserRepSchema.index {userId: 1}, {background:true}
  UserRepSchema.index {rbo_rep0: 1}, {background:true}
  UserRepSchema.index {rbo_rep1: 1}, {background:true}
  UserRepSchema.index {rbo_rep2: 1}, {background:true}
  UserRepSchema.index {rbo_rep3: 1}, {background:true}
  UserRepSchema.index {rbo_rep4: 1}, {background:true}
  UserRepSchema.index {rbo_rep5: 1}, {background:true}
  UserRepSchema.index {rbo_rep6: 1}, {background:true}
  UserRepSchema.index {rbo_rep7: 1}, {background:true}

  UserRepSchema.statics.byId = (id, tenantId, cb) ->
    @findOne({_id: id, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserRepSchema.statics.byUserId = (userId, cb) ->
    @findOne({userId: userId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserRepSchema.statics.byRepId = (rep_userId, cb) ->
    rep0 = {rbo_rep0:rep_userId}
    rep1 = {rbo_rep1:rep_userId}
    rep2 = {rbo_rep2:rep_userId}
    rep3 = {rbo_rep3:rep_userId}
    rep4 = {rbo_rep4:rep_userId}
    rep5 = {rbo_rep5:rep_userId}
    rep6 = {rbo_rep6:rep_userId}
    rep7 = {rbo_rep7:rep_userId}
    query = {
      $or: [rep0, rep1, rep2, rep3, rep4, rep5, rep6, rep7]
    }
    @find(query).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserRepSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject
    data = _.omit data, '__v', '$promise', '$resolved'

    if !data._id
      return cb "tenantId required to save a UserRep" unless data.tenantId
      return cb "userId required to save a UserRep" unless data.userId

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    userRepId = data._id
    delete data._id if data._id
    #data.createdAt = moment() unless userRepId
    #data.modifiedAt = moment()

    #insert new, or update if provided an _id
    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if userRepId
      query = {$and: [{_id: userRepId}, {_id: {$ne: null}}]}

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, userRepEntry) =>
      return cb err if err
      return cb {error: "UserRep update/insert failed"} unless userRepEntry
      return cb null, userRepEntry

  UserRep = db.model "UserRep", UserRepSchema
