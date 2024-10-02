_ = require "underscore"
async = require "async"
apn = require "apn"
crypto = require "crypto"
DOMParser = require('xmldom').DOMParser
gcm = require "node-gcm"
moment = require "moment"
request = require "request"
URL = require "url"
xpath = require("xpath")

module.exports = (User, Purchase, UserRep) ->

  Reports = {
    adminUsers: (req, res) ->
      console.log 'admin user'
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Admin user required'}, 400 unless req?.user?.isAdmin

      quicksearch = req.param 'quicksearch'

      returnUsers = (users) =>
        #Filter out empty users
        validUses = []
        for tUser in users
          if tUser.userType is "super_admin" and req.user.userType isnt "super_admin"
            continue
          tHasReminders = false
          tReminderStates = tUser.reminders.states.join(",") if tUser.reminders?.states
          tHasReminders = true if tReminderStates and tReminderStates.trim() != "Colorado"
          validUses.push tUser if tHasReminders or tUser.first_name or tUser.last_name or tUser.name or tUser.email or tUser.mail_postal or tUser.physical_postal
        users = validUses
        parentUsersIndex = []
        for tUser in users
          parentUsersIndex[tUser._id] = tUser

        addUser = (users) =>
          (user, done) =>
            #Add any calculated field and logic here
            err = null
            user = @sanitizeUserFields(user)
            user.reminderStates = user.reminders.states.join(",") if user.reminders?.states
            user.isAppUser = true if user.devices?.length
            user.platform = user.devices[0].platform if user.devices?.length > 0 and user.devices[0].platform
            if !user.created
              timestamp = user._id.toString().substring(0,8)
              createdDate = new Date( parseInt( timestamp, 16 ) * 1000 )
              user.created = createdDate

            if (user.parentId)
              parentUser = parentUsersIndex[user.parentId]
              parentUser = _.pick(parentUser,'_id','name','first_name','last_name','clientId','email')
              if parentUser
                keys = _.keys(parentUser)
                for key in keys
                  user["parent_#{key}"] = parentUser[key] if parentUser[key]

            return done err, user

        async.mapSeries users, addUser(users), (err, users) ->
          return res.json err, 500 if err
          res.json users

      if quicksearch?.length
        opts = {internal: false, allusers: true}
        User.findByName quicksearch, req.tenant._id, opts, (err, users) ->
          return res.json err, 500 if err
          returnUsers users
      else
        User.findByTenant req.tenant._id, {internal: false}, (err, users) =>
          return res.json err, 500 if err
          returnUsers users


    adminUsersTree: (req, res) ->
      console.log 'asdf';
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Admin user required'}, 400 unless req?.user?.isAdmin
      membersAndRepsOnly = req.param 'membersAndRepsOnly'
      if membersAndRepsOnly is "true"
        membersAndRepsOnly = true
      else
        membersAndRepsOnly = false
      @getDownstreamUsers req.tenant._id, membersAndRepsOnly, null, true, false, (err, usersTree, usersTreeFlattened) ->
        return res.json err, 500 if err
        return res.json usersTree


    children: (req, res) ->
      parentId = req.param 'userId'
      User.children parentId, {internal:true}, (err, users) ->
        getToken = (user, done) ->
          Token.findByUserId user._id, (err, token) ->
            done err if err
            user.token = token
            done null, user
        async.mapSeries users, getToken, (err, users) ->
          return res.json {error: "System error", err}, 500 if err
          res.json users


    sanitizeUserFields: (data) ->
      data.phone_cell = (''+ data.phone_cell).replace(/[^0-9]+/g, '') if data.phone_cell
      data.phone_day = (''+ data.phone_day).replace(/[^0-9]+/g, '') if data.phone_day
      data.phone_home = (''+ data.phone_home).replace(/[^0-9]+/g, '') if data.phone_home
      data.dob = moment(data.dob, 'MM/DD/YYYY').format('YYYY-MM-DD') if data.dob?.length and ~data.dob.indexOf('/')

      delete data.captcha
      delete data.drivers_license
      delete data.ssn
      delete data.repAgreement
      keys = _.keys(data)
      for key in keys
        delete data[key] if key.toLowerCase().indexOf("username") > 0 #keep username, but remove azUsername
        delete data[key] if key.toLowerCase().indexOf("password") > -1
        delete data[key] if key.toLowerCase().indexOf("field") > -1
        delete data[key] if key.toLowerCase().indexOf("token") > -1

      return data

    getParentAndRep: (parentId, cb) ->
      return cb "parentId is required." unless parentId
      User.byId parentId, (err, user) =>
        return cb err if err
        return cb null, null unless user
        parentData = _.pick(user, '_id', 'name', 'first_name', 'last_name', 'clientId', 'email')
        parentData = @sanitizeUserFields parentData
        return cb null, parentData

    getUserAndParent: (userId, parentId, cb) ->
      return cb "userId is required." unless userId
      results = {}
      User.byId userId, (err, user) =>
        return cb err if err
        return cb null, null unless user
        userData = _.pick(user, '_id', 'name', 'first_name', 'last_name', 'clientId', 'email', 'isMember', 'isRep', 'parentId', 'mail_address','mail_city','mail_country','mail_postal','mail_state','memberId','memberType','phone_cell','phone_day','phone_home','physical_address','physical_city','physical_country','physical_postal','physical_state')
        userData = @sanitizeUserFields userData
        results.user = userData
        return cb null, results unless parentId
        User.byId parentId, (err, parent) =>
          return cb err if err
          return cb null, results unless parent
          parentData = _.pick(parent, '_id', 'name', 'first_name', 'last_name', 'clientId', 'email', 'isMember', 'isRep', 'parentId', 'mail_address','mail_city','mail_country','mail_postal','mail_state','memberId','memberType','phone_cell','phone_day','phone_home','physical_address','physical_city','physical_country','physical_postal','physical_state')
          parentData = @sanitizeUserFields parentData
          results.parent = parentData
          return cb null, results


    outfitterPurchases: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id

      outfitterUserId = req.param 'userId'
      return res.json {error: 'Admin user required'}, 400 if !req?.user?.isAdmin and !req?.user?.isOutfitter and !req?.user?.isVendor

      async.waterfall [
        (next) =>
          Purchase.byOutfitter outfitterUserId, req.tenant._id, (err, purchases) =>
            return next err if err
            getUser = (userId, cb) =>
              return cb null, null unless userId
              User.byId userId, {}, (err, user) =>
                if user
                  return cb null, user
                else
                  console.log "adminPurchases error, user not found for userId: ", userId
                  console.log err
                  return cb null, null

            addPurchase = (purchase, done) =>
              #Add any calculated field and logic here
              purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]
              #return done err, purchase

              async.waterfall [
                #Get purchase User
                (next) =>
                  getUser purchase.userId, (err, user) =>
                    return next err if err
                    return next err, purchase unless user
                    user = @sanitizeUserFields JSON.parse(JSON.stringify(user))
                    keys = _.keys(user)
                    for key in keys
                      purchase["user_#{key}"] = user[key] if user[key]
                    return next null, purchase

              ], (err, purchase) ->
                if req?.tenant?._id?.toString() isnt "5bd75eec2ee0370c43bc3ec7" and req?.tenant?._id?.toString() isnt "5684a2fc68e9aa863e7bf182"
                  keys = _.keys(purchase)
                  for key in keys
                    delete purchase[key] if key.indexOf("cc_") > -1
                    delete purchase[key] if key.indexOf("parent_") > -1
                    delete purchase[key] if key.indexOf("rbo_") > -1
                    delete purchase[key] if key.indexOf("tenantId") > -1
                    delete purchase[key] if key.indexOf("internalNotes") > -1
                    delete purchase[key] if key.indexOf("Id") > -1 and key.indexOf("clientId") is -1 and key.indexOf("userId") is -1
                    delete purchase[key] if key.indexOf("dob") > -1
                    delete purchase[key] if key.indexOf("ssn") > -1
                    delete purchase[key] if key.indexOf("field") > -1
                    delete purchase[key] if key.indexOf("user_") > -1 and key.indexOf("clientId") is -1 and key.indexOf("email") is -1 and key.indexOf("phone") is -1 and key.indexOf("mail") is -1 and key.indexOf("physical") is -1 and key.indexOf("name") is -1

                return done err, purchase

            async.mapSeries purchases, addPurchase, (err, purchases) ->
              return next err if err
              results = []
              for purchase in purchases
                results.push purchase if purchase
              return next null, results

      ], (err, purchases) =>
        return res.json err, 500 if err
        res.json purchases


    adminPurchases: (req, res) ->
      cb = res if !res.json?
      startDate = new Date(req.body.startDate) if req?.body?.startDate?
      endDate = new Date(req.body.endDate) if req?.body?.endDate?
      listingTypes = req.body.type.toLowerCase().split(',') if req?.body?.type?
      filter_qb_invoice = req.body.filter_qb_invoice if req?.body?.filter_qb_invoice?
      filter_qb_expense = req.body.filter_qb_expense if req?.body?.filter_qb_expense?
      balances_due_only = req.body.balances_due_only if req?.body?.balances_due_only?

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'Admin user required'}, 400 unless req?.user?.isAdmin

      if req.body?.sub_tenant_id?
        tenantId = req.body.sub_tenant_id
      else
        tenantId = req.tenant._id

      if listingTypes
        tListingTypes = listingTypes
        listingTypes = []
        for listingType in tListingTypes
          listingTypes.push listingType.trim()
      else
        listingTypes = []

      async.waterfall [
        #Retrieve Purchases
        (next) ->
          n1 = moment()
          #testId = "5faafa70cbd0d42ed44dcce0"
          if testId?
            Purchase.byId testId, tenantId, (err, tPurchase) ->
              return next err, [tPurchase]
          else if filter_qb_invoice? and filter_qb_expense? and startDate and endDate
            Purchase.byDateRangeQB tenantId, filter_qb_invoice, filter_qb_expense, balances_due_only, startDate, endDate, (err, tPurchases) ->
              return next err if err
              return next err, [] if !tPurchases?
              purchases = []
              for tPurchase in tPurchases
                if listingTypes?.indexOf(tPurchase.huntCatalogCopy[0].type.toLowerCase().trim()) > -1 or listingTypes?.indexOf("all") > -1
                  purchases.push tPurchase
              n2 = moment()
              return next err, purchases
          else if startDate and endDate
            Purchase.byDateRange tenantId, startDate, endDate, (err, tPurchases) ->
              return next err if err
              return next err, [] if !tPurchases?
              purchases = []
              for tPurchase in tPurchases
                if listingTypes?.indexOf(tPurchase.huntCatalogCopy[0].type.toLowerCase().trim()) > -1 or listingTypes?.indexOf("all") > -1
                  purchases.push tPurchase
              n2 = moment()
              return next err, purchases
          else
            Purchase.byTenant req.tenantId, (err, purchases) =>
              return next err, purchases

        #Retrieve Users
        (purchases, next) ->
          userIds = {}
          for tPurchase in purchases
            userIds[tPurchase.userId.toString()] = tPurchase.userId
            userIds[tPurchase.userParentId.toString()] = tPurchase.userParentId if tPurchase.userParentId
            userIds[tPurchase.rbo_rep0.toString()] = tPurchase.rbo_rep0 if tPurchase.rbo_rep0
            userIds[tPurchase.rbo_rep1.toString()] = tPurchase.rbo_rep1 if tPurchase.rbo_rep1
            userIds[tPurchase.rbo_rep2.toString()] = tPurchase.rbo_rep2 if tPurchase.rbo_rep2
            userIds[tPurchase.rbo_rep3.toString()] = tPurchase.rbo_rep3 if tPurchase.rbo_rep3
            userIds[tPurchase.rbo_rep4.toString()] = tPurchase.rbo_rep4 if tPurchase.rbo_rep4
            userIds[tPurchase.rbo_rep5.toString()] = tPurchase.rbo_rep5 if tPurchase.rbo_rep5
            userIds[tPurchase.rbo_rep6.toString()] = tPurchase.rbo_rep6 if tPurchase.rbo_rep6
            userIds[tPurchase.rbo_rep7.toString()] = tPurchase.rbo_rep7 if tPurchase.rbo_rep7
            userIds[tPurchase.rbo_repOSSP.toString()] = tPurchase.rbo_repOSSP if tPurchase.rbo_repOSSP
            userIds[tPurchase.rbo_rbo1.toString()] = tPurchase.rbo_rbo1 if tPurchase.rbo_rbo1
            userIds[tPurchase.rbo_rbo2.toString()] = tPurchase.rbo_rbo2 if tPurchase.rbo_rbo2
            userIds[tPurchase.rbo_rbo3.toString()] = tPurchase.rbo_rbo3 if tPurchase.rbo_rbo3
            userIds[tPurchase.rbo_rbo4.toString()] = tPurchase.rbo_rbo4 if tPurchase.rbo_rbo4
          idList = Object.keys(userIds)
          n1 = moment()
          if idList?.length < 5000
            #Retrieve Users using $in query, much faster. TODO: See what is optimal size in chunks if greater than 5,000
            User.byIds idList, {internal: false}, (err, users) =>
              return next err if err
              userIndex = {}
              for user in users
                userIndex[user._id.toString()] = user
              n2 = moment()
              return next err, purchases, userIndex
          else
            #Retrieve Users method 2, just grab them all in a single query.
            User.findByTenant tenantId, {internal: false}, (err, users) =>
              return next err if err
              userIndex = {}
              for user in users
                userIndex[user._id.toString()] = user
              n2 = moment()
              return next err, purchases, userIndex

        #Loop Purchases, add users, and calculated fields
        (purchases, userIndex, next) =>
          getUser = (userId, cb) ->
            return cb null, null unless userId
            foundUser = userIndex[userId.toString()]
            if foundUser
              return cb null, foundUser
            else
              console.log "adminPurchases error, user not found for userId: ", userId
              return cb null, null

          addPurchase = (purchase, done) =>
            #Add any calculated field and logic here
            purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]
            #return done err, purchase

            async.waterfall [
              #Get purchase User
              (next) =>
                getUser purchase.userId, (err, user) =>
                  return next err if err
                  return next err, purchase unless user
                  user = @sanitizeUserFields user
                  keys = _.keys(user)
                  for key in keys
                    purchase["user_#{key}"] = user[key] if user[key]
                  return next null, purchase
              #Get purchase user parent
              (purchase, next) =>
                getUser purchase.userParentId, (err, parent) =>
                  return next err if err
                  return next err, purchase unless parent
                  parent = @sanitizeUserFields parent
                  keys = _.keys(parent)
                  for key in keys
                    purchase["parent_#{key}"] = parent[key] if parent[key]
                  return next null, purchase
              #Get rbo_rep0
              (purchase, next) =>
                repField = "rbo_rep0"
                return next null, purchase unless purchase.rbo_rep0
                getUser purchase.rbo_rep0, (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep1
              (purchase, next) =>
                repField = "rbo_rep1"
                return next null, purchase unless purchase.rbo_rep1
                getUser purchase.rbo_rep1, (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep2
              (purchase, next) =>
                repField = "rbo_rep2"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep3
              (purchase, next) =>
                repField = "rbo_rep3"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep4
              (purchase, next) =>
                repField = "rbo_rep4"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep5
              (purchase, next) =>
                repField = "rbo_rep5"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep6
              (purchase, next) =>
                repField = "rbo_rep6"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rep7
              (purchase, next) =>
                repField = "rbo_rep7"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_repOSSP
              (purchase, next) =>
                repField = "rbo_repOSSP"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rbo1
              (purchase, next) =>
                repField = "rbo_rbo1"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rbo2
              (purchase, next) =>
                repField = "rbo_rbo2"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rbo3
              (purchase, next) =>
                repField = "rbo_rbo3"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase
              #Get rbo_rbo4
              (purchase, next) =>
                repField = "rbo_rbo4"
                return next null, purchase unless purchase[repField]
                getUser purchase[repField], (err, rep) =>
                  return next err if err
                  return next null, purchase unless rep
                  repData = _.pick(rep, '_id', 'name', 'clientId')
                  repData = @sanitizeUserFields repData
                  keys = _.keys(repData)
                  for key in keys
                    purchase["#{repField}_#{key}"] = repData[key] if repData[key]
                  next null, purchase

            ], (err, purchase) ->
              if tenantId?.toString() isnt "5bd75eec2ee0370c43bc3ec7" and tenantId?.toString() isnt "5684a2fc68e9aa863e7bf182"
                keys = _.keys(purchase)
                for key in keys
                  delete purchase[key] if key.indexOf("cc_") > -1
                  delete purchase[key] if key.indexOf("parent_") > -1
                  delete purchase[key] if key.indexOf("rbo_") > -1
                  delete purchase[key] if key.indexOf("tenantId") > -1
                  delete purchase[key] if key.indexOf("internalNotes") > -1
                  delete purchase[key] if key.indexOf("Id") > -1 and key.indexOf("clientId") is -1 and key.indexOf("userId") is -1
                  delete purchase[key] if key.indexOf("dob") > -1
                  delete purchase[key] if key.indexOf("ssn") > -1
                  delete purchase[key] if key.indexOf("field") > -1
                  delete purchase[key] if key.indexOf("user_") > -1 and key.indexOf("clientId") is -1 and key.indexOf("email") is -1 and key.indexOf("phone") is -1 and key.indexOf("mail") is -1 and key.indexOf("physical") is -1 and key.indexOf("name") is -1


              return done err, purchase

          async.mapSeries purchases, addPurchase, (err, purchases) ->
            return next err if err
            results = []
            for purchase in purchases
              results.push purchase if purchase
            return next null, results

      ], (err, purchases) =>
        if cb
          return cb err if err
          return cb null, purchases
        else
          return res.json err, 500 if err
          res.json purchases


    adminStats: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Admin user required'}, 400 unless req?.user?.isAdmin and req?.user?.userType is "super_admin"
      thisYearStart = moment().startOf('year').format("YYYY-MM-DD")+"T00:00:00.000Z"
      thisYearEnd = moment().endOf('year').format("YYYY-MM-DD")+"T23:59:59.999Z"
      thisMonthStart = moment().startOf('month').format("YYYY-MM-DD")+"T00:00:00.000Z"
      thisMonthEnd = moment().endOf('month').format("YYYY-MM-DD")+"T23:59:59.999Z"

      if req.body?.startDate
        startDate = new Date(req.param 'startDate')
      else
        startDate = thisMonthStart unless startDate

      if req.body?.endDate
        endDate = new Date(req.param 'endDate')
      else
        endDate = thisMonthEnd unless endDate

      stats = {
        #monthly: []
        #weekly: []
        daily: []
      }

      #initailze purchase_date_index with an entry for each day from start to end date.
      current_date = moment(startDate).startOf('day')
      stop_date = moment(endDate)
      purchase_date_index = {}
      while current_date < stop_date
        purchase_date_index[current_date.format('MM/DD/YYYY')] = []
        current_date = current_date.add(1, 'days')

      async.waterfall [
        (next) ->
          Purchase.byDateRange req.tenant._id, startDate, endDate, (err, purchases) ->
            return next err, purchases

        (purchases, next) ->
          for purchase in purchases
            purchase.huntCatalogType = purchase.huntCatalogCopy[0].type if purchase.huntCatalogCopy?[0]
            purchase.huntCatalogCopy = purchase.huntCatalogCopy[0] if purchase.huntCatalogCopy?[0]
            if !purchase.rbo_reps_commission
              purchase.rbo_reps_commission = 0
              purchase.rbo_reps_commission += purchase.rbo_commission_rep0 if !isNaN(purchase.rbo_commission_rep0)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep1 if !isNaN(purchase.rbo_commission_rep1)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep2 if !isNaN(purchase.rbo_commission_rep2)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep3 if !isNaN(purchase.rbo_commission_rep3)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep4 if !isNaN(purchase.rbo_commission_rep4)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep5 if !isNaN(purchase.rbo_commission_rep5)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep6 if !isNaN(purchase.rbo_commission_rep6)
              purchase.rbo_reps_commission += purchase.rbo_commission_rep7 if !isNaN(purchase.rbo_commission_rep7)
              purchase.rbo_reps_commission += purchase.rbo_commission_repOSSP if !isNaN(purchase.rbo_commission_repOSSP)
            if !purchase.rbo_overrides
              purchase.rbo_overrides = 0
              purchase.rbo_overrides += purchase.rbo_commission_rbo1 if !isNaN(purchase.rbo_commission_rbo1)
              purchase.rbo_overrides += purchase.rbo_commission_rbo2 if !isNaN(purchase.rbo_commission_rbo2)
              purchase.rbo_overrides += purchase.rbo_commission_rbo3 if !isNaN(purchase.rbo_commission_rbo3)
              purchase.rbo_overrides += purchase.rbo_commission_rbo4 if !isNaN(purchase.rbo_commission_rbo4)

            purchase.month = moment(purchase.createdAt).startOf('month').format('MMM')
            purchase.week = moment(purchase.createdAt).endOf('week').format('MM/DD/YYYY')
            purchase.day = moment(purchase.createdAt).startOf('day').format('MM/DD/YYYY')
            purchase_date_index[purchase.day] = [] unless purchase_date_index[purchase.day]
            purchase_date_index[purchase.day].push purchase unless purchase?.huntCatalogCopy?.title and purchase.huntCatalogCopy.title.toLowerCase().indexOf("payment") > -1
          return next null, purchases

        (purchases, next) ->
          sum_total_sales = 0
          sum_total_rep_commissions = 0
          sum_total_overrides = 0
          sum_total_rbo_margin = 0
          sum_total_memberships = 0
          sum_total_reps = 0
          sum_total_hunts = 0
          sum_total_rifles = 0
          sum_total_products = 0
          sum_total_courses = 0
          sum_total_advertising = 0
          sum_total_number_new_memberships = 0
          sum_total_number_new_reps = 0
          sum_total_number_hunts = 0
          sum_total_number_rifles = 0
          sum_total_number_products = 0
          sum_total_number_courses = 0
          for key of purchase_date_index
            tPurchases =  purchase_date_index[key]
            sales = 0
            rep_commissions = 0
            overrides = 0
            rbo_margin = 0
            memberships = 0
            reps = 0
            hunts = 0
            rifles = 0
            products = 0
            courses = 0
            advertising = 0
            number_new_memberships = 0
            number_new_reps = 0
            number_hunts = 0
            number_rifles = 0
            number_products = 0
            number_courses = 0
            for purchase in tPurchases
              sum_total_sales += purchase.basePrice
              sum_total_rep_commissions += purchase.rbo_reps_commission
              sum_total_overrides += purchase.rbo_overrides
              sum_total_rbo_margin += purchase.rbo_margin
              sum_total_memberships += purchase.basePrice if purchase.huntCatalogType is "membership"
              sum_total_reps += purchase.basePrice if purchase.huntCatalogCopy.title is "Adventure Specialist"
              sum_total_reps += purchase.basePrice if purchase.huntCatalogCopy.title is "Adventure Advisor"
              sum_total_hunts += purchase.basePrice if purchase.huntCatalogType is "hunt"
              sum_total_rifles += purchase.basePrice if purchase.huntCatalogType is "rifle"
              sum_total_products += purchase.basePrice if purchase.huntCatalogType is "product"
              sum_total_courses += purchase.basePrice if purchase.huntCatalogType is "course"
              sum_total_advertising += purchase.basePrice if purchase.huntCatalogType is "advertising"
              sum_total_number_new_memberships += 1 if purchase.huntCatalogType is "membership"
              sum_total_number_new_reps += 1 if purchase.huntCatalogCopy.title is "Adventure Specialist"
              sum_total_number_new_reps += 1 if purchase.huntCatalogCopy.title is "Adventure Advisor"
              sum_total_number_hunts += 1 if purchase.huntCatalogType is "hunt"
              sum_total_number_rifles += 1 if purchase.huntCatalogType is "rifle"
              sum_total_number_products += 1 if purchase.huntCatalogType is "product"
              sum_total_number_courses += 1 if purchase.huntCatalogType is "course"
              sales += purchase.basePrice
              rep_commissions += purchase.rbo_reps_commission
              overrides += purchase.rbo_overrides
              rbo_margin += purchase.rbo_margin
              memberships += purchase.basePrice if purchase.huntCatalogType is "membership"
              reps += purchase.basePrice if purchase.huntCatalogCopy.title is "Adventure Specialist"
              reps += purchase.basePrice if purchase.huntCatalogCopy.title is "Adventure Advisor"
              hunts += purchase.basePrice if purchase.huntCatalogType is "hunt"
              rifles += purchase.basePrice if purchase.huntCatalogType is "rifle"
              products += purchase.basePrice if purchase.huntCatalogType is "product"
              courses += purchase.basePrice if purchase.huntCatalogType is "course"
              advertising += purchase.basePrice if purchase.huntCatalogType is "advertising"
              number_new_memberships += 1 if purchase.huntCatalogType is "membership"
              number_new_reps += 1 if purchase.huntCatalogCopy.title is "Adventure Specialist"
              number_new_reps += 1 if purchase.huntCatalogCopy.title is "Adventure Advisor"
              number_hunts += 1 if purchase.huntCatalogType is "hunt"
              number_rifles += 1 if purchase.huntCatalogType is "rifle"
              number_products += 1 if purchase.huntCatalogType is "product"
              number_courses += 1 if purchase.huntCatalogType is "course"
            entry = {
              key: key
              sum_total_sales: sum_total_sales
              sum_total_rep_commissions: sum_total_rep_commissions
              sum_total_overrides: sum_total_overrides
              sum_total_rbo_margin: sum_total_rbo_margin
              sum_total_memberships: sum_total_memberships
              sum_total_reps: sum_total_reps
              sum_total_hunts: sum_total_hunts
              sum_total_rifles: sum_total_rifles
              sum_total_products: sum_total_products
              sum_total_courses: sum_total_courses
              sum_total_advertising: sum_total_advertising
              sum_total_number_new_memberships: sum_total_number_new_memberships
              sum_total_number_new_reps: sum_total_number_new_reps
              sum_total_number_hunts: sum_total_number_hunts
              sum_total_number_rifles: sum_total_number_rifles
              sum_total_number_products: sum_total_number_products
              sum_total_number_courses: sum_total_number_courses
              sales: sales
              rep_commissions: rep_commissions
              overrides: overrides
              rbo_margin: rbo_margin
              memberships: memberships
              reps: reps
              hunts: hunts
              rifles: rifles
              products: products
              courses: courses
              advertising: advertising
              number_new_memberships: number_new_memberships
              number_new_reps: number_new_reps
              number_hunts: number_hunts
              number_rifles: number_rifles
              number_products: number_products
              number_courses: number_courses
            }
            stats.daily.push entry
          return next null, stats

      ], (err, stats) ->
        return res.json err, 500 if err
        return res.json stats

    repLeaderboard: (req, res) ->
      cb = res if !res.json?
      startDate = new Date(req.body.startDate) if req?.body?.startDate?
      endDate = new Date(req.body.endDate) if req?.body?.endDate?

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'User is not a rep'} unless req?.user?.isRep
        return cb {error: 'missing startDate Required'} unless startDate
        return cb {error: 'missing endDate Required'} unless endDate
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep
        return res.json {error: 'missing startDate Required'}, 400 unless startDate
        return res.json {error: 'missing endDate Required'}, 400 unless endDate

      leader_board = {
        advisors: {userId: null, count: 0}
        memberships: {userId: null, count: 0}
        adventures: {userId: null, count: 0}
        courses: {userId: null, count: 0}
        products: {userId: null, count: 0}
        rifles: {userId: null, count: 0}
        oss: {userId: null, count: 0}
      }

      async.waterfall [
        #Get Purchases
        (next) ->
          Purchase.byDateRange req.tenant._id, startDate, endDate, (err, purchases) ->
            return next err, purchases

        (purchases, next) ->
          user_stats = {}
          for tPurchase in purchases
            userId = tPurchase.rbo_rep0.toString()
            type = tPurchase.huntCatalogCopy[0]?.type
            title = tPurchase.huntCatalogCopy[0]?.title
            continue if title.toLowerCase().indexOf("owner") > -1 #skip ownership contributions items
            continue if (userId == "570419ee2ef94ac9688392b0" or userId == "570419ab2ef94ac9688392af") #brain or brad
            user_stats[userId] = {} if !user_stats[userId]
            user_stats[userId][type] = 0 if !user_stats[userId][type]
            if type.indexOf("hunt") > -1 or type.indexOf("product") > -1
              user_stats[userId][type] = user_stats[userId][type] + tPurchase.amountTotal
            else
              user_stats[userId][type] = user_stats[userId][type] + 1
          return next null, user_stats

        (user_stats, next) ->
          for key, value of user_stats
            userId = key
            for type, count of value
              switch
                when type is "rep"
                  leaderboard_type = "advisors"
                when type.indexOf("membership") > -1
                  leaderboard_type = "memberships"
                when type is "hunt"
                  leaderboard_type = "adventures"
                when type is "course"
                  leaderboard_type = "courses"
                when type is "product"
                  leaderboard_type = "products"
                when type is "rifle"
                  leaderboard_type = "rifles"
                when type is "oss"
                  leaderboard_type = "oss"
                when type.indexOf("payment") > -1
                  leaderboard_type = "payments"
                else
                  leaderboard_type = type
              leader_stat = leader_board[leaderboard_type]
              if leader_stat and count > leader_stat.count
                leader_board[leaderboard_type] = {userId: null, count: 0} if !leader_stat
                leader_board[leaderboard_type].userId = userId
                leader_board[leaderboard_type].count = count

          return next null, leader_board

      ], (err, leader_board) ->
        if cb
          return cb err if err
          return cb null, leader_board
        else
          return res.json err, 500 if err
          return res.json leader_board


    repPurchases2: (req, res) ->
      cb = res if !res.json?
      repId = req.body.userId if req?.body?.userId?
      startDate = new Date(req.body.startDate) if req?.body?.startDate?
      endDate = new Date(req.body.endDate) if req?.body?.endDate?
      userIdsList = req.body.users_id_list if req?.body?.users_id_list?
      if req.body.expand_data is true or req.body.expand_data is "true"
        expand_data = true
      else
        expand_data = false

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'User is not a rep'} unless req?.user?.isRep
        return cb {error: 'missing userId Required'} unless repId
        return cb {error: 'missing startDate Required'} unless startDate
        return cb {error: 'missing endDate Required'} unless endDate
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep
        return res.json {error: 'missing userId Required'}, 400 unless repId
        return res.json {error: 'missing startDate Required'}, 400 unless startDate
        return res.json {error: 'missing endDate Required'}, 400 unless endDate

      async.waterfall [
        #Get Purchases
        (next) ->
          Purchase.byDateRange req.tenant._id, startDate, endDate, (err, purchases) ->
            return next err, purchases

        #Filter to only those that apply to the userId list
        (purchases, next) ->
          filtered_purchases =[]
          for tPurchase in purchases
            if userIdsList.indexOf(tPurchase.userId.toString()) > -1
              filtered_purchases.push tPurchase
          return next null, filtered_purchases

        #Now expand any calculated or metadata needed
        (filtered_purchases, next) ->
          for tPurchase in filtered_purchases
            tPurchase.huntCatalogCopy = tPurchase.huntCatalogCopy[0]
            if expand_data
              console.log "TODO: implement expanded data.  Currently data is expanded in RRADS as needed"
              #TODO: grab the user metatdata
              #TODO: grab the parent user metadata
          return next null, filtered_purchases

      ], (err, filtered_purchases) ->
        if cb
          return cb err if err
          return cb null, filtered_purchases
        else
          return res.json err, 500 if err
          return res.json filtered_purchases

    #Legacy method called my rep dashboard in NRADS.  Once that is not used, this can be deleted
    repPurchases: (req, res) ->
      cb = res if !res.json?
      repId = req.body.userId if req?.body?.userId?
      startDate = new Date(req.body.startDate) if req?.body?.startDate?
      endDate = new Date(req.body.endDate) if req?.body?.endDate?
      userIdsList = req.body.users_id_list if req?.body?.users_id_list?

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'User is not a rep'} unless req?.user?.isRep
        return cb {error: 'missing userId Required'} unless repId
        return cb {error: 'missing startDate Required'} unless startDate
        return cb {error: 'missing endDate Required'} unless endDate
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep
        return res.json {error: 'missing userId Required'}, 400 unless repId
        return res.json {error: 'missing startDate Required'}, 400 unless startDate
        return res.json {error: 'missing endDate Required'}, 400 unless endDate

      User.byId repId, (err, topUser) =>
        if cb
          return cb err if err
          return cb "repPurchases could not find user for id: #{repId}" unless topUser
        else
          return res.json err, 500 if err
          return res.json "repPurchases could not find user for id: #{repId}" unless topUser


        chunkSize = 5000
        async.waterfall [
          (next) =>
            if userIdsList?
              userIdsList.push topUser._id
              allChunks = _.groupBy userIdsList, (element, index) ->
                return Math.floor(index/chunkSize)
              allChunks = _.toArray(allChunks)
              getUsers = (chunckIdList, done) ->
                User.byIds chunckIdList, {}, (err, users) ->
                  return done err, users
              usersTreeFlattened = {}
              async.mapSeries allChunks, getUsers, (err, group_of_users) ->
                return next err if err
                for group in group_of_users
                  for tUser in group
                    usersTreeFlattened[tUser._id.toString()] = tUser
                return next err, usersTreeFlattened
            else
              #Legacy support for NRADS rep dashboard (old rep dashboard)
              membersAndRepsOnly = false
              @getDownstreamUsers req.tenant._id, membersAndRepsOnly, topUser, false, true, (err, usersTree, usersTreeFlattened) =>
                return next err if err
                usersTreeFlattened[topUser._id.toString()] = topUser
                userIdsList = []
                userIdsList.push topUser._id
                for key, value of usersTreeFlattened
                  userIdsList.push value._id
                return next null, usersTreeFlattened
        ], (err, usersTreeFlattened) =>
          if cb
            return cb err if err
          else
            return res.json err, 500 if err

          allChunks = _.groupBy userIdsList, (element, index) ->
            return Math.floor(index/chunkSize)
          allChunks = _.toArray(allChunks)
          getPurchases = (chunckIdList, done) ->
            Purchase.byUserIds req.tenant._id, chunckIdList, startDate, endDate, (err, purchases) ->
              return done err, purchases
          purchases = []
          async.mapSeries allChunks, getPurchases, (err, group_of_purchases) =>
            if cb
              return cb err if err
            else
              return res.json err, 500 if err
            for group in group_of_purchases
              for tPurchase in group
                purchases.push tPurchase
          #Purchase.byUserIds req.tenant._id, userIdsList, startDate, endDate, (err, purchases) =>
            getUser = (userId, cb) ->
              return cb null, null unless userId
              foundUser = usersTreeFlattened[userId.toString()]
              if topUser?._id?.toString() is userId.toString()
                return cb null, topUser
              else if foundUser
                return cb null, foundUser
              else
                return cb "user not found"

            addPurchase = (purchase, done) =>
              #Add any calculated field and logic here
              purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]

              async.waterfall [
                #Get purchase User
                (next) =>
                  getUser purchase.userId, (err, user) =>
                    console.log "repPurchases() get user for userId #{purchase.userId} failed with error: ", err if err
                    return next null, purchase unless user
                    user = @sanitizeUserFields user
                    keys = _.keys(user)
                    if keys.indexOf("$__original_save")
                      user = JSON.parse(JSON.stringify(user))
                      keys = _.keys(user)
                    for key in keys
                      purchase["user_#{key}"] = user[key] if user[key]
                    return next null, purchase

                #Get purchase user parent
                (purchase, next) =>
                  getUser purchase.userParentId, (err, parent) =>
                    console.log "repPurchases() get user for parentId #{purchase.userParentId} failed with error: ", err if err
                    return next null, purchase unless parent
                    parent = @sanitizeUserFields parent
                    keys = Object.keys(parent)
                    if keys.indexOf("$__original_save") #what is this object doing here!?  wierd!
                      purchase['parent__id'] = parent._id.toString()
                      purchase['parent_name'] = parent.name
                    else
                      for key in keys
                        purchase["parent_#{key}"] = parent[key] if parent[key]
                    return next null, purchase

              ], (err, purchase) ->
                return done err, purchase

            async.mapSeries purchases, addPurchase, (err, purchases) ->
              if cb
                return cb err if err
                return cb null, purchases
              else
                return res.json err, 500 if err
                return res.json purchases


    repCommissions: (req, res) ->
      cb = res if !res.json?
      repId = req.body.userId if req?.body?.userId?
      startDate = new Date(req.body.startDate) if req?.body?.startDate?
      endDate = new Date(req.body.endDate) if req?.body?.endDate?

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'User is not a rep'} unless req?.user?.isRep
        return cb {error: 'missing userId Required'} unless repId
        return cb {error: 'missing startDate Required'} unless startDate
        return cb {error: 'missing endDate Required'} unless endDate
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep
        return res.json {error: 'missing userId Required'}, 400 unless repId
        return res.json {error: 'missing startDate Required'}, 400 unless startDate
        return res.json {error: 'missing endDate Required'}, 400 unless endDate

      Purchase.byRepAny req.tenant._id, repId, startDate, endDate, (err, purchases) =>
        if cb
          return cb err if err
        else
          return res.json err, 500 if err
        addPurchase = (purchase, done) =>
          #Add any calculated field and logic here
          purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]
          return done null, null if purchase.huntCatalogCopy?.huntNumber is "FSHS" or purchase.huntCatalogCopy?.huntNumber is "AS"
          delete purchase.commission
          delete purchase.commissionPercent
          delete purchase.huntCatalogCopy.outfitter_userId
          delete purchase.huntCatalogCopy.outfitter_name
          delete purchase.huntCatalogCopy.internalNotes
          delete purchase.huntCatalogCopy.createMember
          delete purchase.huntCatalogCopy.createRep
          delete purchase.huntCatalogCopy.media
          delete purchase.userIsMember
          delete purchase.membershipPurchased
          delete purchase.cc_transId
          delete purchase.cc_responseCode
          delete purchase.cc_messageCode
          delete purchase.cc_name
          delete purchase.cc_email
          delete purchase.cc_phone
          delete purchase.cc_number
          delete purchase.rbo_margin

          repId = repId.toString()
          purchase.comm_r0 = purchase.rbo_commission_rep0 if repId is purchase.rbo_rep0?.toString()
          purchase.comm_r1 = purchase.rbo_commission_rep1 if repId is purchase.rbo_rep1?.toString()
          purchase.comm_r2 = purchase.rbo_commission_rep2 if repId is purchase.rbo_rep2?.toString()
          purchase.comm_r3 = purchase.rbo_commission_rep3 if repId is purchase.rbo_rep3?.toString()
          purchase.comm_r4 = purchase.rbo_commission_rep4 if repId is purchase.rbo_rep4?.toString()
          purchase.comm_r5 = purchase.rbo_commission_rep5 if repId is purchase.rbo_rep5?.toString()
          purchase.comm_r6 = purchase.rbo_commission_rep6 if repId is purchase.rbo_rep6?.toString()
          purchase.comm_r7 = purchase.rbo_commission_rep7 if repId is purchase.rbo_rep7?.toString()
          purchase.comm_rOSSP = purchase.rbo_commission_repOSSP if repId is purchase.rbo_repOSSP?.toString()
          #if repId is "570419ee2ef94ac9688392b0" or repId is "5783ff9baea350ac565420c1" or repId is "570682e49e6e8e445d92db2e"
          #  purchase.comm_c1 = purchase.rbo_commission_rbo1 if repId is purchase.rbo_rbo1
          #  purchase.comm_c2 = purchase.rbo_commission_rbo2 if repId is purchase.rbo_rbo2
          #  purchase.comm_c3 = purchase.rbo_commission_rbo3 if repId is purchase.rbo_rbo3
          #  purchase.comm_c4 = purchase.rbo_commission_rbo4 if repId is purchase.rbo_rbo4

          total = 0
          total += purchase.comm_r0 if purchase.comm_r0
          total += purchase.comm_r1 if purchase.comm_r1
          total += purchase.comm_r2 if purchase.comm_r2
          total += purchase.comm_r3 if purchase.comm_r3
          total += purchase.comm_r4 if purchase.comm_r4
          total += purchase.comm_r5 if purchase.comm_r5
          total += purchase.comm_r6 if purchase.comm_r6
          total += purchase.comm_r7 if purchase.comm_r7
          total += purchase.comm_rOSSP if purchase.comm_rOSSP
          purchase.repIdTotalCommissions = total
          return done null, null if total == 0

          delete purchase.rbo_rep0
          delete purchase.rbo_rep1
          delete purchase.rbo_rep2
          delete purchase.rbo_rep3
          delete purchase.rbo_rep4
          delete purchase.rbo_rep5
          delete purchase.rbo_rep6
          delete purchase.rbo_rep7
          delete purchase.rbo_repOSSP
          delete purchase.rbo_rbo1
          delete purchase.rbo_rbo2
          delete purchase.rbo_rbo3
          delete purchase.rbo_rbo4
          delete purchase.rbo_commission_rep0
          delete purchase.rbo_commission_rep1
          delete purchase.rbo_commission_rep2
          delete purchase.rbo_commission_rep3
          delete purchase.rbo_commission_rep4
          delete purchase.rbo_commission_rep5
          delete purchase.rbo_commission_rep6
          delete purchase.rbo_commission_rep7
          delete purchase.rbo_commission_repOSSP
          delete purchase.rbo_commission_rbo1
          delete purchase.rbo_commission_rbo2
          delete purchase.rbo_commission_rbo3
          delete purchase.rbo_commission_rbo4

          SKIP_PARENT_DATA = false #because it is too slow to hit the db for each purchase
          if SKIP_PARENT_DATA
            return done err, purchase
          else
            #@getUserAndParent purchase.userId, purchase.userParentId, (err, result) ->
            @getUserAndParent purchase.userId, null, (err, result) ->
              return done err if err
              return done err, purchase unless result.user
              keys = _.keys(result.user)
              for key in keys
                purchase["user_#{key}"] = result.user[key] if result.user[key]
              keys = _.keys(result.parent)
              for key in keys
                purchase["parent_#{key}"] = result.parent[key] if result.parent[key]
              return done err, purchase

        async.mapSeries purchases, addPurchase, (err, purchases) ->
          if cb
            return cb err if err
          else
            return res.json err, 500 if err
          tPurchases = []
          for purchase in purchases
            tPurchases.push purchase if purchase
          if cb
            return cb null, tPurchases
          else
            res.json tPurchases

    repCommissions2: (req, res) ->
      cb = res if !res.json?
      repId = req.body.userId if req?.body?.userId?
      startDate = new Date(req.body.startDate) if req?.body?.startDate?
      endDate = new Date(req.body.endDate) if req?.body?.endDate?

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'User is not a rep'} unless req?.user?.isRep
        return cb {error: 'missing userId Required'} unless repId
        return cb {error: 'missing startDate Required'} unless startDate
        return cb {error: 'missing endDate Required'} unless endDate
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep
        return res.json {error: 'missing userId Required'}, 400 unless repId
        return res.json {error: 'missing startDate Required'}, 400 unless startDate
        return res.json {error: 'missing endDate Required'}, 400 unless endDate

      Purchase.byRepAny req.tenant._id, repId, startDate, endDate, (err, purchases) =>
        if cb
          return cb err if err
        else
          return res.json err, 500 if err
        addPurchase = (purchase, done) =>
          #Add any calculated field and logic here
          purchase.huntCatalogCopy = purchase.huntCatalogCopy[0]
          return done null, null if purchase.huntCatalogCopy?.huntNumber is "FSHS" or purchase.huntCatalogCopy?.huntNumber is "AS"
          delete purchase.commission
          delete purchase.commissionPercent
          delete purchase.huntCatalogCopy.outfitter_userId
          delete purchase.huntCatalogCopy.outfitter_name
          delete purchase.huntCatalogCopy.internalNotes
          delete purchase.huntCatalogCopy.createMember
          delete purchase.huntCatalogCopy.createRep
          delete purchase.huntCatalogCopy.media
          delete purchase.userIsMember
          delete purchase.membershipPurchased
          delete purchase.cc_transId
          delete purchase.cc_responseCode
          delete purchase.cc_messageCode
          delete purchase.cc_name
          delete purchase.cc_email
          delete purchase.cc_phone
          delete purchase.cc_number
          delete purchase.rbo_margin

          repId = repId.toString()
          purchase.comm_r0 = purchase.rbo_commission_rep0 if repId is purchase.rbo_rep0?.toString()
          purchase.comm_r1 = purchase.rbo_commission_rep1 if repId is purchase.rbo_rep1?.toString()
          purchase.comm_r2 = purchase.rbo_commission_rep2 if repId is purchase.rbo_rep2?.toString()
          purchase.comm_r3 = purchase.rbo_commission_rep3 if repId is purchase.rbo_rep3?.toString()
          purchase.comm_r4 = purchase.rbo_commission_rep4 if repId is purchase.rbo_rep4?.toString()
          purchase.comm_r5 = purchase.rbo_commission_rep5 if repId is purchase.rbo_rep5?.toString()
          purchase.comm_r6 = purchase.rbo_commission_rep6 if repId is purchase.rbo_rep6?.toString()
          purchase.comm_r7 = purchase.rbo_commission_rep7 if repId is purchase.rbo_rep7?.toString()
          purchase.comm_rOSSP = purchase.rbo_commission_repOSSP if repId is purchase.rbo_repOSSP?.toString()
          #if repId is "570419ee2ef94ac9688392b0" or repId is "5783ff9baea350ac565420c1" or repId is "570682e49e6e8e445d92db2e"
          #  purchase.comm_c1 = purchase.rbo_commission_rbo1 if repId is purchase.rbo_rbo1
          #  purchase.comm_c2 = purchase.rbo_commission_rbo2 if repId is purchase.rbo_rbo2
          #  purchase.comm_c3 = purchase.rbo_commission_rbo3 if repId is purchase.rbo_rbo3
          #  purchase.comm_c4 = purchase.rbo_commission_rbo4 if repId is purchase.rbo_rbo4

          total = 0
          total += purchase.comm_r0 if purchase.comm_r0
          total += purchase.comm_r1 if purchase.comm_r1
          total += purchase.comm_r2 if purchase.comm_r2
          total += purchase.comm_r3 if purchase.comm_r3
          total += purchase.comm_r4 if purchase.comm_r4
          total += purchase.comm_r5 if purchase.comm_r5
          total += purchase.comm_r6 if purchase.comm_r6
          total += purchase.comm_r7 if purchase.comm_r7
          total += purchase.comm_rOSSP if purchase.comm_rOSSP
          purchase.repIdTotalCommissions = total
          return done null, null if total == 0

          delete purchase.rbo_rep0
          delete purchase.rbo_rep1
          delete purchase.rbo_rep2
          delete purchase.rbo_rep3
          delete purchase.rbo_rep4
          delete purchase.rbo_rep5
          delete purchase.rbo_rep6
          delete purchase.rbo_rep7
          delete purchase.rbo_repOSSP
          delete purchase.rbo_rbo1
          delete purchase.rbo_rbo2
          delete purchase.rbo_rbo3
          delete purchase.rbo_rbo4
          delete purchase.rbo_commission_rep0
          delete purchase.rbo_commission_rep1
          delete purchase.rbo_commission_rep2
          delete purchase.rbo_commission_rep3
          delete purchase.rbo_commission_rep4
          delete purchase.rbo_commission_rep5
          delete purchase.rbo_commission_rep6
          delete purchase.rbo_commission_rep7
          delete purchase.rbo_commission_repOSSP
          delete purchase.rbo_commission_rbo1
          delete purchase.rbo_commission_rbo2
          delete purchase.rbo_commission_rbo3
          delete purchase.rbo_commission_rbo4
          return done err, purchase

        async.mapSeries purchases, addPurchase, (err, purchases) ->
          if cb
            return cb err if err
          else
            return res.json err, 500 if err
          tPurchases = []
          for purchase in purchases
            tPurchases.push purchase if purchase
          if cb
            return cb null, tPurchases
          else
            res.json tPurchases


    repUsers: (req, res) ->
      cb = res if !res.json?
      repId = req.body.userId if req?.body?.userId?
      includeProspects = req.body.includeProspects if req?.body?.includeProspects?
      quicksearch = req.body.quicksearch if req?.body?.quicksearch?
      quicksearch = quicksearch.toLowerCase() if quicksearch

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
        return cb {error: 'User is not a rep'} unless req?.user?.isRep
        return cb {error: 'Missing required repId'} unless repId
      else
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
        return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep
        return res.json {error: 'Missing required repId'}, 400 unless repId

      if includeProspects? and (includeProspects is true or includeProspects is "true")
        includeProspects = true
        membersAndRepsOnly = false
      else
        includeProspects = false
        membersAndRepsOnly = true

      User.byId repId, (err, topUser) =>
        if cb
          return cb err if err
          return cb "Unable to find user for rep id: #{repId}" unless topUser
        else
          return res.json err, 500 if err
          return res.json "Unable to find user for rep id: #{repId}", 500 unless topUser
        @getDownstreamUsers req.tenant._id, membersAndRepsOnly, topUser, false, true, (err, usersTree, usersTreeFlattened) =>
          if cb
            return cb err if err
          else
            return res.json err, 500 if err

          getUser = (userId) ->
            return null unless userId
            foundUser = usersTreeFlattened[userId.toString()]
            if foundUser
              return foundUser
            else if topUser?._id?.toString() is userId.toString()
              return topUser
            else
              console.log "repUsersDownstream: user not found for userId: ", userId
              return null

          validUsers = []
          for key, tUser of usersTreeFlattened
            continue unless tUser.tenantId?.toString() is req.tenant._id.toString()
            if quicksearch
              continue unless (tUser.name?.toLowerCase().indexOf(quicksearch) > -1 or tUser.email?.toLowerCase().indexOf(quicksearch) > -1)
            parent = getUser tUser.parentId
            if parent
              tUser['parent__id'] = parent._id.toString()
              tUser['parent_name'] = parent.name
            tHasReminders = false
            tReminderStates = tUser.reminders.states.join(",") if tUser.reminders?.states
            tHasReminders = true if tReminderStates and tReminderStates.trim() != "Colorado"
            tUser.reminderStates = tUser.reminders.states.join(",") if tUser.reminders?.states
            tUser.isAppUser = true if tUser.devices?.length
            tUser.platform = tUser.devices[0].platform if tUser.devices?.length > 0 and tUser.devices[0].platform
            if !tUser.created
              timestamp = tUser._id.toString().substring(0,8)
              createdDate = new Date( parseInt( timestamp, 16 ) * 1000 )
              tUser.created = createdDate
            tUser.userId = tUser._id
            delete tUser.dob
            delete tUser.isAdmin
            delete tUser.isOutfitter
            delete tUser.imported
            delete tUser.internalNotes
            delete tUser.needsWelcomeEmail
            delete tUser.welcomeEmailSent
            delete tUser.needsPointsEmail
            delete tUser.pointsEmailSent
            delete tUser.powerOfAttorney
            delete tUser.source
            delete tUser.username
            delete tUser.modified
            delete tUser.residence
            tUser = @sanitizeUserFields(tUser)
            validUsers.push tUser if tHasReminders or tUser.first_name or tUser.last_name or tUser.name or tUser.email or tUser.mail_postal or tUser.physical_postal

          if cb
            return cb null, validUsers
          else
            return res.json validUsers



    repUsersDownstream: (req, res) ->
      repId = req.param 'userId'
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'User is not a rep'}, 400 unless req?.user?.isRep

      User.byId repId, (err, topUser) =>
        return res.json err, 500 if err
        membersAndRepsOnly = true
        @getDownstreamUsers req.tenant._id, membersAndRepsOnly, topUser, false, true, (err, usersTree, usersTreeFlattened) ->
          return res.json err, 500 if err

          getUser = (userId) ->
            return null unless userId
            foundUser = usersTreeFlattened[userId.toString()]
            if foundUser
              return foundUser
            else if topUser?._id?.toString() is userId.toString()
              return topUser
            else
              console.log "repUsersDownstream: user not found for userId: ", userId
              return null

          for key, item of usersTreeFlattened
            parent = getUser item.parentId
            if parent
              item['parent__id'] = parent._id.toString()
              item['parent_name'] = parent.name

          results = {
            usersTree: usersTree
            usersTreeFlattened: usersTreeFlattened
          }
          return res.json results



    getDownstreamUsers: (tenantId, membersAndRepsOnly, topUser, includeMissingUsers, forRepView, cb) ->
      User.findByTenant tenantId, {internal: false, sort: "first_name"}, (err, users) =>
        return cb err if err

        #Filter out empty users
        validUses = []
        for tUser in users
          tHasReminders = false
          tReminderStates = tUser.reminders.states.join(",") if tUser.reminders?.states
          tHasReminders = true if tReminderStates and tReminderStates.trim() != "Colorado"
          if tHasReminders or tUser.first_name or tUser.last_name or tUser.name or tUser.email or tUser.mail_postal or tUser.physical_postal
            if membersAndRepsOnly
              if tUser.isRep or tUser.isMember
                validUses.push tUser
            else
              validUses.push tUser
        users = validUses

        unflatten = (users, parent, tree) =>
          #console.log "Unflatten called with parent: ", parent.name, parent.treeParentId, parent.treeId
          tree = [] unless tree
          parent = { treeId: 0 } unless parent
          children = _.filter users, (child) =>
            return child.treeParentId == parent.treeId

          if !_.isEmpty(children)
            parent.numChildren = children.length
            if parent.treeId == 0 || parent.startTreeRoot
              tree = children
            else
              parent['items'] = children

            _.each children, (child) =>
              unflatten users, child

          return tree;

        flatten = (tree, leveldown, flat) ->
          flat = {} unless flat
          leveldown++
          for item in tree
            item.leveldown = leveldown
            flat[item._id] = item
            if item["items"]
              flatten item["items"], leveldown, flat
          return flat

        addUser = (users) =>
          (user, done) =>
            #Add any calculated field and logic here
            user = @sanitizeUserFields(user)
            if forRepView
              delete user.dob
              delete user.isAdmin
              delete user.isOutfitter
              delete user.imported
              delete user.internalNotes
              delete user.needsWelcomeEmail
              delete user.welcomeEmailSent
              delete user.needsPointsEmail
              delete user.pointsEmailSent
              delete user.powerOfAttorney
              delete user.source
              delete user.username
              delete user.modified
              delete user.residence

            user.isAppUser = true if user.devices?.length
            user.class = "rbo_tree"
            if user.isRep and user.repType is "Agency Manager"
              user.class = "#{user.class} rbo_am"
            if user.isRep and user.repType is "Division Manager"
              user.class = "#{user.class} rbo_dm"
            else if user.isRep and user.repType is "Senior Adventure Specialist"
              user.class = "#{user.class} rbo_shs"
            else if user.isRep and user.repType is "Adventure Specialist"
              user.class = "#{user.class} rbo_fshs"
            if user.isMember and !user.isRep
              user.class = "#{user.class} rbo_member"

            if user.parentId and user.parentId.toString() isnt user._id.toString()
              user.treeParentId = user.parentId.toString()
              user.treeId = user._id.toString()
            else
              user.treeId = user._id.toString()
              if user.isAppUser
                user.treeParentId = -1
              else if user.imported is "RBO_WordpressRequest"
                user.treeParentId = -2
              else
                user.treeParentId = 0

            user.text = "#{user.first_name} #{user.last_name}, #{user.clientId}" if user.clientId
            user.text = "#{user.first_name} #{user.last_name}" if !user.clientId
            if user.text.indexOf("undefined") > -1
              user.text = "#{user.text}, #{user._id}"
            if !user.created
              timestamp = user._id.toString().substring(0,8)
              createdDate = new Date( parseInt( timestamp, 16 ) * 1000 )
              user.created = createdDate

            return done err, user

        async.mapSeries users, addUser(users), (err, users) =>
          return cb err if err


          # Create the Tree by starting with all users with no parents and build the tree "down"
          if !topUser and !forRepView
            #admin pull the full tree
            usersTree = unflatten(users, null, null)
            usersTreeFlattened = flatten(usersTree, 0)
          else if topUser?._id
            topUser.treeId = topUser._id.toString()
            topUser.startTreeRoot = true
            usersTree = unflatten(users, topUser, null)
            usersTreeFlattened = flatten(usersTree, 0)
          else
            cb "Error: Downstream users requested but top user not specified."


          #Now look for users that that were missed in the tree
          if includeMissingUsers
            missingUsers = []
            users.push {
              treeId: -1
              treeParentId: 0
              text: "No Parent (app users)"
            }
            users.push {
              treeId: -2
              treeParentId: 0
              text: "No Parent (from wsm wordpress)"
            }
            usersLookup = []
            usersInTreeLookup = []
            for tUser in users
              usersLookup[tUser._id.toString()] = tUser if tUser._id

            for tUserId of usersLookup
              missingUsers.push(tUserId) unless usersTreeFlattened[tUserId]
            missing = []
            for mUserId in missingUsers
              dUser = _.clone(usersLookup[mUserId])
              dUser.text = "#{dUser.first_name} #{dUser.last_name}, #{dUser.clientId}, #{dUser._id}" if dUser.clientId
              dUser.text = "#{dUser.first_name} #{dUser.last_name}, #{dUser._id}" if !dUser.clientId
              missing.push dUser
            usersTree.push {
              treeId: -3
              treeParentId: 0
              text: "No Parent (missing valid parent)"
              items: missing
            }

          #Add in parent objects
          #getUser = (userId) ->
          #  return null unless userId
          #  foundUser = usersTreeFlattened[userId.toString()]
          #  if foundUser
          #    return foundUser
          #  else
          #    return null
          #for key, value of usersTreeFlattened
          # if value.parentId
          #    parent = getUser(value.parentId)
          #    value.parent = parent if parent

          return cb null, usersTree, usersTreeFlattened

    getDownstreamUsersv2: (tenantId, membersAndRepsOnly, topUser, includeMissingUsers, forRepView, cb) ->
      UserRep.byRepId topUser._id, (err, user_reps) =>
        return cb err if err
        userIds = []
        user_reps_index = {}
        for tUserRep in user_reps
          userIds.push tUserRep.userId
          user_reps_index[tUserRep.userId.toString()] = tUserRep

        chunkSize = 2000
        allChunks = _.groupBy userIds, (element, index) ->
          return Math.floor(index/chunkSize)
        allChunks = _.toArray(allChunks)

        getUsers = (chunckIdList, done) ->
          User.byIds chunckIdList, {}, (err, users) ->
            return done err, users
        users = []
        async.mapSeries allChunks, getUsers, (err, group_of_users) =>
          console.log err if err
          for group in group_of_users
            for tUser in group
              users.push tUser

          #Filter out empty users
          validUses = []
          for tUser in users
            if tUser.tenantId.toString() isnt topUser.tenantId.toString()
              console.log "Error: CROSS TENANT USER ISSUE!"
              continue
            tHasReminders = false
            tReminderStates = tUser.reminders.states.join(",") if tUser.reminders?.states
            tHasReminders = true if tReminderStates and tReminderStates.trim() != "Colorado"
            if tHasReminders or tUser.first_name or tUser.last_name or tUser.name or tUser.email or tUser.mail_postal or tUser.physical_postal
              if membersAndRepsOnly
                if tUser.isRep or tUser.isMember
                  validUses.push tUser
              else
                validUses.push tUser
          users = validUses

          assignLevels = (users, parent, tree) =>
            newUserList = {}
            for user in users
              userRep = user_reps_index[user._id.toString()]
              console.log "Alert: userRep to check for level of parent rep #{parent.name}/#{parent._id}, user: #{user.name}/#{user._id}:   userrep entry:", userRep
              if userRep
                switch parent._id.toString()
                  when userRep.rbo_rep0.toString() then user.leveldown = 1
                  when userRep.rbo_rep1.toString() then user.leveldown = 2
                  when userRep.rbo_rep2.toString() then user.leveldown = 3
                  when userRep.rbo_rep3.toString() then user.leveldown = 4
                  when userRep.rbo_rep4.toString() then user.leveldown = 5
                  when userRep.rbo_rep5.toString() then user.leveldown = 6
                  when userRep.rbo_rep6.toString() then user.leveldown = 7
                  when userRep.rbo_rep7.toString() then user.leveldown = 8
                  else
                    console.log "Error: Encountered user not in user reps list. #{user._id}, #{user._name}, for parentId: #{parent._id}"
                newUserList[user._id] = user
              else
                console.log "Error: Encountered user not in user reps index list. #{user._id}, #{user._name}, for parentId: #{parent._id}"

            console.log "Alert newUserList with leveldown: ", newUserList.length
            console.log "Alert newUserList with leveldown: ", newUserList
            return newUserList;


          addUser = (users) =>
            (user, done) =>
              #Add any calculated field and logic here
              user = @sanitizeUserFields(user)
              if forRepView
                delete user.dob
                delete user.isAdmin
                delete user.isOutfitter
                delete user.imported
                delete user.internalNotes
                delete user.needsWelcomeEmail
                delete user.welcomeEmailSent
                delete user.needsPointsEmail
                delete user.pointsEmailSent
                delete user.powerOfAttorney
                delete user.source
                delete user.username
                delete user.modified
                delete user.residence
              user.isAppUser = true if user.devices?.length
              user.text = "#{user.first_name} #{user.last_name}, #{user.clientId}" if user.clientId
              user.text = "#{user.first_name} #{user.last_name}" if !user.clientId
              if user.text.indexOf("undefined") > -1
                user.text = "#{user.text}, #{user._id}"
              if !user.created
                timestamp = user._id.toString().substring(0,8)
                createdDate = new Date( parseInt( timestamp, 16 ) * 1000 )
                user.created = createdDate
              return done err, user

          async.mapSeries users, addUser(users), (err, users) =>
            return cb err if err
            # Create the Tree by starting with all users with no parents and build the tree "down"
            if topUser
              usersTree = assignLevels(users, topUser, null)
              usersTreeFlattened = usersTree
            else
              cb "Error: Downstream users requested but top user not specified."

            return cb null, usersTree, usersTreeFlattened



  }

  _.bindAll.apply _, [Reports].concat(_.functions(Reports))
  return Reports
