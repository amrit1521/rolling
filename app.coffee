_          = require "underscore"
bodyParser = require "body-parser"
cluster    = require "cluster"
cors       = require "cors"
device     = require "express-device"
dnode      = require "dnode"
domain     = require "domain"
e          = require "std-error"
express    = require "express"
fs         = require "fs"
http       = require "http"
https      = require "https"
moment     = require "moment"
morgan     = require "morgan"
multer     = require "multer"
path       = require "path"
shoe       = require "shoe"
toobusy    = require "toobusy-js"
util       = require "util"

toobusy.maxLag(60 * 1000) # Max lag in milliseconds

config  = require "./config"

exports.createServer = ->
  config.resolve (
    api
    api_rbo
    api_rbo_rrads
    auth
    AWSStorage
    bots
    captainsLogs  
    drawResults
    email
    home
    hunt_choices
    hunt_options
    hunts
    logger
    MultiTenant
    points
    postals
    PUBNUB_SUBSCRIBE_KEY
    SEND_STARTUP_EMAIL
    reminders
    NODE_ENV
    notifications
    searches
    states
    tenantEmails
    tenants
    user_states
    users
    utahs
    clients
    serviceRequests
    huntCatalogs,
    purchases,
    views,
    reports
  ) ->

    logger.info "Start createServer"
    app = express()
    app.use cors()

    storage = new AWSStorage();
    upload = multer({ storage: storage });
    gmtUpload = upload.fields([{ name: 'uploadedFiles' }]);
    m_addFilesToReq = multer()
    addFilesToReq = m_addFilesToReq.fields([{ name: 'uploadedFiles' }]);

    # expose jquery-ui images publicly
    app.use((req, res, next) ->
      console.log 'req.url:59', req.url
      req.url = req.url.replace("/assets/styles/images", '/img/jquery-ui') if req.url.search('/assets/styles/images') is 0
      next()
    )

    app.use (req, res, next) ->
      if toobusy()
        res.send 503, "I'm busy right now, sorry."
      else
        next()
      return

    searchBots = [
      'googlebot'
      'yahoo'
      'bingbot'
      'baiduspider'
      'facebookexternalhit'
      'twitterbot'
      'rogerbot'
      'linkedinbot'
      'embedly'
      'quora link preview'
      'showyoubot'
      'outbrain'
    ]

    app.use (req, res, next) ->
      userAgent = req.headers['user-agent']

      console.log "agent:", userAgent
      console.log "path:", req.path
      console.log "url:", req.url

      # if request is for / and is bot then use _escaped_fragment_
      if userAgent and searchBots.some((agent) -> ~userAgent.toLowerCase().indexOf(agent)) and req.url is '/'
        console.log "render for bot"
        return bots.render req, res

      next()

    ###
    # If a GET request had a content-type header and a content-length header the bodyParser chokes
    ###
    app.use(
      (req, res, next) ->
        if req.method is 'GET'
          delete req.headers['content-type'] if req?.headers?['content-type']
          delete req.headers['content-length'] if req?.headers?['content-length']
        next()
    )

    app.use(e.defaultHandler)
    app.use morgan(':remote-addr - :req[x-forwarded-for] - - [:date] ":method :url HTTP/:http-version" :status :res[content-length] :response-time', {stream: logger.winstonStream})

    # parse application/x-www-form-urlencoded
    app.use bodyParser.urlencoded({ extended: false })

    # parse application/json
    #app.use bodyParser.json()
    app.use(bodyParser.json({limit: "50mb"}));
    app.use(bodyParser.urlencoded({limit: "50mb", extended: true, parameterLimit:50000}));

    
    

    # Attach req.user
    app.use auth.user

    # Attach req.tenant
    app.use MultiTenant.tenant 
     

    
    app.get '/about', (req, res) ->
        fs.readFile path.join(__dirname, 'app/www/about.html'), {encoding: "utf8"}, (err, aboutPage) ->
          if err
            console.error 'Error reading about.html:', err
            return res.status(500).send 'Error loading About page'
          
          # Define tenant data
          tenant = {
            _id: "12345"
            domain: "http://localhost/"
            logo: "logo.png"
            name: "Example Tenant"
            url: "http://localhost:5003"
          }

          # Replace tenant-specific placeholders in the HTML
          aboutPage = aboutPage.replace /{{tenant\.name}}/g, tenant.name
          aboutPage = aboutPage.replace /{{tenant\.logo}}/g, tenant.logo
          aboutPage = aboutPage.replace /{{tenant\.url}}/g, tenant.url

          # Send the modified HTML content
          res.setHeader 'content-type', 'text/html; charset=UTF-8'
          res.end aboutPage 

    app.get "/", (req, res) ->
      if req.query?._escaped_fragment_?.length
       return res.json "Not Foundy", 404 if req.query._escaped_fragment_.search(/\/admin\//) is 0
       return bots.render req, res
      else
      
        fs.readFile path.join(__dirname, 'app/www/index.html'), {encoding: "utf8"}, (err, index) ->
          # tenant = "{_id: \"12345\", domain: \"http://localhost/\", logo: \"logo.png\", name: \"Example Tenant\", url: \"http://localhost:5003\"}"
          tenant = "{_id: \"#{req.tenant._id}\", domain: \"#{req.tenant.domain}\", logo: \"#{req.tenant.logo}\", name: \"#{req.tenant.name}\", url: \"#{req.tenant.url}\"}"
          console.log 'index:138:', index
          console.log 'ttttttttttttttttttttttttttttttttttt', index
          index = index.replace "{{tenant}}", tenant
          index = index.replace /{{tenant\.name}}/g, req.tenant.name
          index = index.replace /{{tenant\.logo}}/g, req.tenant.logo
          res.setHeader 'content-type', 'text/html; charset=UTF-8'
          res.end index
          index = null

     app.get "/testing", (req, res) ->
      logger.info "admin url:"


    app.get "/admin", (req, res) ->
      logger.info "admin url:" + util.inspect(req.url, {depth: 5})
      logger.info "have user" if req.user
      return res.redirect("#/admin") if req.user
      res.setHeader 'content-type', 'text/html; charset=UTF-8'
      # res.json({title: "home", tenant: req.tenant})
      res.render('index', {title: "home", tenant: req.tenant})

    app.get "/admin/drawresults/report/:state", auth.authenticate, drawResults.adminReport

    app.get "/admin/emails/send/:id", auth.authenticate, tenantEmails.send
    app.get "/admin/emails/type/:type", auth.authenticate, tenantEmails.adminByType
    app.put "/admin/emails", auth.authenticate, tenantEmails.update
    app.post "/admin/emails", auth.authenticate, tenantEmails.save
    app.post "/admin/emails/sendTest", auth.authenticate, tenantEmails.sendTest

    app.delete "/admin/reminders/:id", auth.authenticate, reminders.adminDelete
    app.get "/admin/reminders/read/:id", auth.authenticate, reminders.adminRead
    app.get "/admin/reminders/index", auth.authenticate, reminders.adminIndex
    app.post "/admin/reminders/save", auth.authenticate, reminders.adminSave
    app.post "/admin/reminders/test", auth.authenticate, reminders.adminTest

    app.get "/admin/report/users", auth.authenticate, reports.adminUsers
    app.get "/admin/report/usersTree", auth.authenticate, reports.adminUsersTree
    app.post "/admin/report/purchases", auth.authenticate, reports.adminPurchases
    app.get "/admin/report/purchases/tenant/:userId", auth.authenticate, reports.adminPurchases
    app.get "/admin/report/purchases/outfitter/:userId", auth.authenticate, reports.outfitterPurchases
    app.post "/admin/report/stats", auth.authenticate, reports.adminStats

    app.post "/rep/report/commissions/rep", auth.authenticate, reports.repCommissions
    app.post "/rep/report/purchases/rep", auth.authenticate, reports.repPurchases
    app.post "/rep/report/users/search", auth.authenticate, reports.repUsers
    app.get "/rep/report/users/downstream/:userId", auth.authenticate, reports.repUsersDownstream

    app.get "/admin/states/index", auth.authenticate, states.adminIndex
    app.get "/admin/states/:id", auth.authenticate, states.adminRead
    app.put "/admin/states", auth.authenticate, states.update
    app.post "/admin/states", auth.authenticate, states.create

    app.get "/admin/tenants/index", auth.authenticate, tenants.adminIndex
    app.get "/admin/tenants/:id", auth.authenticate, tenants.adminRead
    app.delete "/admin/tenants/:id", auth.authenticate, tenants.delete
    app.put "/admin/tenants", auth.authenticate, tenants.update
    app.post "/admin/tenants", auth.authenticate, tenants.save
    app.post "/admin/tenants/pushrrads", auth.authenticate, tenants.adminPushToRRADS
    app.post "/admin/tenants/billing/:id", auth.authenticate, tenants.adminBilling

    app.get "/admin/servicerequests/index", auth.authenticate, serviceRequests.adminIndex
    app.get "/admin/servicerequests/:id", auth.authenticate, serviceRequests.adminRead
    #app.delete "/admin/servicerequests/:id", auth.authenticate, serviceRequests.adminDelete
    app.put "/admin/servicerequests", auth.authenticate, serviceRequests.update
    #app.post "/admin/servicerequests", auth.authenticate, serviceRequests.save

    app.get "/admin/hunts/all/applications", auth.authenticate, hunts.adminAllApplications
    app.get "/admin/hunts/index/:stateId", auth.authenticate, hunts.adminIndex
    app.get "/admin/hunts/:id", auth.authenticate, hunts.adminRead
    app.put "/admin/hunts", auth.authenticate, hunts.update
    app.post "/admin/hunts", auth.authenticate, hunts.create

    app.get "/admin/huntcatalog/index", auth.authenticate, huntCatalogs.adminIndex
    app.get "/admin/huntcatalog/:id", auth.authenticate, huntCatalogs.adminRead
    #app.delete "/admin/huntcatalog/:id", auth.authenticate, huntCatalogs.adminDelete
    app.put "/admin/huntcatalog", auth.authenticate, huntCatalogs.upsert
    #app.post "/admin/huntcatalog", auth.authenticate, huntCatalogs.save
    app.post "/admin/huntcatalog/mediaAdd/:id/:token", gmtUpload, huntCatalogs.mediaAdd
    app.post "/admin/huntcatalog/mediaRemove/:id/:token", huntCatalogs.mediaRemove
    app.get "/huntcatalog/index", huntCatalogs.index
    app.get "/huntcatalog/:id", huntCatalogs.read
    app.post "/huntcatalog/purchase/:id", huntCatalogs.purchase
    app.get "/ref/huntcatalogs/:referrer", api.handleReferrerHuntCatalog
    app.get "/ref/huntcatalog/:referrer/:id", api.handleReferrerHuntCatalog

    app.post "/api/v1/points/client/state", api.pointsClientState
    app.post "/api/v1/register", api.importUser
    app.post "/api/v1/user", api.importUser
    app.post "/api/v1/state", api.state
    app.post "/api/v1/drawresult", api.drawresult
    app.post "/api/v1/stateaccount", api.createStateAccount
    app.post "/api/v1/populatestateaccount", api.populateStateAccount
    app.post "/api/v1/receipts", api.receipts
    app.post "/api/v1/usersummary", api.usersummary
    app.post "/api/v1/refreshPoints", api.refreshPoints
    app.post "/api/v1/huntCatalogs", api.huntCatalogs
    app.post "/api/rbo/v1/huntCatalogs", api_rbo.huntCatalogs
    app.post "/api/rbo/v1/huntCatalogs/share", api_rbo.huntcatalog_share
    app.post "/api/rbo/v1/login", api_rbo.login
    app.post "/api/rbo/v1/login_sso", api_rbo.login_sso
    app.post "/api/rbo/v1/user/forgotpassword", api_rbo.user_forgotPassword
    app.post "/api/rbo/v1/user/changepassword", api_rbo.user_changePassword
    app.get "/api/rbo/v1/user/index", auth.authenticate, api_rbo.user_index
    app.get "/api/rbo/v1/user", api_rbo.user_get
    app.get "/api/rbo/v1/user/paymentinfo", auth.authenticate, api_rbo.user_getPaymentInfo
    app.post "/api/rbo/v1/user/paymentinfo", auth.authenticate, api_rbo.user_upsertPaymentInfo
    app.get "/api/rbo/v1/user/webhook/mailchimp", api_rbo.webhook_mailchimp_ping
    app.post "/api/rbo/v1/user/webhook/mailchimp", api_rbo.webhook_mailchimp
    app.post "/api/rbo/v1/user/notification", auth.authenticate, api_rbo.user_notifications
    app.post "/api/rbo/v1/user/reminders", auth.authenticate, api_rbo.user_reminders
    app.post "/api/rbo/v1/user/user_upsert_rads", auth.authenticate, api_rbo_rrads.user_upsert_rads
    app.post "/api/rbo/v1/user/reassign_rep_downline_all", auth.authenticate, api_rbo_rrads.reassign_rep_downline_all
    app.post "/api/rbo/v1/user/user_refresh_from_rrads", auth.authenticate, api_rbo_rrads.user_refresh_from_rrads
    app.post "/api/rbo/v1/user", api_rbo.user_create
    app.put "/api/rbo/v1/user", auth.authenticate, api_rbo.user_update
    app.get "/api/rbo/v1/purchase", auth.authenticate, api_rbo.purchase_byId
    app.post "/api/rbo/v1/purchase", auth.authenticate, api_rbo.purchase_create
    app.post "/api/rbo/v1/purchase_from_rrads", auth.authenticate, api_rbo.purchase_from_rrads
    app.get "/api/rbo/v1/purchase/byuser", auth.authenticate, api_rbo.purchase_byuser
    app.post "/api/rbo/v1/contact", api_rbo.servicerequest_create
    app.get "/api/rbo/v1/reminder/index", auth.authenticate, api_rbo.reminders_index
    app.post "/api/rbo/v1/hunt_application", auth.authenticate, api_rbo.huntApplication
    app.post "/api/rbo/v1/repdashboard/api_req", auth.authenticate, api_rbo.repDashboardAPI
    app.post "/api/rbo/v1/admindashboard/api_req", auth.authenticate, api_rbo.adminDashboardAPI
    app.post "/api/rbo/v1/admin_qb_api/api_req", auth.authenticate, api_rbo.adminQB_API
    app.get "/api/rbo/v1/hunts/all/applications", auth.authenticate, api_rbo.adminAllApplications
    app.post "/api/rbo/v1/sendemail/contact_advisor", api_rbo.contact_advisor

    app.post "/api/rbo/v1/test", api_rbo.run_test

    app.post "/captains_logs/log", captainsLogs.log

    app.get "/clientstates/:userId/:year", auth.authenticate, clients.read

    app.get "/download/:referrer", api.handleReferrer

    app.get "/hunts/available/:stateId", auth.authenticate, hunts.available
    app.get "/hunts/by_state/:stateId", auth.authenticate, hunts.byState
    app.get "/hunts/current/:stateId", auth.authenticate, hunts.currentByState
    app.get "/hunts/:id", auth.authenticate, hunts.get
    app.get "/hunts/options/:id", auth.authenticate, hunts.options


    app.get "/hunt_options/:huntId", auth.authenticate, hunt_options.get

    app.get "/hunt_choices/:userId/:huntId", auth.authenticate, hunt_choices.get
    app.get "/hunt_choices/group/:huntId/:groupId", auth.authenticate, hunt_choices.byGroup
    app.get "/hunt_choices/user/group/:userId/:huntId", auth.authenticate, hunt_choices.groupCheck
    app.post "/hunt_choices", auth.authenticate, hunt_choices.save
    app.post "/hunt_choices/run", auth.authenticate, hunt_choices.run
    app.post "/hunt_choices/batch/test", auth.authenticate, hunt_choices.batchTest
    # app.post "/hunt_choices/batch/run", auth.authenticate, hunt_choices.batchRun


    app.get "/notifications", auth.authenticate, notifications.read
    app.get "/notifications/allread", auth.authenticate, notifications.markAllRead

    app.get "/points/all/:userId", auth.authenticate, points.all
    app.get "/points/:userId/state/:stateId", auth.authenticate, points.byState
    app.get "/points/:userId/state/:stateId/:cid", auth.authenticate, points.byState
    app.get "/points/:userId/state/:stateId/:cid/:refresh", auth.authenticate, points.byState
    app.post "/points/montana", auth.authenticate, points.getMontanaPoints

    app.get "/postals/state/:code", postals.getState

    app.get "/purchase/:id", auth.authenticate, purchases.read
    app.get "/admin/purchase/index", auth.authenticate, purchases.adminIndex
    app.put "/admin/purchase/commissions", auth.authenticate, huntCatalogs.adminCommissions
    app.put "/admin/purchase/commissions/markaspaid", auth.authenticate, purchases.adminCommissionsMarkAsPaid
    app.put "/admin/purchase/commissions/paypal", auth.authenticate, purchases.adminPaypal
    app.get "/purchase/byUserId/:userId", auth.authenticate, purchases.byUserId
    app.get "/purchase/byInvoiceNumberPublic/:invoiceNumber", auth.authenticate, purchases.byInvoiceNumberPublic
    #app.post "/admin/purchase/fileAdd/:id/:token", gmtUpload, purchases.fileAdd
    #app.post "/admin/purchase/fileRemove/:id/:token", purchases.fileRemove
    app.put "/admin/purchase/confirmations/send", auth.authenticate, purchases.sendConfirmations
    app.put "/admin/purchase/payment/record", auth.authenticate, purchases.recordPayment


    app.post "/reminders/states", reminders.byStates

    app.post "/searches", auth.authenticate, searches.find

    app.get "/searches/application/:search/:range/:status", auth.authenticate, searches.search
    app.get "/searches/application/latest/:userId/:huntId/:year", auth.authenticate, searches.applicationByUserHuntYear
    app.get "/searches/card/:userId/:index", auth.authenticate, users.cardByUserIndex

    app.get "/states/active", states.active
    app.post "/states/find/user", states.findUser
    app.get "/states/index", states.index
    app.get "/states/user/:id", auth.authenticate, states.byUser
    app.get "/states/:id", auth.authenticate, states.byId
    app.get "/states/init/:id", auth.authenticate, states.initByStateId
    app.get "/states/montana/captcha", states.montanaCaptcha

    app.get "/tenants", tenants.current

    app.post "/users/defaultUser", users.defaultUser
    app.post "/users/childUser", users.defaultUser
    app.get  "/users/cards/:id", auth.authenticate, users.cards
    app.post  "/users/cardUpdate", auth.authenticate, users.updateCard
    app.get  "/users/children/:userId", auth.authenticate, users.children
    app.get  "/users/verify", auth.authenticate, users.verify
    app.get  "/users/:id", auth.authenticate, users.read
    app.get  "/users/:id/:topToken", auth.authenticate, users.read
    app.post "/users", users.register
    app.put  "/users", auth.authenticate, users.update
    app.put  "/users/admin/:userId/:isAdmin", auth.authenticate, users.setAdmin
    app.post "/users/changepassword", auth.authenticate, users.changePassword
    app.post "/users/changeparent", auth.authenticate, users.changeParent
    app.post "/users/device/register", auth.authenticate, users.registerDevice
    app.post "/users/login", users.login
    app.get "/users/login", users.login
    app.post "/users/loginPassthrough", users.loginPassthrough
    app.post "/users/messages", auth.authenticate, users.sendMessage
    app.post "/users/register", users.register
    app.post "/users/client", auth.authenticate, users.updateClient
    app.put  "/users/reminders", auth.authenticate, users.updateReminders
    app.post  "/users/refer", auth.authenticate, users.checkRefer
    app.post  "/users/checkexists", auth.authenticate, users.checkExists
    app.post  "/users/testUsers", auth.authenticate, users.testUsers
    app.get  "/users/parent/rep/:userId", auth.authenticate, users.getParentAndRep
    app.get  "/users/emails/by/clients/:clientIds", auth.authenticate, users.getEmails
    app.post "/users/emails/send_welcome/emails", auth.authenticate, users.sendWelcomeEmails
    app.get  "/users/by/clientId/:clientId", users.getUserByClientId_public
    app.post "/users/admin/fileAdd/:id/:token", gmtUpload, users.fileAdd
    app.post "/users/admin/fileRemove/:id/:token", users.fileRemove
    app.post "/users/admin/parseuserimport/:id/:token", addFilesToReq, users.parseUserImport
    app.post "/users/admin/userimport/userimport", auth.authenticate, users.userImport
    app.post "/stamp/get", auth.authenticate, users.getStamp

    app.delete "/user_states/:userId/:stateId", auth.authenticate, user_states.delete

    app.get  "/utah/sportsmans/eligibility", auth.authenticate, utahs.eligibility
    app.get  "/utah/sportsmans", auth.authenticate, utahs.sportsmans

    app.get "/view/find", views.find
    app.post "/view", auth.authenticate, views.save

    app.get "/sitemap.xml", (req, res) ->
      fs.readFile path.join(__dirname, 'views/sitemap.xml'), {encoding: "utf8"}, (err, index) ->
        console.log 'index:252:', index
        index = index.replace /{{tenant\.domain}}/g, req.tenant.domain
        index = index.replace /{{currentDate}}/g, moment().format('YYYY-MM-DD')
        res.end index
        index = null

    # app.use express.static(__dirname + '/app/www')
    app.use express.static(path.join(__dirname, 'app/www'))
    # app.use(express.static('public'));


    console.log "Set remoteCommands"
    app.remoteCommands = {
      auth: users.auth
      hearbeat: (stream, cb) -> cb {success: "OK"}
      ping: home.ping
      purchase: hunt_choices.purchase
    }

    # language packs
    app.get "/i18n/:language", (req, res) ->
      langagueFile = path.join(__dirname, "i18n/" + req.params.language + ".coffee")
      if fs.existsSync langagueFile
        language = require langagueFile
        return res.json language
      else
        res.json {}

    app.get "/templates/*", (req, res) ->
      console.log 'req.params:278:', req.params
      filePath = './assets/templates/' + req.params[0].replace(/\.html$/, '')
      realPath = path.join(__dirname, filePath + '.jade')
      fs.exists realPath, (exists) ->
        if not exists
          res.end()
          return
        res.render realPath, {tenant: req.tenant}

    # Send worker startup email
    if NODE_ENV isnt "development"
      message = "A node started at: #{moment().format('YYYY-MM-DD HH:mm:ss ZZ')} - rollingbones.com"
      logger.info message
      mailOptions =
        from: "RBO Errors <info@rollingbonesoutfitters.com>"
        to: "scott@rollingbonesoutfitters.com"
        subject: message

      if SEND_STARTUP_EMAIL != false and SEND_STARTUP_EMAIL != "false"
        email.sendMail mailOptions, (err, response) ->
          return logger.error "Startup email failed:" + util.inspect(err, {depth: 5}) if err
          logger.info "Startup email sent:" + util.inspect(response, {depth: 5})

    return app

if module is require.main
  app = exports.createServer()

  config.resolve (HUNTINTOOL_MEMORY_LIMIT, PORT, PORT_SSL, NODE_ENV, SSL_DOMAIN, Tenant, logger) ->

    closeServer = (server, cb = ->) ->
      try
        logger.error "close the serveru"
        # server.close()
        logger.error "disconnect the workeru"
        # cluster.worker?.disconnect()


        killtimer = setTimeout(->
          logger.error "kill the process"
          process.exit 1
          return
        , (1000 * 60 * 5)) # make sure we close down within 5 minutes

        # But don't keep the process open just for that!
        killtimer.unref()
      catch err
        return cb err

      cb()

    setupDomain = (server, app, req, res) ->
      d = domain.create()
      d.on 'error', (err) ->
        console.log "Error stack:", err.stack
        console.log "A domain error occurred:", err

        console.log "\n\n\n\ncloseServer due to ERROR\n\n\n\n"
        closeServer server, (err) ->
          return console.log "Error disconnecting.1:", err if err

          res.statusCode = 500
          res.setHeader 'content-type', 'text/plain'
          res.end 'Oops, there was a problem!\n'

      d.add req
      d.add res

      d.run ->

        console.log "memory:", process.memoryUsage().heapUsed
        app req, res

        if process.memoryUsage().heapUsed > HUNTINTOOL_MEMORY_LIMIT
          console.log "Memory limit exceeded"
          console.log "\n\n\n\ncloseServer due to MEMORY LIMIT\n\n\n\n"
          closeServer server, (err) ->
            return console.log "Error disconnecting.2:", err if err

    logger.info "Started on port:#{PORT} in #{NODE_ENV} mode"
    server = http.createServer (req, res) ->
      setupDomain server, app, req, res

    server.listen(PORT)

    process.on 'uncaughtException', (err) ->
      logger.error "Uncaught Error:" + util.inspect(err, {depth: 5})
      logger.error err.stack
      closeServer server, (err) ->
        return console.log "Error disconnecting.2:", err if err

    sock = shoe((stream) ->
      commands = _.clone app.remoteCommands
      addStream = (name, method) ->
        local = this
        ->
          args = [].splice.call arguments, 0
          args.unshift stream
          method.apply local, args
          args = null

      for name, method of commands
        commands[name] = addStream name, method

      d = dnode(commands)
      d.pipe(stream).pipe d
      return
    )
    sock.install server, "/dnode"

#    Tenant.findByDomain SSL_DOMAIN, (err, tenant) ->
#      console.log "SSL_DOMAIN: ", SSL_DOMAIN
#      return console.log "Error finding domain:", err if err
#      return console.log "Domain not found" unless tenant
#
#      sslOptions =
#        key: tenant.ssl_key
#        cert: tenant.ssl_pem
#        # ca: fs.readFileSync("./ssl/ca.crt")
#        # requestCert: false
#        # rejectUnauthorized: false
#
#      secureServer = https.createServer sslOptions, (req, res) ->
#        setupDomain secureServer, app, req, res
#
#      secureServer.listen(PORT_SSL, ->
#        console.log "Secure Express server listening on port", PORT_SSL
#        return
#      )
#
#      sock.install secureServer, "/dnode"
