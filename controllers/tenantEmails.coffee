_ = require "underscore"
async = require "async"
emailTemplates = require 'email-templates'
ejs = require "ejs"
moment = require 'moment'
nodemailer = require 'nodemailer'
path = require 'path'
String = require 'string'
amqp        = require "amqp"


module.exports = (Point, State, TenantEmail, User, UserState, logger, Zipcode, QueueConnectionOptions) ->

  TenantEmails = {

    adminRead: (req, res) ->
      TenantEmail.findById req.params.id, (err, tenantEmail) ->
        return res.json err, 500 if err
        res.json tenantEmail

    adminByType: (req, res) ->
      TenantEmail.findByType req.params.type, req.tenant._id, (err, tenantEmail) ->
        return res.json err, 500 if err
        res.json tenantEmail

    delete: (req, res) ->
      id = req.params.id
      TenantEmail.delete id, req.tenant._id, (err) ->
        return res.json err, 500 if err
        res.json {message: "Email deleted"}

    getStateByUserId: (userId, cb) ->

      User.findById userId, (err, user) ->
        return cb err if err

        Zipcode.findByCode user.mail_postal, (err, zipcode) ->
          return cb err if err
          return cb null, {} unless zipcode

          State.findByAbbreviation zipcode.state, (err, state) ->
            return cb err if err
            return cb null, state

    sendTest: (req, res) ->
      return res.json {error: "userId or clientIds is required"}, 500 unless req?.body?.userId or req?.body?.clientIds
      return res.json {error: "tenantEmailId is required"}, 500 unless req?.body?.tenantEmailId
      return res.json {error: "task is required"}, 500 unless req?.body?.task

      getTime = -> moment().format('YYYY-MM-DD HH:mm:ss')
      console.log "sendTest req.body", req.body

      #SEND WELCOME EMAIL (with new user's password, if the welcome email hasn't already been sent
      @sendWelcomeEmail req.body.userId, req.tenant._id, (err, welcomeMsg) =>
        console.log "Check sendWelcomeEmail ignored as it failed with an error: ", err if err
        console.log "Check sendWelcomeEmail succeeded welcomeMsg: ", welcomeMsg if welcomeMsg
        conRMQ = amqp.createConnection(QueueConnectionOptions)

        #conRMQ.on 'error', (err) ->
        #  console.log "Error connecting to rabbitMQ: ", err
        #  console.log "#{getTime()} - Disconnecting from rabbitMQ"
        #  conRMQ.disconnect()
        #  return res.json {error: "Error connecting to rabbitMQ: " + err}, 500

        conRMQ.on 'ready', ->
          console.log "#{getTime()} - conRMQ Connected to rabbitMQ"
          conRMQ.queue "task_queue",
            autoDelete: false
            durable: true
          , (queue) ->
            console.log "#{getTime()} - Queue ready"
            msg = {
              task: req.body.task
              priority: 1
              message:
                userId: req.body.userId
                clientIds: req.body.clientIds
                tenantEmailId: req.body.tenantEmailId
                huntCatalogId: req.body.huntCatalogId
                customNote: req.body.customNote
                additionalEmails: req.body.additionalEmails
                sendAsTest: true
            }
            conRMQ.publish "task_queue", msg, {deliveryMode: 2}
            setTimeout ->
              #console.log "#{getTime()} - Disconnecting from rabbitMQ"
              console.log "returning from rabbitMQ publish call"
              #conRMQ.disconnect()
              return res.json msg
            , 200

    send: (req, res) ->
      #TODO: THIS NEEDS TO BE REPLACED WITH ADDING A REQUEST TO THE QUEUE AFTER GETTING POINTS/DRAWRESULTS.  DON"T SEND EMAIL FROM HERE.
      return res.json {error: "Sending end of year email to all users is not currently allowed."}, 500
      async.waterfall [
        (next) ->
          TenantEmail.findById req.params.id, (err, template) ->
            return next err if err
            return next {error: "Email template not found"} unless template
            next null, {template}

        (data, next) ->
          User.findByTenant req.tenant._id, {internal: false}, (err, users) ->
            return next err if err
            return next {error: "No users found"} unless users?.length
            data.users = users
            next null, data

        (data, next) ->
          State.index (err, states) =>
            return next err if err
            for user, i in data.users
              data.users[i].states = []
              for state in states
                data.users[i].states.push _.clone state

            next null, data

        (data, next) =>
          getHomeStates = (user, cb) =>
            @getStateByUserId user._id, (err, home) ->
              return cb err if err
              user.home = home
              cb()

          async.map data.users, getHomeStates, (err) ->
            return next err if err
            next null, data

        (data, next) ->
          getStatesIds = (user, cb) =>
            UserState.byUser user._id, (err, stateIds) ->
              return cb err if err
              user.stateIds = stateIds
              cb()

          async.map data.users, getStatesIds, (err) ->
            return next err if err
            next null, data

        (data, next) ->
          for user in data.users
            for stateId in user.stateIds
              for state in user.states
                if state._id.toString() is stateId.stateId.toString()
                  state.cid = stateId.cid
                  break

          next null, data

        (data, next) ->
          for user in data.users
            if user.home?._id
              for state in user.states
                if state._id.toString() is user.home._id.toString()
                  state.home = true
                  break

          next null, data

        (data, next) ->
          addPointsToState = (user, cb) ->
            logger.info "called Point.addToState:", user._id
            async.map user.states, Point.addToState(user._id), (err, results) ->
              logger.info "results #{user.name}:", results

              return cb err if err
              user.states = results
              cb null, user

          async.map data.users, addPointsToState, (err, results) ->
            return next err if err
            for result in results
              logger.info "###### RESULT: #{result.name}:", result
            data.users = results
            next null, data
      ],
      (err, data) =>
        # send out emails here
        return res.json err, 500 if err

        transport = nodemailer.createTransport("SMTP",
          host: "smtp.gmail.com"
          port: 465
          secureConnection: true
          auth:
            user: "support@gotmytag.com"
            pass: "UfgipHac2"
        )

        templatesDir = path.join(__dirname, '../email')
        emailTemplates templatesDir, (err, template) =>
          logger.info "emailTemplates error:", err if err
          return res.json err, 500 if err
          header = "<p>" + data.template.header.split(/\n+/).join('</p><p>') + "</p>"
          footer = "<p>" + data.template.footer.split(/\n+/).join('</p><p>') + "</p>"

          for user in data.users
            logger.info "user:", user
            user.tenant = req.tenant
            user.header = ejs.render(header, user)
            user.footer = ejs.render(footer, user)
            @sendPointsEmail user, template, transport

    sendPointsEmail: (user, template, transport, next = ->) ->
      #TODO: DON"T SEND EMAIL HERE, ADD TO QUEUE INSTEAD
      return next()
      logger.info "before points template"
      template "points", user, (err, html, text) ->
        if err
          logger.info "email template error:", err
          return

        mailOptions =
          from: "GotMyTag Support <support@gotmytag.com>"
          to: user.email
          subject: "#{user.first_name}'s #{moment().format('YYYY')} Hunting Preference Points - GotMyTag.com"
          html: html
          text: text

        mailOptions.subject = String(mailOptions.subject).template(user).s
        logger.info "send points email:", mailOptions

        # send mail with defined transport object
        #transport.sendMail mailOptions, (err, response) ->
        #  if err
        #    logger.info "emailTransport error", err
        #  else
        #    logger.info "Email sent: " + response.message
        #  next()

    sendWelcomeEmail: (userId, tenantId, cb) ->
      return cb null, "skipping sendWelcomeEmail check" #TODO: TEST THIS, BEFORE I CHANGED to conRMQ2 it caused all emails to not send
      return cb "userId is required" unless userId
      return cb "tenantId is required" unless tenantId

      User.byId userId, {}, (err, user) ->
        return cb err if err
        return cb "user not found for userId #{userId}" unless user
        return cb null, "welcome email already sent" if user.welcomeEmailSent and user.needsWelcomeEmail is false

        TenantEmail.findEnabledByType "Welcome", tenantId, (err, tenantEmail) ->
          return cb err if err
          return cb "welcome email template doesn't exist for tenantId: #{tenantId}" unless tenantEmail

          getTime = -> moment().format('YYYY-MM-DD HH:mm:ss')
          console.log "sendWelcomeEmail sending... "

          conRMQ2 = amqp.createConnection(QueueConnectionOptions)

          #conRMQ2.on 'error', (err) ->
          #  console.log "Error connecting to rabbitMQ: ", err
          #  console.log "#{getTime()} - Disconnecting from rabbitMQ"
          #  conRMQ2.disconnect()
          #  return res.json {error: "Error connecting to rabbitMQ: " + err}, 500

          conRMQ2.on 'ready', ->
            console.log "#{getTime()} - conRMQ2 Connected to rabbitMQ"
            conRMQ2.queue "task_queue",
              autoDelete: false
              durable: true
            , (queue) ->
              console.log "#{getTime()} - Queue2 ready"

              msg = {
                task: "welcome_email.send"
                priority: 1
                message:
                  userId: userId
                  tenantEmailId: tenantEmail._id
              }

              conRMQ2.publish "task_queue", msg, {deliveryMode: 2}
              setTimeout ->
                console.log "returning from rabbitMQ publish2 call"
                #conRMQ2.disconnect()
                return cb null, msg
              , 200


    save: (req, res) ->
      req.body.tenantId = req.tenant._id
      tenantEmail = new TenantEmail req.body
      tenantEmail.save (err, tenantEmail) ->
        return res.json err, 500 if err
        res.json tenantEmail

    update: (req, res) ->
      return res.json {error: 'Email id required'}, 400 unless req?.body?._id

      tenantEmailId = req.body._id
      delete req.body._id
      req.body.tenantId = req.tenant._id

      TenantEmail.findOne {_id: tenantEmailId}, (err, tenantEmail) ->
        return res.json {error: err}, 500 if err

        for index, value of req.body
          tenantEmail.set index, value

        logger.info "save tenant email:", tenantEmail.toJSON()
        tenantEmail.save (err) ->
          return res.json {error: err}, 500 if err
          res.json tenantEmail.toJSON()
  }

  _.bindAll.apply _, [TenantEmails].concat(_.functions(TenantEmails))
  return TenantEmails
