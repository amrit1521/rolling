_ = require 'underscore'
async = require 'async'
moment = require 'moment'
mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId

module.exports = (db, Secure, logger) ->

  privateFields = [
    'field1'
    'field2'
    'field3'
    'field4'
    'field5'
    'field6'
    'field7'
    'field8'
    'field9'
    'field10'
    'field11'
    'field12'
    'field13'
  ]

  addSetters = (user) ->
    isModel = false
    if typeof user?.get is 'function'
      isModel = true
    else
      user.get = (key) ->
        user[key]
      user.set = (key, value) ->
        if typeof key is 'string'
          user[key] = value
        else
          for index, val of key
            user.set index, val if key.hasOwnProperty(index)
        value

    isModel

  cleanupSetters = (isModel, user) ->
    if not isModel
      delete user.get
      delete user.set

    user

  sanitize = (user) ->
    return unless user

    isModel = addSetters(user)

    user.set 'ssn', ('' + user.ssn).replace(/[^\d]/g, '').substr(-4) if user?.ssn

    c1 = if user.get('field8')?.length then user.get('field8') else ''
    c2 = if user.get('field13')?.length then user.get('field13') else ''
    user.set 'postal2', "#{c1} #{c2}"

    userObj = if user.toObject then user.toObject() else _.clone(user)
    for key of userObj
      continue if key in ['get', 'set']
      user.set key, undefined

    userObj = _.omit userObj, privateFields
    user.set userObj


    cleanupSetters(isModel, user)

  expand = (user) ->
    return unless user
    isModel = addSetters(user)
    parts = [user.get('field1'), user.get('field2')]
    return cleanupSetters(isModel, user) unless parts[0]
    #results = Secure.desocial parts
    #{social, dob} = results
    #user.set 'ssn', social
    #user.set 'dob', dob
    cleanupSetters(isModel, user)

  compress = (user) ->
    return unless user
    isModel = addSetters(user)
    #user.set 'ssn', ('' + user.ssn).replace(/[^\d]/g, '') if user?.ssn
    #user.set 'dob', moment(user.dob, 'YYYY-MM-DD').format('YYYY-MM-DD') if user.dob
    #[field1, field2] = Secure.social user.get('ssn'), user.get('dob')
    #user.set 'field1', field1
    #user.set 'field2', field2
    #user.set 'ssn', ('' + user.ssn).substr -4 if user?.ssn
    cleanupSetters(isModel, user)


  UserDeviceSchema = new Schema {
    deviceId: String
    platform: String
    token: String
  }

  UserFileSchema = new Schema {
    originalName: String
    extension: String
    mimetype: String
    url: String
    size: String
    encoding: String
  }

  UserSchema = new Schema {
    active: Boolean
    clientId: String
    linked_userId: ObjectId
    commission: String
    contractEnd: Date
    createdAt: Date
    demo: Boolean
    devices: [UserDeviceSchema]
    dob: String
    drivers_license: String
    dl_state: String
    dl_issued: String
    email: String
    eyes: String

    payment_customerProfileId: String
    payment_paymentProfileId: String
    payment_recurring_paymentProfileId: String
    qb_customer_id: String

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

    files: [UserFileSchema]

    group_outfitterIds: [ObjectId]

    first_name: String
    gender: String
    hair: String
    heightFeet: String
    heightInches: String
    hunter_safety_number: String
    hunter_safety_type: String
    hunter_safety_state: String
    alaska_license: String
    alaska_license_year: String
    idaho_license: String
    idaho_license_year: String

    isAdmin: Boolean
    isMember : Boolean
    isRep : Boolean
    userType: String

    isOSSCertified: Boolean

    payment_form_sent: Date
    payment_form_received: Date

    isOutfitter: Boolean
    outfitter_vetted_by: String
    outfitter_vetted_date: Date

    isVendor: Boolean
    vendor_contact_name: String
    vendor_contact_email: String
    vendor_contact_phone: String
    vendor_vetted_by: String
    vendor_vetted_date: Date
    vendor_pricing_confirmed: Date
    vendor_shipping_method: String
    vendor_rbo_payment_process: String, enum: ['Net 30', 'Due on Receipt', 'Trade']
    vendor_rbo_payment_method: String, enum: ['invoice', 'cc on file']
    vendor_rbo_order_process: String
    vendor_rbo_order_confirmed_process: String
    vendor_rbo_return_process: String
    vendor_isFeatured: Boolean
    vendor_external_link: String

    imported: type: String
    internalNotes: String
    last_name: String
    locale: String
    needsWelcomeEmail: Boolean
    needsPointsEmail: Boolean
    needs_sync_nrads_rrads: Boolean

    mail_address: String
    mail_city: String
    mail_country: String
    mail_postal: String
    mail_state: String

    memberId: String
    memberType: String
    memberExpires: Date
    memberStarted: Date
    memberStatus: String
    membership_next_payment_amount: Number
    repExpires: Date
    repStarted: Date
    repType: String
    repAgreement: String
    repStatus: String
    rep_next_payment: Date
    rep_next_payment_amount: Number

    middle_name: String
    name: String
    occupation: String

    parentId: ObjectId
    parent_memberId: String
    parent_clientId: String
    password: String
    phone_cell: String
    phone_cell_carrier: String
    phone_day: String
    phone_home: String

    business_phone: String #todo: implement this field
    business_email: String #todo: implement this field

    physical_address: String
    physical_city: String
    physical_country: String
    physical_postal: String
    physical_state: String

    shipping_address: String
    shipping_city: String
    shipping_country: String
    shipping_postal: String
    shipping_state: String

    billing_address: String
    billing_city: String
    billing_country: String
    billing_postal: String
    billing_state: String

    powerOfAttorney: Boolean
    form_w9: Date #todo: implement this field
    form_direct_deposit: Date #todo: implement this field

    reminders: {
      email: Boolean
      inApp: Boolean
      text: Boolean
      stateswpoints: Boolean

      types: [String]
      states: [String]
    }
    subscriptions: {
      hunts: Boolean
      products: Boolean
      newsletters: Boolean
      rifles: Boolean
    }

    referredBy: String
    referral: {
      referId: ObjectId
      ip: String
      modified: Date
      referrer: String
      refer_parent_clientId: String
      refer_campaign: String
    }


    residence: String
    res_months: Number
    res_years: Number
    source: String
    ssn: String
    status: String
    suffix: String
    tenantId: ObjectId
    timestamp: type: Date, "default": Date.now, index: true
    type: String
    modified: Date
    username: String
    weight: String
    welcomeEmailSent: Date
    pointsEmailSent: Date

    azUsername: String
    azPassword: String
    coUsername: String
    coPassword: String
    idUsername: String
    idPassword: String
    mtUsername: String
    mtPassword: String
    nmUsername: String
    nmPassword: String
    nvUsername: String
    nvPassword: String
    sdUsername: String
    sdPassword: String
    waUsername: String
    waPassword: String

    dl_is_new: Boolean

  }

  UserSchema.statics.defaultPassword = (user, cb) ->
    return cb "failed to set default password, missing user._id is required." unless user._id
    pwd = ""
    pwd = user.first_name.substring(0,1).toLowerCase() if user?.first_name?.length
    pwd = "#{pwd}#{user._id.toString().substr(0,4)}"
    pwd = "#{pwd}#{user._id.toString().substr(-3,3)}"
    return cb null, pwd

  UserSchema.statics.byId = (id, opts, cb) ->
    if not cb and typeof opts is "function"
      cb = opts
      opts = {}

    @findOne({_id: id}).exec (err, user) ->
      user = expand(user)
      user = sanitize(user) unless opts.internal
      return cb null, user

  UserSchema.statics.byIds = (idList, opts, cb) ->
    @find({_id: {$in: idList}}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      cb null, results

  UserSchema.statics.byIdsTenant = (idList, tenantId, opts, cb) ->
    console.log "User::byIdsTenant tenantId:", tenantId
    @find({_id: {$in: idList}, tenantId}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      cb null, results


  UserSchema.statics.byApplyForMe = (tenantId, opts, cb) ->
    return cb "teantId is required" unless tenantId
    @find({powerOfAttorney: true, tenantId}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts?.internal
      cb null, results

  UserSchema.statics.repRenewalsByDate = (tDate, tenantId, opts, cb) ->
    return cb "tenantId is required" unless tenantId
    return cb "tDate is required" unless tDate
    if not cb and typeof opts is "function"
      cb = opts
      opts = {}
    start = tDate.clone().startOf('day')
    end = tDate.clone().endOf('day')
    @find({rep_next_payment: {'$gte':start, '$lte':end}, tenantId}).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts?.internal
      cb null, results

  UserSchema.statics.membershipExpiredByDate = (tDate, tenantId, opts, cb) ->
    return cb "tenantId is required" unless tenantId
    if not cb and typeof opts is "function"
      cb = opts
      opts = {}
    start = tDate.clone().startOf('day')
    end = tDate.clone().endOf('day')
    @find({memberExpires: {'$gte':start, '$lte':end}, isMember: true, tenantId}).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts?.internal
      cb null, results


  UserSchema.statics.matchNVUser = (first_name, last_name, city, cb) ->
    return cb {error: 'first_name required'} unless first_name
    return cb {error: 'last_name required'} unless last_name
    return cb {error: 'city required'} unless city
    @find({ "first_name" : {$regex : new RegExp(first_name, "i")}, "last_name" : {$regex : new RegExp(last_name, "i")},  $or: [ {"mail_city" : {$regex : new RegExp(city, "i")}},{"physical_city" : {$regex : new RegExp(city, "i")}}]}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i])

      cb null, results

  UserSchema.statics.matchUser = (fields, data, tenantId, cb) ->
    cb "teantId is required" unless tenantId
    conditions = {tenantId: tenantId}
    for field in fields
      return cb {error: "#{field} required"} unless data[field]
      #conditions[field] = data[field]
      conditions[field] = {$regex : new RegExp(data[field], "i")}

    @find(conditions).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i])
      cb null, results

  # User.byReminderStates states, (err, users) ->
  UserSchema.statics.byReminderStates = (states, opts, cb) ->
    @find({"reminders.states": {$in: states}}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      cb null, results

  UserSchema.statics.idsByReminderStates = (reminderType, states, tenantId, opts, cb) ->
    if reminderType is "email"
      remiderTypeFlag = "reminders.email"
    else if reminderType is "text"
      remiderTypeFlag = "reminders.text"
    else
      return cb "Missing valid type.  Must be 'email', or 'text'"

    @find({"reminders.states": {$in: states}, "#{remiderTypeFlag}": true, tenantId: tenantId}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      cb null, results

  UserSchema.statics.byNewUsers = (tenantId, cb) ->
    cb "teantId is required" unless tenantId
    @find({needsWelcomeEmail: true, tenantId}).lean().exec (err, results) ->
      return cb err if err
      cb null, results

  UserSchema.statics.byNeedPointsEmail = (tenantId, cb) ->
    cb "teantId is required" unless tenantId
    @find({needsPointsEmail: true, tenantId}).lean().exec (err, results) ->
      return cb err if err
      cb null, results

  UserSchema.statics.cards = (userId, cb) ->
    @findOne({_id: userId}).lean().exec (err, user) ->
      return cb err if err

      cards = {}
      cards['1'] = user.field8 if user.field8?.length
      cards['2'] = user.field13 if user.field13?.length

      cb null, cards

  UserSchema.statics.children = (userId, opts, cb) ->
    @find({parentId: userId}).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal
      cb null, results

  UserSchema.statics.findByEmail = (email, tenantId, opts, cb) ->

    search = new RegExp('^' + email.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + '$', 'i')
    # console.log 'f'
    # console.log 'emaiil id ',email
    # console.log 'tenatid',tenantId
    # //check
    @findOne({type: "local", email: email, tenantId: {$in: [tenantId, null]}}).lean().exec (err, user) ->
    # @findOne({type: "local", email: email}).lean().exec (err, user) ->
      return cb err if err

      user = expand(user)
      user = sanitize(user) unless opts.internal

      return cb null, user

  UserSchema.statics.findByUserType = (userType, tenantId, opts, cb) ->
    @find({userType: userType, tenantId: tenantId}).lean().exec (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal
      cb null, results

  UserSchema.statics.findByEmailOrUsername = (email, username, tenantId, opts, cb) ->
    searchEmail = new RegExp('^' + email.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + '$', 'i')
    searchUsername = new RegExp('^' + username.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + '$', 'i')

    conditions = {$or: [{email: searchEmail}, {username: searchUsername}]}
    conditions['tenantId'] = tenantId
    conditions['type'] = "local"

    @find(conditions).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      return cb null, results

  UserSchema.statics.findByEmailOrUsernamePassword = (email, username, password, tenantId, opts, cb) ->
    # searchEmail = new RegExp('^' + email.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + '$', 'i')
    # searchUsername = new RegExp('^' + username.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + '$', 'i')
    console.log 'emailg',email
    console.log 'usernameh',username
    
    tenantId = mongoose.Types.ObjectId(tenantId) if typeof tenantId is 'string'
    console.log 'tenant idn',tenantId
    conditions = {
      $and: [
        { $or: [{email: email}, {username: username}] },
        { password: password},
        #  $or: [{tenantId: tenantId}, {$and: [ {tenantId: {$exists:false}}, {isAdmin:true}]}]}
        {$and: [{isAdmin:true}]}
      ]
    }
    #conditions['type'] = "local"

    @findOne(conditions).lean().exec (err, user) ->
      return cb err if err

      user = expand(user)
      user = sanitize(user) unless opts.internal

      return cb null, user

  UserSchema.statics.findById = (userId, opts, cb) ->
    if not cb
      cb = opts
      opts = {}

    return cb {error: 'User id required'} unless userId

    @findOne({_id: userId}).lean().exec (err, user) ->
      return cb err if err
      return cb 'NOTFOUND' unless user

      user = expand(user)
      user = sanitize(user) unless opts.internal

      return cb null, user

  UserSchema.statics.findByName = (search, tenantId, opts, cb) ->
    searchParts = search.split(/\s+/)
    searches = for part in searchParts
      RegExp part, 'i'

    conditions = {$or: [{first_name: {$in: searches}}, {last_name: {$in: searches}}]}
    conditions['tenantId'] = tenantId if tenantId
    conditions['isOutfitter'] = true if opts.outfittersOnly

    logger.info "search conditions: ", conditions

    @find(conditions).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      if opts.allusers
        return cb null, results

      #Filter outfitters if this isn't an outfitter search.  For backwards compatibility
      if !opts.outfittersOnly
        tResults = []
        for result in results
          tResults.push result unless result.isOutfitter
        results = tResults

      return cb null, results

  UserSchema.statics.findByNameAndParent = (search, tenantId, parentId, opts, cb) ->
    return cb "parentId is required when doing this search." unless tenantId
    searchParts = search.split(/\s+/)
    searches = for part in searchParts
      RegExp part, 'i'

    conditions = {$or: [{first_name: {$in: searches}}, {last_name: {$in: searches}}]}
    conditions['tenantId'] = tenantId if tenantId
    conditions['parentId'] = parentId
    conditions['isOutfitter'] = true if opts.outfittersOnly

    logger.info "search conditions: ", conditions

    @find(conditions).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      #Filter outfitters if this isn't an outfitter search
      if !opts.outfittersOnly
        tResults = []
        for result in results
          tResults.push result unless result.isOutfitter
        results = tResults

      return cb null, results

  UserSchema.statics.byMemberId = (memberId, tenantId, cb) ->
    @findOne({memberId, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.byClientId = (clientId, tenantId, cb) ->
    @findOne({clientId: clientId, tenantId: tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.byParentId = (parentId, cb) ->
    @find({parentId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.byClientIdOrMemberId = (clientId, memberId, tenantId, cb) ->
    if clientId and memberId
      query = {$or: [{clientId: clientId}, {memberId: memberId}]}
    else if clientId
      query = {$and: [{clientId: clientId}, {clientId: {$ne: null}}]}
    else if memberId
      query = {$and: [{memberId: memberId}, {memberId: {$ne: null}}]}
    else
      cb {error: "byClientIdOrMemberId() clientId or memberId is required."}
    @findOne(query).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.findByTenant = (tenantId, opts, cb) ->
    handleResults = (err, results) ->
      return cb err if err
      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal
      return cb null, results

    if opts.sort
      @find({tenantId}).sort(opts.sort).lean().exec (err, results) ->
        handleResults err, results
    else
      @find({tenantId}).lean().exec (err, results) ->
        handleResults err, results


  UserSchema.statics.index = (cb) ->
    @find().sort({last_name: 1, first_name: 1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.expand = (user) ->
    user = expand(user)
    return user

  UserSchema.statics.nameList = (list, cb) ->
    @find({_id: {$in: list}}, {"first_name":1, "last_name":1, "name":1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.getTestUsers = (tenantId, sort, cb) ->
    if not cb and typeof sort is "function"
      cb = sort
      sort = {first_name:1}
    @find({$or: [{$and: [{tenantId: tenantId}, {isAdmin: true}]}, {$and: [{isAdmin: true}, {tenantId: {$exists: false}}]}]}, {"first_name":1, "last_name":1, "email":1, "clientId":1}).sort(sort).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  UserSchema.statics.byClientId = (clientId, opts, cb) ->
    @findOne({clientId}).lean().exec (err, user) ->
      cb err if err

      user = expand(user)
      user = sanitize(user) unless opts.internal

      cb null, user

  UserSchema.statics.byClientIds = (clientIds, opts, cb) ->
    @find({clientId: {$in: clientIds}}).lean().exec (err, results) ->
      return cb err if err

      for i of results
        results[i] = expand(results[i])
        results[i] = sanitize(results[i]) unless opts.internal

      cb null, results

  UserSchema.statics.updatePassword = (userId, password, cb) ->

    @findOne({_id: userId}).exec (err, user) ->
      return cb err if err

      user.set 'password', password
      user.save (err) ->
        return cb err if err
        cb()

  UserSchema.statics.updateStatePassword = (userId, field, password, cb) ->

    @findOne({_id: userId}).exec (err, user) ->
      return cb err if err

      user.set field, Secure.encrypt password
      user.save (err) ->
        return cb err, user

  UserSchema.statics.updateReminders = (userId, reminders, cb) ->
    @findOne({_id: userId}).exec (err, user) ->
      return cb err if err

      user.set 'reminders', reminders
      user.save (err) ->
        return cb err if err
        cb()

  UserSchema.statics.updateCards = (userId, data, cb) ->
    @findOne({_id: userId}).exec (err, user) ->
      return cb err if err
      return cb {error: "no data"} unless data

      user.set 'field4', data.field4 if data.field4
      user.set 'field5', data.field5 if data.field5
      user.set 'field6', data.field6 if data.field6
      user.set 'field7', data.field7 if data.field7
      user.set 'field8', data.field8 if data.field8
      user.set 'field9', data.field9 if data.field9
      user.set 'field10', data.field10 if data.field10
      user.set 'field11', data.field11 if data.field11
      user.set 'field12', data.field12 if data.field12
      user.set 'field13', data.field13 if data.field13
      user.save (err) ->
        return cb err if err
        cb()

  UserSchema.statics.addDevice = (userId, device, cb) ->
    @findOne({_id: userId}).exec (err, user) =>
      return cb err if err
      return cb "missing required field device" unless device

      addDevice = true
      if user.devices?.length
        for tDevice in user.devices
          if tDevice.deviceId is device.deviceId
            addDevice = false
            break
      if addDevice
        query = {_id: user._id}
        @findOneAndUpdate query, {$push: devices: device}, {upsert: false, new: true}, cb
      else
        console.log "Device Id already exists, skipping update."
        cb null, null

  UserSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject
    data = _.omit data, '__v', '$promise', '$resolved'

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    async.waterfall [

      # Find current user
      (next) =>
        userId = data._id
        delete data._id if data._id
        if opts.query
          query = opts.query
        else if userId
          query = {_id: userId}
        else
          return next()

        # Preserve ssn
        delete data.ssn if not data.ssn or data.ssn.length < 6

        # Catch moment.format() Invalid dates
        delete data.dob if data.dob == 'Invalid date'
        delete data.dob if data.dob == '0000-00-00'

        # Don't lose devices.  For now, we don't have a user.upsert that will remove them, and we do have a bug that tries to udpate it to empty array.
        delete data.devices if not data?.devices?.length
        console.log 'query',query
        # @findOne({ email: 'developer@verdadtech.com' }).lean().exec
        #   .then (result) ->
        #     next null, result
        #   .catch (err) ->
        #     next(err)

        # @findOne({ email: 'developer@verdadtech.com' }).lean().exec (err, result) ->
        # return next(err) if err
        # next null, result
        @findOne(query).lean().exec((err, result) ->
          return next(err) if err
          next(null, result)
)



      (user, next) =>

        if not next
          next = user
          user = null

        if user
          user = expand(user)
          data.dob = user.dob if user.dob and not data.dob
          data.ssn = user.ssn if user.ssn and not data.ssn

        allowDeletedFields = ['repExpires','memberExpires', 'rep_next_payment']
        for key, value of data
          delete data[key] if typeof value is 'undefined' and allowDeletedFields.indexOf(key) is -1

        data = compress(data)

        query = {_id: {$exists: false}}
        if opts.query
          query = opts.query
        else if user?._id
          query = {_id: user._id}

        @findOneAndUpdate query, {$set: data}, {upsert: opts.upsert, new: true}, next

    ], (err, user) ->
      return cb err if err
      cb null, user

  User = db.model "User", UserSchema