_ = require "underscore"
async = require "async"
moment = require 'moment'

module.exports = (Tenant, User, DrawResult, Message, Application, logger, api_rbo_rrads) ->

  Tenants = {

    adminIndex: (req, res) ->
      Tenant.all req.param('type'), (err, tenants) ->
        return res.json err, 500 if err
        res.json tenants

    adminRead: (req, res) ->
      Tenant.findById req.params.id, (err, tenant) ->
        return res.json err, 500 if err
        res.json tenant

    current: (req, res) ->
      tenant = _.pick req.tenant, '_id', 'domain', 'rrads_api_base_url', 'logo', 'name', 'url', 'cc_fee_percent'
      res.json tenant

    delete: (req, res) ->
      return res.json "Not Implemented", 500
      id = req.params.id
      Tenant.delete id, (err) ->
        return res.json err, 500 if err
        res.json {message: "Tenant deleted"}

    save: (req, res) ->
      return res.json "Unauthorized", 500 unless req.user?.isAdmin and req.user?.userType is "super_admin"
      tenant = new Tenant req.body
      return res.json "Missing Tenant Client Prefix is required", 500 unless tenant.clientPrefix
      adminUser = null
      async.waterfall [
        #Check if tenant client prefix is unique
        (next) ->
          Tenant.findByClientPrefix tenant.clientPrefix, (err, t_tenant) ->
            return next err if err
            return next "A tenant with the client prefix of '#{tenant.clientPrefix}' already exists.  The prefix must be unique.  Please try again." if t_tenant
            return next null, t_tenant

        #Save the tenant
        (results, next) ->
          tenant.save (err, tenant) ->
            return next err, tenant

        #Check if OSS Admin and Tenant Admin users exists, if not create them
        (tenant, next) =>
          @upsertDefaultUsers tenant, (err, adminUser) ->
            return next err, tenant

        #Create the tenant in RRADS
        (tenant, next) =>
          @adminPushToRRADS {tenant: tenant}, (err, results) ->
            console.log "Error: Failed to create tenant in RRADS.  Error: ", err if err
            return next null, tenant

      ], (err, tenant) ->
        return res.json err, 500 if err
        res.json tenant


    update: (req, res) ->
      return res.json "Unauthorized", 500 unless req.user?.isAdmin and req.user?.userType is "super_admin"
      return res.json {error: 'Tenant id required'}, 400 unless req?.body?._id

      tenantId = req.body._id
      delete req.body._id

      Tenant.findOne {_id: tenantId}, (err, tenant) =>
        return res.json {error: err}, 500 if err

        for index, value of req.body
          tenant.set index, value

        async.waterfall [
          #updat the tenant
          (next) ->
            logger.info "update tenant:", tenant.toJSON()
            tenant.save (err) ->
              return next err, null

          #Check if OSS Admin and Tenant Admin users exists, if not create them
          (results, next) =>
            @upsertDefaultUsers tenant, (err, adminUser) ->
              return next err, adminUser

        ], (err, results) ->
          return res.json {error: err}, 500 if err
          return res.json tenant.toJSON()

    adminBilling: (req, res) ->
      return res.json {error: 'Admin only report'}, 400 unless req?.user?.isAdmin
      return res.json {error: 'GMT Admin only report'}, 400 if req.body.allTenants and req?.user?.tenantId

      year = moment().format("YYYY")
      thisMonthStart = moment().startOf('month').format("YYYY-MM-DD")+"T00:00:00.000Z"
      thisMonthStart_d = new Date(thisMonthStart)
      thisMonthEnd = moment().endOf('month').format("YYYY-MM-DD")+"T23:59:59.999Z"
      thisMonthEnd_d = new Date(thisMonthEnd)
      lastMonthStart = moment().subtract(1, 'months').startOf('month').format("YYYY-MM-DD")+"T00:00:00.000Z"
      lastMonthStart_d = new Date(lastMonthStart)
      lastMonthEnd = moment().subtract(1, 'months').endOf('month').format("YYYY-MM-DD")+"T23:59:59.999Z"
      lastMonthEnd_d = new Date(lastMonthEnd)
      thisWeekStart = moment().startOf('week').format("YYYY-MM-DD")+"T00:00:00.000Z"
      thisWeekStart_d = new Date(thisWeekStart)
      thisWeekEnd = moment().endOf('week').format("YYYY-MM-DD")+"T23:59:59.999Z"
      thisWeekEnd_d = new Date(thisWeekEnd)
      lastWeekStart = moment().subtract(1, 'weeks').startOf('week').format("YYYY-MM-DD")+"T00:00:00.000Z"
      lastWeekStart_d = new Date(lastWeekStart)
      lastWeekEnd = moment().subtract(1, 'weeks').endOf('week').format("YYYY-MM-DD")+"T23:59:59.999Z"
      lastWeekEnd_d = new Date(lastWeekEnd)
      console.log "Billing Dates: ",  lastMonthStart_d, lastMonthEnd_d, thisMonthStart_d, thisMonthEnd_d, lastWeekStart_d, lastWeekEnd_d, thisWeekStart_d, thisWeekEnd_d

      tenantId = req.param('id')
      allTenants = req.body.allTenants
      return res.json {error: 'Tenant id required'}, 400 unless tenantId

      Tenant.findById tenantId, (err, tenant) ->
        console.log "Getting billing data for tenant #{tenant.name}:"
        async.parallel [
          # Get tenant user totals
          (done) ->
            console.log "getting user totals..."
            User.findByTenant tenant._id, {}, (err, users) ->
              userStats = {
                total: 0,
                total_thisMonth: 0,
                total_lastMonth: 0,
                total_thisWeek: 0,
                total_lastWeek: 0,
                members: 0,
                members_thisMonth: 0,
                members_lastMonth: 0,
                members_thisWeek: 0,
                members_lastWeek: 0,
                memberList: []
              }
              return done err, userStats unless users?.length
              userStats.total = users.length
              if !allTenants
                for user in users
                  created = user._id.getTimestamp()
                  userStats.members = userStats.members + 1 if user.memberId
                  userStats.total_thisMonth = userStats.total_thisMonth + 1 if created >= thisMonthStart_d and created <= thisMonthEnd_d
                  userStats.total_lastMonth = userStats.total_lastMonth + 1 if created >= lastMonthStart_d and created <= lastMonthEnd_d
                  userStats.total_thisWeek = userStats.total_thisWeek + 1 if created >= thisWeekStart_d and created <= thisWeekEnd_d
                  userStats.total_lastWeek = userStats.total_lastWeek + 1 if created >= lastWeekStart_d and created <= lastWeekEnd_d
                  userStats.members_thisMonth = userStats.members_thisMonth + 1 if user.memberId and created >= thisMonthStart_d and created <= thisMonthEnd_d
                  userStats.members_lastMonth = userStats.members_lastMonth + 1 if user.memberId and created >= lastMonthStart_d and created <= lastMonthEnd_d
                  userStats.members_thisWeek = userStats.members_thisWeek + 1 if user.memberId and created >= thisWeekStart_d and created <= thisWeekEnd_d
                  userStats.members_lastWeek = userStats.members_lastWeek + 1 if user.memberId and created >= lastWeekStart_d and created <= lastWeekEnd_d


                  if user.memberId and created >= thisMonthStart_d and created <= thisMonthEnd_d
                    userStats.memberList.push {
                      name: "#{user.first_name} #{user.last_name}"
                      userId: user._id
                      clientId: user.clientId
                      memberId: user.memberId
                      memberType: user.memberType
                      created: created
                      created_str: moment(created).format("MM/DD/YYYY  HH:MM:SS")
                    }
                    #console.log "MemberId: #{user.memberId}, created: #{created}, this week: #{created >= thisWeekStart_d and created <= thisWeekEnd_d}, last week: #{created >= lastWeekStart_d and created <= lastWeekEnd_d}, this month: #{created >= thisMonthStart_d and created <= thisMonthEnd_d}, last month: #{created >= lastMonthStart_d and created <= lastMonthEnd_d}"
              done err, userStats

          # Get tenant drawresults last month
          (done) ->
            #return done null, 0 #TODO: SKIPPING SO DON"T CRASH THE SERVER WITH LONG BAD QUERIES
            console.log "getting drawresults last month..."
            statusType = "all"
            stateId = "all"
            DrawResult.byStateResultsDateRange stateId, tenant._id, year, statusType, lastMonthStart, lastMonthEnd, (err, drawresults) ->
              byUserAndState = {}
              for drawresult in drawresults
                key = "#{drawresult.userId}|#{drawresult.stateId}"
                byUserAndState[key] = key unless byUserAndState[key]

              return done err, 0 unless Object.keys(byUserAndState).length
              done err, Object.keys(byUserAndState).length

          # Get tenant drawresults this month
          (done) ->
            #return done null, 0 #TODO: SKIPPING SO DON"T CRASH THE SERVER WITH LONG BAD QUERIES
            console.log "getting drawresults this month..."
            statusType = "all"
            stateId = "all"
            DrawResult.byStateResultsDateRange stateId, tenant._id, year, statusType, thisMonthStart, thisMonthEnd, (err, drawresults) ->
              byUserAndState = {}
              for drawresult in drawresults
                key = "#{drawresult.userId}|#{drawresult.stateId}"
                byUserAndState[key] = key unless byUserAndState[key]

              return done err, 0 unless Object.keys(byUserAndState).length
              done err, Object.keys(byUserAndState).length

          # Get tenant message notification sent last month
          (done) ->
            #return done null, 0 #TODO: SKIPPING SO DON"T CRASH THE SERVER WITH LONG BAD QUERIES
            console.log "getting message notification last month..."
            Message.byTenantDateRange tenant._id, lastMonthStart, lastMonthEnd, (err, messages) ->
              return done err, 0 unless messages?.length
              done err, messages.length

          # Get tenant message notification sent this month
          (done) ->
            #return done null, 0 #TODO: SKIPPING SO DON"T CRASH THE SERVER WITH LONG BAD QUERIES
            console.log "getting message notifications this month..."
            Message.byTenantDateRange tenant._id, thisMonthStart, thisMonthEnd, (err, messages) ->
              return done err, 0 unless messages?.length
              done err, messages.length

          # Get tenant applications done this last month
          (done) ->
            #return done null, 0 #TODO: SKIPPING SO DON"T CRASH THE SERVER WITH LONG BAD QUERIES
            console.log "getting applications last month..."
            Application.byPurchasedTenantDateRange tenant._id, lastMonthStart, lastMonthEnd, (err, applications) ->
              return done err, 0 unless applications?.length
              purchasedHunts = []
              for app in applications
                for huntId in app.huntIds
                  purchasedHunts.push huntId
              done err, purchasedHunts.length

          # Get tenant applications done this this month
          (done) ->
            #return done null, 0 #TODO: SKIPPING SO DON"T CRASH THE SERVER WITH LONG BAD QUERIES
            console.log "getting applications this month..."
            Application.byPurchasedTenantDateRange tenant._id, thisMonthStart, thisMonthEnd, (err, applications) ->
              return done err, 0 unless applications?.length
              purchasedHunts = []
              for app in applications
                for huntId in app.huntIds
                  purchasedHunts.push huntId
              done err, purchasedHunts.length

        ], (err, results) ->
          console.log "Billing #{tenant.name}"
          console.log "errors occured:", err if err
          return res.json err, 500 if err

          billingStats = results[0]
          billingStats.drawresults_lastMonth = results[1]
          billingStats.drawresults_thisMonth = results[2]
          billingStats.messages_lastMonth = results[3]
          billingStats.messages_thisMonth = results[4]
          billingStats.applications_lastMonth = results[5]
          billingStats.applications_thisMonth = results[6]
          tenant.billingStats = billingStats
          console.log "returning tenant billing stats: ", _.omit(billingStats, "memberList")
          return res.json tenant


    adminPushToRRADS: (req, res) ->
      if res?.json
        return res.json "Unauthorized", 500 unless req.user?.isAdmin and req.user?.userType is "super_admin"
        tenant = {tenant: req.body}
      else
        tenant = req
      api_rbo_rrads.pushTenantToRRADS tenant, (err_rrads, results) ->
        console.log "Error: failed to create tenant in RRADS with error: ", err_rrads if err_rrads
        if res?.json
          return res.json err_rrads, 500 if err_rrads
          return res.json results
        else
          return res err_rrads, results


    upsertDefaultUsers: (tenant, cb) ->
      adminUser = null
      adminClientId = "#{tenant.clientPrefix}S1"
      adminEmail = 'admin@osstnt.com'
      async.waterfall [
        (next) ->
          User.byClientId adminClientId, tenant._id, (err, admin_user) ->
            return next err if err
            if admin_user
              adminUser = admin_user
              console.log "OSS Admin User already exists for this tenant. #{admin_user.clientId}, #{admin_user._id}, #{admin_user.name}"
              return next err, tenant
            else
              userData = {
                "active" : true
                "isAdmin" : true,
                "type" : "local",
                "userType": "tenant_admin",
                "password" : "d51aaad6fd6837bb99356283a3b1e0d3e910467d",
                "name" : "OSS Admin",
                "first_name" : "OSS",
                "last_name" : "Admin",
                "email" : adminEmail,
                "clientId": adminClientId,
                "tenantId" : tenant._id
              }
              User.upsert userData, {}, (err, tUser) ->
                return next err if err
                return next "Failed to create default oss admin user for tenant." unless tUser
                User.upsert {_id: tUser._id, parentId: tUser._id}, {}, (err, tUser) ->
                  adminUser = tUser
                  #UPDATE RRADS
                  req = {
                    params: {
                      _id: tUser._id
                      tenantId: tenant._id
                    }
                  }
                  api_rbo_rrads.user_upsert_rads req, (errR, result) ->
                    console.log "Error failed to upsert the user to RRADS: ", errR if errR
                    return next err, tenant

        (results, next) ->
          User.findByUserType "tenant_admin", tenant._id, {}, (err, tenant_admin_users) ->
            return next err if err
            foundTenantAdmin = null
            for tenant_admin_user in tenant_admin_users
              if tenant_admin_user.clientId isnt adminClientId
                foundTenantAdmin = tenant_admin_user
                break
            if foundTenantAdmin
              console.log "Tenant Admin User already exists for this tenant. #{foundTenantAdmin.clientId}, #{foundTenantAdmin._id}, #{foundTenantAdmin.name}"
              return next err, results
            else
              userData = {
                "active" : true
                "isAdmin" : true,
                "type" : "local",
                "userType": "tenant_admin",
                "password" : "4d390fb676dcc2ab59fbbad83ec238f710697865",
                "name" : "Tenant Admin",
                "first_name" : "Tenant",
                "last_name" : "Admin",
                "email" : "tenantadmin@osstnt.com",
                "clientId": tenant.clientPrefix+"1",
                "tenantId" : tenant._id
                "isOutfitter": true,
                "parentId": adminUser._id
              }
              User.upsert userData, {}, (err, tUser) ->
                return next err if err
                return next "Failed to create default tenant admin user for tenant." unless tUser
                req = {
                  params: {
                    _id: tUser._id
                    tenantId: tenant._id
                  }
                }
                api_rbo_rrads.user_upsert_rads req, (errR, result) ->
                  console.log "Error failed to upsert the user to RRADS: ", errR if errR
                  return next err, tenant

      ], (err, results) ->
        return cb err, adminUser



  }

  _.bindAll.apply _, [Tenants].concat(_.functions(Tenants))
  return Tenants
