_ = require 'underscore'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed

module.exports = (db) ->

  HuntChoiceSchema = new Schema {
    choices: Mixed
    hunt: String
    preferecePoint: Boolean
    huntId: ObjectId
    stateId: ObjectId
    userId: ObjectId
  }

  HuntChoiceSchema.statics.byUserHunt = (userId, huntId, cb) ->
    @findOne {huntId, userId}, cb

  HuntChoiceSchema.statics.members = (groupId, huntId, cb) ->
    @find({huntId, "choices.group_id": groupId}, {"userId":1}).lean().exec (err, results) ->
      return cb err if err
      cb null, _.pluck results, 'userId'

  HuntChoiceSchema.statics.removeByHuntCID = (huntId, cid, cb) ->
    return cb {error: "Removing of previous groups requires a valid hunt id"} unless huntId?.length
    return cb {error: "Removing of previous groups requires a valid group id"} unless cid?.length

    @remove({"choices.group_id": cid, huntId}).exec (err) ->
      cb err

  HuntChoiceSchema.statics.removeByUserHuntIds = (userId, huntIds, cb) ->
    return cb {error: "Removing of hunt choices by hunt ids requires huntIds"} unless huntIds?.length
    @remove({userId, huntId: { $in: huntIds}}).exec (err) ->
      cb err

  HuntChoiceSchema.statics.upsert = (data, cb) ->
    delete data._id if data._id
    @update {userId: data.userId, huntId: data.huntId}, data, {upsert: true}, (err) ->
      return cb err if err
      cb null, data

  HuntChoice = db.model "HuntChoice", HuntChoiceSchema
