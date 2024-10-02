_        = require "underscore"
cors     = require "cors"
e        = require "std-error"
express  = require "express"
https    = require "https"
memwatch = require "memwatch-next"
moment   = require "moment"
toobusy  = require "toobusy-js"
util     = require "util"

toobusy.maxLag(60 * 1000) # Max lag in milliseconds

config  = require "./config"

process.on 'uncaughtException', (err) ->
  console.error "Uncaught Error:", err
  console.error err.stack
  throw err

exports.createServer = ->
  config.resolve (
    auth
    logger
    MultiTenant
    NODE_ENV

  ) ->
    memoryWarningLevel = 250 # 300MB

    process.on 'uncaughtException', (err) ->
      logger.error "Uncaught Error:" + util.inspect(err, {depth: 5})
      logger.error err.stack

    memwatch.on 'leak', (info) ->
      logger.error "MemWatch::Leak detected:" + util.inspect(info, {depth: 5})

    checkMemoryLimit = _.throttle (stats) ->
      if stats.current_base > (memoryWarningLevel * 1024 * 1024) and NODE_ENV isnt "development"
        warningTime = moment().format('YYYY-MM-DD HH:mm:ss ZZ')
        mailOptions =
          from: "RBO Errors <info@rollingbonesoutfitters.com>"
          to: "scott@rollingbonesoutfitters.com"
          subject: "A node has exceeded #{memoryWarningLevel}MB at: #{warningTime} - rollingbones.com"

        email.sendMail mailOptions, (err, response) ->
          return logger.error "Memory warning email failed:" + util.inspect(err, {depth: 5}) if err
          logger.info "Memory warning at #{warningTime} sent:" + util.inspect(response, {depth: 5})
    , (1 * 60 * 1000) # Once a minute
    , { trailing: true }

    memwatch.on 'stats', (stats) ->
      logger.info "MemWatch::Current stats:" + util.inspect(stats, {depth: 5})
      checkMemoryLimit(stats)

    logger.info "Start createServer"
    app = express()

    app.use cors()

    app.use (req, res, next) ->
      if toobusy()
        res.send 503, "I'm busy right now, sorry."
      else
        next()
      return


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
    app.use express.logger({stream: logger.winstonStream, format: ':remote-addr - :req[x-forwarded-for] - - [:date] ":method :url HTTP/:http-version" :status :res[content-length] :response-time' })

    app.use express.bodyParser()
    app.set('views', __dirname + '/views')
    app.set('view engine', 'jade')
    app.set('view options', { layout: false });

    # Attach req.tenant
    app.use MultiTenant.tenant




    app.get "/", drawResults.adminReport





    # Send worker startup email
    if NODE_ENV isnt "development"
      message = "A node started at: #{moment().format('YYYY-MM-DD HH:mm:ss ZZ')} - Messaging.rollingbones.com"
      logger.info message
      mailOptions =
        from: "RBO Messaging Errors <info@rollingbonesoutfitters.com>"
        to: "scott@rollingbonesoutfitters.com"
        subject: message

      email.sendMail mailOptions, (err, response) ->
        return logger.error "Messaging Startup email failed:" + util.inspect(err, {depth: 5}) if err
        logger.info "Messaging Startup email sent:" + util.inspect(response, {depth: 5})

    return app

if module is require.main
  app = exports.createServer()

  config.resolve (MSG_PORT_SSL, SSL_DOMAIN, Tenant, logger) ->

    Tenant.findByDomain SSL_DOMAIN, (err, tenant) ->
      return console.log "Error finding domain:", err if err
      return console.log "Domain not found" unless tenant

      sslOptions =
        key: tenant.ssl_key
        cert: tenant.ssl_pem

      secureServer = https.createServer(sslOptions, app)
      secureServer.listen(MSG_PORT_SSL, ->
        console.log "Secure Express server listening on port", MSG_PORT_SSL
        return
      )
