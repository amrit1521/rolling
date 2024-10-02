mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.Types.ObjectId
Mixed = Schema.Types.Mixed
moment = require "moment"


module.exports = (db, HuntCatalog) ->


  PurchaseFileSchema = new Schema {
    originalName: String
    extension: String
    mimetype: String
    url: String
    size: String
    encoding: String
  }

  PurchaseOptionsSchema = new Schema {
    title: String             #Group Name
    description: String       #Group Description
    specific_type: String     #Selected Option Name
    available_with: String    #Depricated
    catalog_id: String
    price: Number
    commission: Number        #RBO's commission ($ amount of the option price RBO will keep)
  }

  PaymentsSchema = new Schema {
    createdAt: Date
    name: String
    specific_type: type: String, enum: ['check', 'cash', 'credit card']
    amount: Number
    paidOn: Date
    referenceNumber: String #Either Check #, credit card trans comfirmation number, or other payment identifier
    notes: String
    original_huntCatalogId: ObjectId
    original_invoiceNumber: String
  }


  PurchaseSchema = new Schema {
    tenantId: ObjectId
    userId: ObjectId
    huntCatalogId: ObjectId
    huntCatalogCopy: [HuntCatalog.schema]     #Mongoose hack to cross reference schemas...not really an array, just one
    payments: [PaymentsSchema]
    receipt: String           #URL
    amount: Number            #The $ amount paid on the initial purchase (initial deposit)
    amountTotal: Number       #The Total $ amount of the purchase (includes taxes, shipping, fees, etc.)
    amountPaid: Number        #The total $ payments received to date for this item.
    cart_id: Number           #External Identifier in RRADS db
    orderNumber: String       #Unique Number generated for each cart order processed
    invoiceNumber: String
    applyTo_purchaseId: ObjectId
    applyTo_invoiceNumber: String

    createdAt: Date
    purchaseNotes: String
    paymentMethod: String
    paymentUsed: String       #This will be cc or bank, coming from RRADS
    minPaymentRequired: Number
    basePrice: Number
    price_non_commissionable: Number        #Amount of the outfitter's prices that is non commissionable
    monthlyPayment: Number
    monthlyPaymentNumberMonths: Number
    userIsMember: Boolean
    membershipPurchased: Boolean
    userParentId: ObjectId
    commission: Number        #RBO's commission $ amount
    commissionPercent: Number  #Tenant's commission % amount
    commissionsPaid: Date
    opt_out_subscription: Boolean #If this was as subscription, but they opted out of recurring and it's only 1 payment worth.
    adminNotes: String
    #totalPaidToOutfitter: Number  #Total $ of deposits sent to the outfitter for this item.
    #lastDepositSentToOutfitter: Date
    purchase_confirmed_by_client: Date
    purchase_confirmed_by_outfitter: Date
    confirmation_sent_outfitter: Date
    confirmation_sent_client: Date
    start_hunt_date: Date
    end_hunt_date: Date
    qb_invoice_recorded: Boolean          #RADS invoice recorded in Quickbooks
    qb_expense_bill_recorded: Boolean
    qb_invoice_payment_reconciled: Boolean
    qb_expense_payment_paid: Boolean
    qb_expense_payment_paid_date: Date
    qb_expense_balance_due: Number

    imported: String
    files: [PurchaseFileSchema]

    #RBO custom fields for commissions
    rbo_rep0: ObjectId
    rbo_rep1: ObjectId
    rbo_rep2: ObjectId
    rbo_rep3: ObjectId
    rbo_rep4: ObjectId
    rbo_rep5: ObjectId
    rbo_rep6: ObjectId
    rbo_rep7: ObjectId
    rbo_repOSSP: ObjectId
    rbo_commission_rep0: Number
    rbo_commission_rep1: Number
    rbo_commission_rep2: Number
    rbo_commission_rep3: Number
    rbo_commission_rep4: Number
    rbo_commission_rep5: Number
    rbo_commission_rep6: Number
    rbo_commission_rep7: Number
    rbo_commission_repOSSP: Number

    rbo_rbo1: ObjectId
    rbo_rbo2: ObjectId
    rbo_rbo3: ObjectId
    rbo_rbo4: ObjectId
    rbo_commission_rbo1: Number
    rbo_commission_rbo2: Number
    rbo_commission_rbo3: Number
    rbo_commission_rbo4: Number

    rbo_reps_commission: Number  #This is the amount to the reps only ("commissions" field above is the amount to RBO for the sale)
    rbo_reps_bonus:      Number  #This is the amount of the rbo_reps_commission that is to be applied as a direct bonus
    rbo_reps_bonus_type: String
    rbo_margin:          Number  #comission from outfitter ("commissions") minus paying all the reps (rbo_reps_commission) - overriders
    fee_processing:      Number  #RBO Processing fee NOT included in the outfitter base price OR commissions
    shipping:  Number
    sales_tax:  Number
    sales_tax_percentage: Number
    tags_licenses:  Number
    isSubscription: Boolean

    userSnapShot: String
    repAgreement: String
    options: [PurchaseOptionsSchema]

    refund_amount: Number
    purchase_cancelled: Date
    authorize_automatic_payments: Boolean
    next_payment_date: Date
    next_payment_amount: Number
    status: type: String, enum: ['paid-in-full', 'invoiced', 'transfer', 'check-pending', 'auto-pay-monthly', 'auto-pay-yearly', 'auto-pay-monthly-retry', 'auto-pay-yearly-retry', 'cancelled', 'over_due', 'cc_failed']

    #TODO: MOVE THE FOLLOWING TO A PAYMENTS COLLECTION. (think about if move or just payments array?)
    check_number: String
    check_name: String
    cc_transId: String
    cc_subscriptionId: String
    cc_responseCode: String
    cc_messageCode: String
    cc_description: String
    cc_accountNum: String
    cc_name: String
    cc_email: String
    cc_phone: String
    cc_number: String
    user_payment_customerProfileId: String
    user_payment_paymentProfileId: String
    #receipt
    #paymentMethod
    #notes
    #purchaseId
    #userId
    #tenantId
  }

  PurchaseSchema.index {userId: 1}, {background:true}
  PurchaseSchema.index {userParentId: 1}, {background:true}
  PurchaseSchema.index {tenantId: 1}, {background:true}
  PurchaseSchema.index {huntCatalogId: 1}, {background:true}
  PurchaseSchema.index {paymentMethod: 1}, {background:true}
  PurchaseSchema.index {rbo_rep0: 1}, {background:true}
  PurchaseSchema.index {rbo_rep1: 1}, {background:true}
  PurchaseSchema.index {rbo_rep2: 1}, {background:true}
  PurchaseSchema.index {rbo_rep3: 1}, {background:true}
  PurchaseSchema.index {rbo_rep4: 1}, {background:true}
  PurchaseSchema.index {rbo_rep5: 1}, {background:true}
  PurchaseSchema.index {rbo_rep6: 1}, {background:true}
  PurchaseSchema.index {rbo_rep7: 1}, {background:true}
  PurchaseSchema.index {rbo_repOSSP: 1}, {background:true}
  PurchaseSchema.index {rbo_rbo1: 1}, {background:true}
  PurchaseSchema.index {rbo_rbo2: 1}, {background:true}
  PurchaseSchema.index {rbo_rbo3: 1}, {background:true}


  PurchaseSchema.statics.byId = (id, tenantId, cb) ->
    @findOne({_id: id, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byIdIgnoreTenant = (id, cb) ->
    @findOne({_id: id}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byIdsTenant = (idList, tenantId, cb) ->
    @find({_id: {$in: idList}, tenantId}).lean().exec (err, results) ->
      return cb err if err
      cb null, results

  PurchaseSchema.statics.byHuntCatalogId = (huntCatalogId, tenantId, cb) ->
    @find({huntCatalogId, tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byUserId = (userId, tenantId, cb) ->
    @find({userId, tenantId}).sort({'createdAt': -1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byUserIdIgnoreTenant = (userId, cb) ->
    @find({userId}).sort({'createdAt': -1}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byUserIds = (tenantId, userIds, startDate, endDate, cb) ->
    createdAt_s = {createdAt: {$gte: startDate}} if startDate
    createdAt_e = {createdAt: {$lte: endDate}} if endDate
    query = {
      tenantId: tenantId
      userId: {$in: userIds}
      $and: [createdAt_s, createdAt_e] if createdAt_s and createdAt_e
    }
    @find(query).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byOrderNumber = (orderNumber, tenantId, cb) ->
    @find({orderNumber, orderNumber}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byInvoiceNumber = (invoiceNumber, tenantId, cb) ->
    @findOne({invoiceNumber, invoiceNumber, tenantId: tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byTenant = (tenantId, cb) ->
    @find({tenantId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byOutfitter = (outfitterId, tenantId, cb) ->
    @find({tenantId, "huntCatalogCopy.outfitter_userId": outfitterId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byDateRange = (tenantId, startDate, endDate, cb) ->
    createdAt_s = {createdAt: {$gte: startDate}}
    createdAt_e = {createdAt: {$lte: endDate}}
    conditions = {tenantId, $and: [createdAt_s, createdAt_e]}
    if !tenantId? or tenantId is "all"
      delete conditions.tenantId
    @find(conditions).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byDateRangeQB = (tenantId, filter_qb_invoice, filter_qb_expense, balances_due_only, startDate, endDate, cb) ->
    createdAt_s = {createdAt: {$gte: startDate}}
    createdAt_e = {createdAt: {$lte: endDate}}
    filter_qb_invoice_q = {qb_invoice_recorded: {$in: [null, false]}}
    filter_qb_expense_q = {qb_expense_bill_recorded: {$in: [null, false]}}
    filter_balances_due_only_q = {qb_expense_payment_paid: {$in: [null, false]}}
    filter_qb_expenses_type_q = [{"huntCatalogCopy.type": "hunt"},{"huntCatalogCopy.type": "product"},{"huntCatalogCopy.type": "payment_hunt"}]
    and_query = [createdAt_s, createdAt_e]
    and_query.push filter_qb_invoice_q if filter_qb_invoice
    and_query.push filter_qb_expense_q if filter_qb_expense and !balances_due_only
    and_query.push filter_balances_due_only_q if balances_due_only
    if filter_qb_expense or balances_due_only
      conditions = {tenantId, $and: and_query, $or: filter_qb_expenses_type_q}
    else
      conditions = {tenantId, $and: and_query}
    if !tenantId? or tenantId is "all"
      delete conditions.tenantId

    #conditions = {invoiceNumber: "RBI2174"} for testing
    console.log "Alert: conditions: ", JSON.stringify conditions
    @find(conditions).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byStatusNextPaymentDate = (status, tDate, tenantId, cb) ->
    return cb "tenantId is required" unless tenantId
    return cb "tDate is required" unless tDate
    start = tDate.clone().startOf('day')
    end = tDate.clone().endOf('day')
    @find({status: status, next_payment_date: {'$gte':start, '$lte':end}, tenantId}).lean().exec (err, results) ->
      return cb err, results

  PurchaseSchema.statics.byParent = (tenantId, userParentId, cb) ->
    @find({tenantId, userParentId}).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.byRepAny = (tenantId, repId, startDate, endDate, cb) ->
    createdAt_s = {createdAt: {$gte: startDate}}
    createdAt_e = {createdAt: {$lte: endDate}}
    query = {
      tenantId: tenantId
      $and: [createdAt_s, createdAt_e]
      $or: [
        {"rbo_rep0": repId},
        {"rbo_rep1": repId},
        {"rbo_rep2": repId},
        {"rbo_rep3": repId},
        {"rbo_rep4": repId},
        {"rbo_rep5": repId},
        {"rbo_rep6": repId},
        {"rbo_rep7": repId},
        {"rbo_repOSSP": repId},
        #{"rbo_rbo1": repId},
        #{"rbo_rbo2": repId},
        #{"rbo_rbo3": repId}
      ]
    }
    @find(query).lean().exec()
      .then (result) ->
        cb null, result
      .catch (err) ->
        cb(err)

  PurchaseSchema.statics.updateCommPaidDate = (tenantId, paidDate, purchaseIds, cb) ->
    return cb "tenantId required" unless tenantId
    return cb "paidDate required" unless paidDate
    return cb "purchaseIds required" unless purchaseIds
    query = {
      tenantId: tenantId
      "_id" : { $in: purchaseIds }
    }
    set = {
      "commissionsPaid" : paidDate
    }
    opts = {
      upsert: false
      multi: true
    }
    @update query, set, opts, cb


  PurchaseSchema.statics.upsert = (data, opts, cb) ->
    data = data.toObject() if data.toObject

    if !data._id
      return cb "tenantId required to save a purchase" unless data.tenantId
      return cb "userId required to save a purchase" unless data.userId
      return cb "huntCatalogId required to save a purchase" unless data.huntCatalogId
      return cb "amount required to save a purchase" unless data.amount?
      return cb "paymentMethod required to save a purchase" unless data.paymentMethod

    if not cb and typeof opts is 'function'
      cb = opts
      opts = {
        query: null
        upsert: true
      }

    opts.upsert ?= true

    purchaseId = data._id
    delete data._id if data._id
    data.createdAt = moment() unless purchaseId

    #insert new, or update if provided an _id
    query = {_id: {$exists: false}}
    if opts.query
      query = opts.query
    else if purchaseId
      query = {$and: [{_id: purchaseId}, {_id: {$ne: null}}]}

    @findOneAndUpdate(query, {$set: data}, {upsert: opts.upsert, new: true}).lean().exec (err, purchase) =>
      return cb err if err
      return cb {error: "Purchase update/insert failed"} unless purchase
      cb null, purchase

  Purchase = db.model "Purchase", PurchaseSchema
