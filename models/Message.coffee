_ = require "underscore"
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db, logger) ->

	ModelSchema = new Schema {
		key: String					# Email Address, or Text Number acting as the unique value used in combination with the type to determine if a message has already been sent to avoid sending duplicate messages.
		type: String				# Used for reporting.  'emailStart', 'emailEnd', 'txtStart', 'txtEnd', 'appStart', 'appEnd'
		source: String			# Name of the collection containing the content for the message. i.e: 'Reminder', 'DrawResult', 'Notification'
		sourceId: ObjectId 	# ObjectId of the object in the source collection
		tenantId: ObjectId
		sent: Date
		state: String
		reminderId: ObjectId
		year: String
		userId: ObjectId
	}

	ModelSchema.index {sent: 1}, {background:true}

	ModelSchema.statics.byUnique = (key, type, year, source, reminderId, tenantId, cb) ->
		return cb {message: "key, type, year, source, reminderId, and tenantId required"} unless key and type and year and source and reminderId and tenantId
		@findOne({key, type, year, source, reminderId, tenantId}).lean().exec()
			.then (result) ->
				cb null, result
			.catch (err) ->
				cb(err)

	ModelSchema.statics.byTenantDateRange = (tenantId, startDate, endDate, cb) ->
		startDate = new Date(startDate) if startDate
		endDate = new Date(endDate) if endDate
		createdAt_s = {sent: {$gte: startDate}}
		createdAt_e = {sent: {$lte: endDate}}
		conditions = {tenantId, $and: [createdAt_s, createdAt_e]}
		@find(conditions, {_id:true}).lean().exec()
			.then (result) ->
				cb null, result
			.catch (err) ->
				cb(err)

	ModelSchema.statics.upsert = (data, cb) ->
		data = data.toObject() if data.toObject
		data = _.omit data, '__v'

		data.sent = new Date() unless data.sent

		query = {_id: {$exists: false}}
		if data?._id
			query = {_id: data._id}
			delete data._id

		@findOneAndUpdate(query, {$set: data}, {upsert: true, new: true}).lean().exec (err, message) ->
			cb err, message

	db.model "Message", ModelSchema
