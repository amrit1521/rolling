_ = require "underscore"
moment = require 'moment'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db, logger) ->

  ReminderSchema = new Schema {
    active: Boolean
    title: String
    start: String
    end: String
    #isSheep: Boolean
    state: String
    #startSubject: String
    txtStart: String
    txtEnd: String
    #appStart: String
    #appEnd: String
    #emailStartText: String
    #emailStart: String
    #endSubject: String
    #emailEndText: String
    #emailEnd: String
    #filter: String
    tenantId: ObjectId
    #isDrawResultSuccess: Boolean
    #isDrawResultUnsuccess: Boolean
    testUserId: ObjectId
    #testDrawResultId: ObjectId
    testLastMsg: String
    send_open: Date
    send_close: Date
    validatedOn: Date
    website_link: String
    reminderType: String
  }

  ReminderSchema.statics.byId = (reminderId, cb) ->
    @findOne({_id: reminderId}).exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.byState = (state, cb) ->
    @find({state, end: {$gt: moment().subtract(1, 'days').format('YYYY-MM-DD')}}).sort({end: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.byStates = (states, cb) ->
    @find({state: {$in: states}, end: {$gt: moment().subtract(1, 'days').format('YYYY-MM-DD')}}).sort({end: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.byStatesTenant = (tenantId, states, cb) ->
    @find({tenantId, state: {$in: states}, end: {$gt: moment().subtract(1, 'days').format('YYYY-MM-DD')}}).sort({end: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.byStatesTenantAll = (tenantId, states, cb) ->
    @find({tenantId, state: {$in: states}}).sort({state:1, end: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.index = (cb) ->
    @find({end: {$gt: moment().subtract(1, 'days').format('YYYY-MM-DD')}}).sort({end: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.findAll = (cb) ->
    @find({}).sort({end: -1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.byTenant = (tenantId, activeOnly, cb) ->
    if activeOnly
      query = {tenantId: tenantId, end: {$gt: moment().subtract(1, 'days').format('YYYY-MM-DD')}}
      sort = {end: 1}
    else
      query = {tenantId: tenantId}
      sort = {end: -1}
    @find(query).sort(sort).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.startsOn = (start, tenantId, cb) ->
    if not cb and typeof tenantId is 'function'
      cb = tenantId
      tenantId = null
    return cb 'TenantId is required to retrieve reminders.' unless tenantId
    startDay = moment(start).startOf('day')
    endDay = moment(start).endOf('day')
    @find({tenantId: tenantId, active: true, send_open: {"$gte": startDay, "$lt": endDay}, $and: [{$or: [{isDrawResultSuccess: false}, {isDrawResultSuccess: {$exists:false}}]},{$or: [{isDrawResultUnsuccess: false}, {isDrawResultUnsuccess: {$exists:false}}]}]}).sort({start: 1}).lean().exec (err, reminders) ->
      return cb err, reminders

  ReminderSchema.statics.endsOn = (end, tenantId, cb) ->
    if not cb and typeof tenantId is 'function'
      cb = tenantId
      tenantId = null
    return cb {error: 'TenantId is required to retrieve reminders.'} unless tenantId
    startDay = moment(end).startOf('day')
    endDay = moment(end).endOf('day')
    @find({tenantId: tenantId, active: true, send_close: {"$gte": startDay, "$lt": endDay}, $and: [{$or: [{isDrawResultSuccess: false}, {isDrawResultSuccess: {$exists:false}}]},{$or: [{isDrawResultUnsuccess: false}, {isDrawResultUnsuccess: {$exists:false}}]}]}).sort({end: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.DrawResultsOn = (start, tenantId, cb) ->
    if not cb and typeof tenantId is 'function'
      cb = tenantId
      tenantId = null
    return cb 'TenantId is required to retrieve reminders.' unless tenantId
    @find({start, tenantId: tenantId, $or: [{isDrawResultSuccess: true},{isDrawResultUnsuccess: true}]}).sort({start: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  ReminderSchema.statics.upsert = (data, cb) ->
    reminderId = data._id

    if reminderId
      query = {_id: reminderId} if reminderId
    else
      query = {title: data.title, state: data.state}
      data = _.omit data, 'title', 'state'

    data = _.omit data, '_id', '__v'

    console.log('UPSERT REMINDER:', data);

    @findOneAndUpdate query, data, {upsert: true, new: true}, (err, result) ->
      return cb err if err
      cb null, result

  Reminder = db.model "Reminder", ReminderSchema
