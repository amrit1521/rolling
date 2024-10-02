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
creditcard = require 'creditcard'
stream = require 'stream'
readline = require 'readline'

module.exports = (APN_CERT, APN_KEY, HF_APN_CERT, HF_APN_KEY, GCM_API_KEY, HF_GCM_API_KEY,
  Notification, Point, salt, Tenant, Token, User, Refer, Secure, logger,
  HuntinFoolTenantId, HuntinFoolClient, HuntinFoolState, RollingBonesTenantId,
  GotMyTagTenantId, GotMyTagDevTenantId, Custom, NavTools, APITOKEN, mailchimpapi, TENANT_IDS, api_rbo_rrads) ->

  Users = {
    auth: (stream, token, cb) ->
      console.log 'asdfasdf';
      async.waterfall [
        (next) ->
          domain = stream.headers.host.split(':')[0]
          domain = 'test.gotmytag.com' if domain is 'localhost'
          Tenant.findByDomain domain, (err, tenant) ->
            return next err if err

            if not tenant
              logger.info "Page not found"
              return next {error: "Page not found"}

            stream.tenant = tenant
            next()

        (next) ->
          console.log "Asdfsdaf"
          Token.findOne({token}).lean().exec (err, token) ->
            return next(err) if err
            return next({error: "Token not found"}, code: 404) unless token
            next null, token

        (token, next) ->
          console.log "Asdfsdaf"
          User.findById token.userId, internal: true, (err, user) ->
            return next err if err
            return next {error: "Token not found"}, code: 404 unless user
            stream.user = user
            next()
      ], cb

    cards: (req, res) ->
      console.log 'rkeq'
      return res.json {error: 'Unauthorized'}, 401 unless req.param('id') is req.user._id or req.user.isAdmin

      User.cards req.param('id'), (err, cards) ->
        return res.json (error: err), 500 if err
        res.json cards

    cardByUserIndex: (req, res) ->
      console.log 'rgheq'
      return res.json {error: "Unauthorized"}, 401 unless req.user.isAdmin
      index = req.param('index')
      userId = req.param('userId')

      return res.json (error: "bad card index encountered"), 500 unless index
      return res.json (error: "bad user encountered"), 500 unless userId

      User.findById userId, {internal: true}, (err, user) ->
        return res.json (error: err), 500 if err
        return res.json (error: "user not found"), 500 unless user
        # Get ccard billing address
        HuntinFoolClient.byUserId user._id, (err, huntinFoolClient) ->
          return res.json (error: err), 500 if err
          if huntinFoolClient['billing' + index + '_address']?.length
            # use billing info
            address = {
              address: huntinFoolClient["billing" + index + "_address"]
              address2: huntinFoolClient["billing" + index + "_address2"]
              city:     huntinFoolClient["billing" + index + "_city"]
              country:  if huntinFoolClient["billing" + index + "country"] then huntinFoolClient["billing" + index + "country"] else 'United States'
              state:    NavTools.stateFromAbbreviation(huntinFoolClient["billing" + index + "_state"])
              postal:   huntinFoolClient["billing" + index + "_zip"]
              phone:   huntinFoolClient["billing" + index + "_phone"]
              email:   huntinFoolClient["billing" + index + "_email"]
            }
          else
          # use mail address info
            address = {
              address: user.mail_address
              city:     user.mail_city
              country:  if user.mail_country?.length then user.mail_country else if user.physical_country?.length then user.physical_country else 'United States'
              state:    user.mail_state
              postal:   user.mail_postal
            }

          switch index
            when '1'
              {credit, exp} = Secure.decredit [user.field6, user.field7]
              # Get card from db if cardId
              type = creditcard.parse(credit).scheme
              ccName = Secure.decrypt user.field4

              card = _.extend {
                code: Secure.decrypt user.field5
                month: exp.substr 0, 2
                year: exp.substr 2, 4
                name: if ccName.length then ccName else user.name
                number: credit
                phone: user.phone_day
                type: type
              }, address

            when '2'
              {credit, exp} = Secure.decredit [user.field11, user.field12]
              # Get card from db if cardId
              type = creditcard.parse(credit).scheme
              ccName = Secure.decrypt user.field9

              card = _.extend {
                code: Secure.decrypt user.field10
                month: exp.substr 0, 2
                year: exp.substr 2, 4
                name: if ccName.length then ccName else user.name
                number: credit
                phone: user.phone_day
                type: type
              }, address

          card.number = ('' + card?.number).replace /[^\d]/g, ''
          return res.json {card: card}

    updateCard: (req, res) ->
      #return res.json {error: "Unauthorized"}, 401 unless req.user.isAdmin
      data = req.body

      return res.json (error: "bad card index encountered"), 500 unless data.cardIndex >= 0
      return res.json (error: "bad card number encountered"), 500 unless data.number >= 12
      return res.json (error: "missing card expiration month"), 500 unless data.month
      return res.json (error: "missing card expiration year"), 500 unless data.year

      card = {}

      number = data.number.replace /[^\d]/g, ''
      field4 = Secure.encrypt data.name
      field5 = Secure.encrypt data.code
      exp = ('00' + data.month).substr(-2) + '20' + data.year.substr(-2)
      [field6, field7] = Secure.credit number, exp
      field8 = number.substr -4

      if data.cardIndex-1 == 0
        card.field4 = field4
        card.field5 = field5
        card.field6 = field6
        card.field7 = field7
        card.field8 = field8
      else
        card.field9 = field4
        card.field10 = field5
        card.field11 = field6
        card.field12 = field7
        card.field13 = field8

      User.updateCards data.userId, card, (err) ->
        return res.json (error: err), 500 if err

        #Save billing address info to HF Client Table
        hfClientData = {
          userId: data.userId
        }
        hfClientData["billing#{data.cardIndex}_phone"] = data.phone
        hfClientData["billing#{data.cardIndex}_address"] = data.address
        hfClientData["billing#{data.cardIndex}_address2"] = data.address2
        hfClientData["billing#{data.cardIndex}_city"] = data.city
        hfClientData["billing#{data.cardIndex}_state"] = data.state
        hfClientData["billing#{data.cardIndex}_zip"] = data.postal
        hfClientData["billing#{data.cardIndex}_country"] = data.country
        HuntinFoolClient.upsert hfClientData, {query: {userId: data.userId}}, (err, hfClient) ->
          return res.json (error: err), 500 if err
          res.json {success: true}


    changeParent: (req, res) ->
      console.log 're;fq'
      return res.json({error: "Unauthorized"}, 401) unless req.user?.isAdmin and req.user?.userType is "super_admin"
      data = req.body

      requiredFields = {
        'newParentId': 'New Parent Id'
        'userId': "Valid User id"
      }
      missing = _.difference Object.keys(requiredFields), Object.keys(data)
      return res.json({error: "Missing required fields: " + missing.join(', ')}, 400) if missing.length

      User.byId data.userId, (err, user) ->
        return res.json {error: "System error when changing parent", err}, 400 if err
        return res.json {error: "Invalid User Id"}, 400 unless user

        User.byId data.newParentId, (err, parent) ->
          return res.json {error: "System error when changing parent", err}, 400 if err
          return res.json {error: "Invalid Parent Id"}, 400 unless parent

          userData = {}
          userData._id = user._id
          userData.parentId = parent._id
          userData.parent_clientId = parent.clientId
          console.log "User.upsert() userData", userData
          User.upsert userData, {upsert: false}, (err, userRsp) ->
            return res.json {error: "System error when changing parent", err}, 400 if err
            tReq = {
              params: {
                _id: userRsp._id
                tenantId: userRsp.tenantId
                parentId: userRsp.parentId
                clientId: userRsp.clientId
              }
            }
            api_rbo_rrads.user_update_rrads_partial tReq, (err, results) ->
              console.log "Error changing parent in RRADS: ", err if err
              return res.json {error: "System rrads error when changing parent", err}, 400 if err
              return res.json {status: "Parent re-assigned successfully."}

    changePassword: (req, res) ->
      data = req.body
      requiredFields = {
        'password': 'New Password'
        'newPassword': 'Confirm New Password'
        '_id': "Valid User id"
      }

      missing = _.difference Object.keys(requiredFields), Object.keys(data)
      missing = missing.map (item) ->
        return requiredFields[item]
      return res.json({error: "Missing required fields: " + missing.join(', ')}, 400) if missing.length

      User.byId data._id, (err, user) =>
        return res.json {error: "System error when changing password", err}, 400 if err
        return res.json {error: "Invalid User Id"}, 400 unless user

        return res.json({error: "Missing required fields: 'currentPassword': 'Current Password'"}, 400) if user.password and not data.currentPassword and not req.user.isAdmin

        #A password hasn't been set before.  Setting it the first time is ok
        if (not user.password and not data.currentPassword) or (req.user.isAdmin and not data.currentPassword)
          if data.password is "default"
            User.defaultPassword user, (err, defaultPassword) =>
              console.log err if err
              return res.json {error: "System error when setting default password", err}, 400 if err
              return res.json {error: "System error when setting default password", err}, 400 unless defaultPassword
              data.password = defaultPassword
              User.updatePassword user._id, @hashPassword(data.password), (err) ->
                return res.json {error: "System error when changing password", err}, 400 if err
                return res.json {status: 'success'}
          else
            User.updatePassword user._id, @hashPassword(data.password), (err) ->
              return res.json {error: "System error when changing password", err}, 400 if err
              return res.json {status: 'success'}
        else if false
          Custom.RB_checkPassword user.email, data.currentPassword, req.tenant._id, (err, authenticated, result) =>
            if err
              return res.status(500).json({error: err})
            if not authenticated
              #Try with a normal GMT hashed password.  Users could have been created in GMT or RB User import.
              hashedPassword = @hashPassword data.currentPassword
              return res.json({error: "Incorrect password"}, 400) if hashedPassword isnt user.password

            return res.json({error: "New Password and Confirm New Password must match"}, 400) if data.password isnt data.newPassword
            User.updatePassword user._id, @hashPassword(data.password), (err) ->
              return res.json {error: "System error when changing password", err}, 400 if err
              return res.json {status: 'success'}
        else
          hashedPassword = @hashPassword data.currentPassword
          return res.json({error: "Incorrect password"}, 400) if hashedPassword isnt user.password
          return res.json({error: "New Password and Confirm New Password must match"}, 400) if data.password isnt data.newPassword

          User.updatePassword user._id, @hashPassword(data.password), (err) ->
            return res.json {error: "System error when changing password", err}, 400 if err
            return res.json {status: 'success'}

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

    defaultUser: (req, res) ->

      # Create user
      user = new User {
        reminders: {
          email: false
          inApp: true
          text: false
          stateswpoints: true

          types: ['app-start', 'app-end']
          states: ['Colorado']
        }

        tenantId: req.tenant._id
        needsWelcomeEmail: true
      }

      parentId = req.param 'parentId'
      user.set 'parentId', parentId if parentId
      demo = req.param 'demo'
      user.set 'demo', demo if demo
      user.save (err) =>
        return res {error: 'Trouble saving user'}, 500 if err

        # Check for referal
        @checkReferById user._id, @_getIp(req), (err, response) =>
          # Log the error, but ignore it.  We don't really care about the error here
          logger.error 'User::defaultuser -> checkReferById error:', err if err

          user.set 'tenantId', response.newTenantAssignment if response?.newTenantAssignment
          user.set 'parent_clientId', response.parent_clientId if response?.parent_clientId

          # Update user with new token and tokenExpires fields
          token = new Token {
            token: crypto.randomBytes(64).toString('hex')
            expires: moment().add(2, 'months').toDate()
            userId: user._id
          }

          token.save (err, token) ->
            if err
              logger.info "Failed to update local user token:", err
              return res.json({error: err}, 500)

            return res.json({error: "Failed to update local user token"}, 500) unless token

            # user = user.toJSON()
            result = {
              user: user.toObject(),
              token: {
                token: token.get 'token'
                tokenExpires: token.get 'expires'
              }
            }

            res.json result

    hashPassword: (password) ->
      shasum = crypto.createHash('sha1')
      shasum.update(password)
      shasum.update(salt)
      shasum.digest('hex')

    login: (req, res) ->
      email = req.param('email')
      password = req.param('password')
      return res.json({error: "Bad Requestk"}, 400) unless email and password

      completeLogin  = (user) =>
        @checkReferById user._id, @_getIp(req), (err, response) ->
          logger.info "checkReferById error:", err if err

        @processClientParentId user, (err, rsp) ->
          logger.error "processClientParentId error:", err if err

        # Update user with new token and tokenExpires fields
        token = new Token {
          token: crypto.randomBytes(64).toString('hex')
          expires: moment().add(2, 'months').toDate()
          userId: user._id
        }

        token.save (err, token) ->
          if err
            logger.info "Failed to update local user token:", err
            return res.json({error: err}, 500)

          return res.json({error: "Failed to update local user token"}, 500) unless token

          result = {
            user: _.omit(user, '__v', 'password', 'postal2', 'timestamp', 'type')
            token: {
              token: token.get 'token'
              tokenExpires: token.get 'expires'
            }
          }

          logger.info "return user:", result

          # We need to pick the part of the user object we want to return before returning back to the user
          # because we don't want to send somethings plain text like their ssn.  For now we skip this because
          # it makes it easier to move quickly and add/remove things from the user object easily.
          # user = _.pick user, 'createdAt', 'email', 'name', 'display_name', 'token', 'tokenExpires', 'type', '_id', 'ssn', 'dob', 'postal'
          res.json(result, 200)


      #custom code for RollingBones login
      if false
        Custom.RB_checkPassword email, password, req.tenant._id, (err, authenticated, user) =>
          if err
            logger.info "find local user error:", err
            return res.status(500).json({error: err})

          if authenticated and user
            completeLogin user
          else
            #Try with a normal GMT hashed password.  Users could have been created in GMT or RB User import.
            password = @hashPassword password
            User.findByEmailOrUsernamePassword email, email, password, req.tenant._id, {internal: false}, (err, user) =>
              if err
                logger.info "find local user error:", err
                return res.status(500).json({error: err})
              console.log 'rehq'
              return res.json({error: "Unauthorized"}, 401) if not user or user.password isnt password
              completeLogin user
      else
        password = @hashPassword password
        console.log 'req.tenant._id',req.tenant._id
        User.findByEmailOrUsernamePassword email, email, password, req.tenant._id, {internal: false}, (err, user) =>
          if err
            logger.info "find local user error:", err
            return res.status(500).json({error: err})
          console.log 'password',password
          console.log 'email',email
          console.log 'user',user
          return res.json({error: "Unauthorized"}, 401) if not user or user.password isnt password
          completeLogin user

    getStamp: (req, res) ->
      originalClientId = req.param('originalClientId')
      clientId = req.param('clientId')

      async.waterfall [

        (next) ->
          return next null, null unless originalClientId
          User.byClientId originalClientId, {}, (err, originalUser) ->
            return next err if err
            return next null, null unless originalUser
            Token.findByUserId originalUser._id, (err, originalUser_token) ->
              return next err, originalUser_token

        (originalUser_token, next) ->
          if clientId
            User.byClientId clientId, {}, (err, currentUser) ->
              return next err if err
              return next null, null unless currentUser
              Token.findByUserId currentUser._id, (err, currentUser_token) ->
                return next err, originalUser_token, currentUser_token
          else
            Token.findByUserId req.user._id, (err, currentUser_token) ->
              return next err, originalUser_token, currentUser_token

      ], (err, originalUser_token, currentUser_token) ->
        params = {
          clientId: clientId,
          originalClientId: originalClientId
        }
        params.originalClientId_token = originalUser_token.token if originalUser_token?.token
        params.clientId_token = currentUser_token.token if currentUser_token?.token

        eStamp = Secure.encrypt_rads_stamp params, (err, eStamp) ->
          return res.json {error: err}, 401 if err
          return res.json {error: "Failed to create eStamp."}, 401 unless eStamp
          return res.json({eStamp: eStamp}, 200)

    loginPassthrough: (req, res) ->
      eStamp = req.param('stamp')
      return res.json({error: "Bad Requestl"}, 400) unless eStamp

      stamp = Secure.validate_rads_stamp eStamp
      return res.json {error: "invalid stamp, unauthorized."}, 401 unless stamp?.isValid
      return res.json {error: "invalid stamp, missing clientId."}, 401 unless stamp?.params?.clientId
      return res.json {error: "invalid stamp, missing destination."}, 401 unless stamp?.params?.destination
      return res.json {error: "invalid stamp, missing purchase_id."}, 401 if stamp?.params?.destination is "receipt" and !stamp?.params?.purchase_id

      clientId = stamp.params.clientId
      destination = stamp.params.destination #receipt, repdashboard, admindashboard
      purchase_id = stamp.params.purchase_id if stamp.params.purchase_id

      completeLogin  = (user) =>
        @checkReferById user._id, @_getIp(req), (err, response) ->
          logger.info "checkReferById error:", err if err

        @processClientParentId user, (err, rsp) ->
          logger.error "processClientParentId error:", err if err

        # Update user with new token and tokenExpires fields
        token = new Token {
          token: crypto.randomBytes(64).toString('hex')
          expires: moment().add(2, 'months').toDate()
          userId: user._id
        }

        token.save (err, token) ->
          if err
            logger.info "Failed to update local user token:", err
            return res.json({error: err}, 500)

          return res.json({error: "Failed to update local user token"}, 500) unless token

          result = {
            user: _.omit(user, '__v', 'password', 'postal2', 'timestamp', 'type')
            token: {
              token: token.get 'token'
              tokenExpires: token.get 'expires'
            }
            params: stamp.params
          }

          logger.info "return user:", result
          res.json(result, 200)


      User.byClientId clientId, {internal: false}, (err, user) =>
        if err
          console.log "find local user error:", err
          return res.json {error: err}, 500 if err
        return res.json {error: "User not found for clientId #{clientId}"}, 501 unless user
        completeLogin user



    read: (req, res) ->
      topToken = req.params.topToken if req.params?.topToken
      topToken = req.query.topToken if req.query?.topToken
      returnUser = (userId, limited) ->
        User.findById userId, (err, result) ->
          return res.json({error: err}, 500) if err
          return res.json null unless result

          if limited
            keys = ["_id","parentId","clientId","email","first_name","last_name","name","phone_cell",
              "mail_address","mail_city","mail_postal","mail_state",
              "shipping_address","shipping_city","shipping_country","shipping_postal","shipping_state"]
            result = _.pick(result, keys)
          res.json result

      if req.user.isAdmin
        userId = req.params.id
        returnUser userId
      else if req.user._id.toString() is req.params?.id
        userId = req.user._id
        returnUser userId
      else if (req.user.isOutfitter or req.user.isVendor) and !req.user.isAdmin
        userId = req.params.id
        returnUser userId, true
      else if topToken
        Token.findOne({token: topToken}).lean().exec (err, token) ->
          return res.json({error: "User not found " + err}, 500) if err
          return res.json({error: "User not found"}, 404) unless token
          topUserId = token.userId
          rCount = 0

          checkValidChain = (tUserId, done) ->
            rCount++
            if tUserId.toString() is topUserId.toString()
              return done null, req.params.id
            else
              User.findById tUserId, (err, user) ->
                return done(err) if err
                if user.parentId
                  checkValidChain user.parentId, done
                else
                  return done()

          done = (err, userId) ->
            return res.json({error: "User not found " + err}, 500) if err
            return res.json({error: "User not found"}, 404) unless userId
            returnUser userId

          User.findById topUserId, (err, topUser) ->
            done err if err
            if topUser.isAdmin
              userId = req.params.id
              returnUser userId
            else
              checkValidChain req.params.id, done

      else
        return res.json({error: "User not found"}, 404)

    sanitizeFields: (data) ->
      data.drivers_license = data.drivers_license.replace(/[^\w\d]+/g, '') if data.drivers_license
      data.phone_cell = (''+ data.phone_cell).replace(/[^0-9]+/g, '') if data.phone_cell
      data.phone_day = (''+ data.phone_day).replace(/[^0-9]+/g, '') if data.phone_day
      data.phone_home = (''+ data.phone_home).replace(/[^0-9]+/g, '') if data.phone_home
      data.ssn = (''+ data.ssn).replace(/[^0-9]+/g, '') if data.ssn
      data.dob = moment(data.dob, 'MM/DD/YYYY').format('YYYY-MM-DD') if data.dob?.length and ~data.dob.indexOf('/')

      if data.needEncryptAZPassword
        data.azPassword = Secure.encrypt data.azPassword
        delete data.needEncryptAZPassword
      if data.needEncryptNMPassword
        data.nmPassword = Secure.encrypt data.nmPassword
        delete data.needEncryptNMPassword
      if data.needEncryptSDPassword
        data.sdPassword = Secure.encrypt data.sdPassword
        delete data.needEncryptSDPassword
      if data.needEncryptIDPassword
        data.idPassword = Secure.encrypt data.idPassword
        delete data.needEncryptIDPassword
      if data.needEncryptWAPassword
        data.waPassword = Secure.encrypt data.waPassword
        delete data.needEncryptWAPassword
      if data.needEncryptCOPassword
        data.coPassword = Secure.encrypt data.coPassword
        delete data.needEncryptCOPassword
      if data.needEncryptMTPassword
        data.mtPassword = Secure.encrypt data.mtPassword
        delete data.needEncryptCOPassword
      if data.needEncryptNVPassword
        data.nvPassword = Secure.encrypt data.nvPassword
        delete data.needEncryptNVPassword

      #For security reasons, don't every allow these two fields to be updated from User updates
      if data.userType isnt "tenant_manager"
        delete data.isAdmin
        delete data.userType


      return data

    # To trigger this action locally, visit: `http://localhost:port/users/register`
    register: (req, res) ->
      #TODO: Update RRADS Here after updating NRADS
      data = req.body
      console.log 'data',data
      logger.info "register data:", data

      requiredFields = {
        #'first_name': 'First Name'
        #'last_name': 'Last Name',
        'email': 'Email'
      }

      missing = _.difference Object.keys(requiredFields), Object.keys(data)
      missing = missing.map (item) ->
        return requiredFields[item]

      return res.json({error: "Missing required fields: " + missing.join(', ')}, 400) if missing.length

      delete data.confirmEmail if data.confirmEmail
      delete data.confirmPassword if data.confirmPassword

      data.type = 'local'
      data.password = @hashPassword data.password if data.password
      data.tenantId = req.tenant._id
      #Now sending welcome emails immediately, so since this is the register method, flag them now.
      sendWelcomeEmailFlag = false
      sendWelcomeEmailFlag = true if data.needsWelcomeEmail
      data.needsWelcomeEmail = false
      data.welcomeEmailSent = new Date() if sendWelcomeEmailFlag

      #Default parent assignment only if RBO tenant, ignore default parent for white label tenants
      if data.tenantId.toString() is TENANT_IDS.RollingBones
        if !data.parentId and !data.parent_clientId
          data.parentId = "570419ee2ef94ac9688392b0" #Hard coded to Brian and Lynley Mehmen for now.
      else if data.tenantId.toString() is TENANT_IDS.RollingBonesTest
        if !data.parentId and !data.parent_clientId
          data.parentId = "5bd7607b02c467db3f70eda2" #Hard coded to top Admin user


      search = new RegExp("^#{data.email}$", 'i')
      console.log 'asdfasdf';
      User.findOne({type: "local", email: search, tenantId: data.tenantId}).lean().exec (err, result) =>
        if err
          logger.info "find local user error:", err
          res.json({error: err}, 500)

        #Todo: NOT For now, let new users with the same email be created to allow family plan.  User login process will check for the first of any emailaddress/password match.
        return res.json({error: "email address already in use"}, 409) if result

        data = @sanitizeFields data

        #Assign the new user a Client Id
        Tenant.getNextClientId req.tenant._id, (err, newClientId) =>
          return next err if err
          return next {error: "tenant not found for id: #{req.tenant._id}"} unless newClientId
          data.clientId = "#{req.tenant.clientPrefix}#{newClientId}"

          logger.info "User.upsert data:", data
          User.upsert data, {internal: false, upsert: true}, (err, user) =>
            if err
              logger.info "Failed to create new user:", err
              return res.json({error: err}, 500)

            return res.json({error: "Failed to create new user"}, 500) unless user

            #@checkReferById user._id, @_getIp(req), (err, response) ->
            #  logger.info "checkReferById error:", err if err

            @processClientParentId user, (err, rsp) ->
              logger.error "processClientParentId error:", err if err

            if sendWelcomeEmailFlag
              @sendWelcomeEmail req.tenant, user, null, (err) ->
                console.log "Welcome email failed to send with error: ", err if err
                console.log "Welcome email sent." unless err

            # Update user with new token and tokenExpires fields
            token = new Token {
              token: crypto.randomBytes(64).toString('hex')
              expires: moment().add(2, 'months').toDate()
              userId: user._id
            }

            token.save (err, token) ->
              if err
                logger.info "Failed to update local user token:", err
                return res.json({error: err}, 500)

              return res.json({error: "Failed to update local user token"}, 500) unless token

              # user = user.toJSON()
              result = {
                user,
                token: {
                  token: token.get 'token'
                  tokenExpires: token.get 'expires'
                }
              }

              res.json result

    registerDevice: (req, res) ->

      user = req.user
      user.devices ?= []
      console.log "req.body:", req.body
      deviceFound = false
      for device, index in user.devices
        if device.deviceId is req.body.deviceId
          user.devices[index] = req.body
          deviceFound = true
          break

      user.devices.push req.body unless deviceFound

      User.upsert user, (err, result) ->
        return res.status(500).json {error: err} if err
        res.status(200).json {status: 'OK'}

    sendGCM: (item, data, cb) ->
      message = new gcm.Message(
        collapseKey: "demo"
        delayWhileIdle: true
        timeToLive: (60 * 60 * 24 * 7) # Try to deliver for 7 days
        data:{notification: data.notification, unread: data.unread}
      )

      if data.user.tenantId?.toString() == HuntinFoolTenantId || data.user.tenantId == HuntinFoolTenantId
        sender = new gcm.Sender HF_GCM_API_KEY
      else
        sender = new gcm.Sender GCM_API_KEY

      sender.send message, [item.token], 4, (err, result) ->
        console.log result
        cb err, result
        return

    sendAPN: (item, data, cb) ->
      options = {
        cert: APN_CERT
        key: APN_KEY
      }

      if data.user.tenantId?.toString() == HuntinFoolTenantId || data.user.tenantId == HuntinFoolTenantId
        options = {
          cert: HF_APN_CERT
          key: HF_APN_KEY
        }

      console.log("sendAPN options", options);

      apnConnection = new apn.Connection(options)
      myDevice = new apn.Device(item.token)
      note = new apn.Notification()
      note.expiry = Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7) # Expires 7 days from now.
      note.badge = data.unread
      note.sound = "ping.aiff"
      note.alert = data.notification.message
      note.payload =
        n_userId: data.notification.userId
        n_message: data.notification.message
        n_created: data.notification.created
        unread: data.unread

      #console.log('myDevice:', myDevice);
      #console.log 'send apn:', note
      apnConnection.on 'transmissionError', (errCode, notification, device) ->
        logger.error "User::sendAPN -> transmissionError: " + errCode + " for device ", device, notification

      apnConnection.on "error", (err) ->
        logger.error 'User::sendAPN -> error:', err

      apnConnection.pushNotification note, myDevice
      cb()

    sendMessage: (req, res) ->
      return res.status(401).json {error: 'Unauthorized'} if req.user.isAdmin = false and req.body.userId isnt req.user._id

      send = (data) =>
        (device, done) =>
          if device.platform is 'android'
            @sendGCM device, data, done
          else
            @sendAPN device, data, done

      async.waterfall [
        (done) ->
          User.byId req.body.userId, done

        (user, done) ->
          data =
            userId: user._id
            message: req.body.message

          Notification.upsert data, (err, notification) ->
            return done err if err
            done null, {user, notification}

        (data, done) ->

          Notification.unreadCount data.user._id, (err, unread) ->
            return done err if err
            data.unread = unread
            done null, data
      ], (err, data) ->

        async.map data.user.devices, send(data), (err) ->
          return res.status(500).json {error: err} if err
          res.status(200).json {status: 'OK'}

    setAdmin: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless req.user.isAdmin

      User.findById req.param('userId'), (err, user) ->
        return res.json {error: err}, 500 if err

        user.set 'isAdmin', req.param('isAdmin')
        user.save ->
          res.json {success: true}

    checkExists: (req, res) ->
      switch req.body.type
        when "username"
          return res.json({error: "username is required"}, 500) unless req?.body?.username
          return res.json({error: "tenantId is required"}, 500) unless req?.body?.tenantId
          User.findOne({username: req.body.username, tenantId: req.body.tenantId}).lean().exec (err, result) =>
            if err
              logger.info "checkExists find local user error:", err
              res.json({error: err}, 500)
            return res.json({exists: true}) if result
            return res.json({exists: false})
        when "memberId"
          return res.json({error: "memberId is required"}, 500) unless req?.body?.memberId
          return res.json({error: "tenantId is required"}, 500) unless req?.body?.tenantId
          User.findOne({memberId: req.body.memberId, tenantId: req.body.tenantId}).lean().exec (err, result) =>
            if err
              logger.info "checkExists find local user error:", err
              res.json({error: err}, 500)
            return res.json({exists: true}) if result
            return res.json({exists: false})
        else
          return res.json({error: "type is required"}, 500)

    testUsers: (req, res) ->
      return res.json({error: "tenantId is required"}, 500) unless req?.body?.tenantId
      User.getTestUsers req.body.tenantId, (err, users) ->
        return res.status(500).json {error: err} if err
        res.json users


    update: (req, res) ->
      #TODO: Update RRADS Here after updating NRADS
      console.log "Users::update: req.user._id and req.user.isAdmin:", req.user._id, req.user.isAdmin
      console.log "Users::update: req.body._id", req?.body?._id
      return res.json {error: 'User id required'}, 400 unless req?.body?._id
      #Since the line above requires a req.body._id to continue, always use it for the update.
      #req.body._id = if req.user.isAdmin then req.body._id else req.user._id
      data = @sanitizeFields req.body
      if data.userType is "tenant_manager" and !data.group_outfitterIds?.length
        data.group_outfitterIds = [data._id]

      if data._id
        User.byId data._id, {}, (err, prev_user) ->
          return res.json {error: err}, 500 if err
          data.memberExpires = undefined if prev_user.memberExpires and !data.memberExpires
          data.repExpires = undefined if prev_user.repExpires and !data.repExpires
          data.rep_next_payment = undefined if prev_user.rep_next_payment and !data.rep_next_payment
          console.log 'ffff';
          console.log 'user data',data;
          User.upsert data, {internal: false, upsert: false}, (err, tUser) ->
            console.log 'error'.err
            return res.json {error: err}, 500 if err
            res.json tUser
      else
        #console.log "Users::update: User.upsert:", data
        User.upsert data, {internal: false, upsert: false}, (err, user) ->
          return res.json {error: err}, 500 if err
          res.json user

    updateClient: (req, res) ->
      console.log "Users::updateClient:", req?.body
      return res.json {error: 'User id required'}, 400 unless req?.body?.userId
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Year is required'}, 400 unless req?.body?.year

      userClient = req.body

      async.waterfall [
        (next) ->
          Tenant.findById req.tenant._id, (err, tenant) ->
            next err, tenant

        # Update User with new ClientId
        (tenant, next) ->
          #return next null, userClient unless userClient.powerOfAttorney
          return next null, userClient if userClient.client_id
          return next null, userClient if req.tenant._id == HuntinFoolTenantId or req.tenant._id.toString() == HuntinFoolTenantId #for now, don't assign HF clientIds from our system
          return next "Missing clientPrefix from Tenant." unless tenant?.clientPrefix

          userData = {}
          userData._id = userClient.userId
          Tenant.getNextClientId tenant._id, (err, newClientId) ->
            next err if err
            next {error: "new ClientId not found for tenant id: #{tenant._id}"} unless newClientId
            userData.clientId = tenant.clientPrefix + newClientId
            console.log "User.upsert() userData", userData
            User.upsert userData, {upsert: false}, (err, userRsp) ->
              return next err if err
              userClient.client_id = userData.clientId if userData.clientId
              return next null, userClient


        # Insert into HuntinFoolUser
        (userClient, next) ->
          return next null, userClient unless userClient.powerOfAttorney
          clientData = {
            client_id: userClient.client_id
            needEncryptCC: false
            nmfst: userClient.nmfst
            nmlt: userClient.nmlt
            userId: userClient.userId
            tenantId: userClient.tenantId
          }
          HuntinFoolClient.upsert clientData, (err, client) ->
            return next err, userClient

        # Insert into HuntinFoolState
        (userClient, next) ->
          applicationData = {
            userId: userClient.userId
            tenantId: userClient.tenantId
            year: userClient.year
          }
          if userClient.allSpecies
            applicationData.ak_species = "Brown Bear\nBlack Bear\nBison\nCaribou\nGoat\nMoose\nMuskox\nSheep\nElk\nEmperor Goose"
            applicationData.az_species = "Desert Sheep\nMule Deer\nBuffalo\nElk\nAntelope\n"
            applicationData.ca_species = "Desert Sheep\nMule Deer \nTule Elk\nAntelope\n"
            applicationData.co_species = "Elk\nRM Sheep\nDesert Sheep\nDeer\nMoose\nAntelope\nGoat\n"
            applicationData.fl_species = "Fish"
            applicationData.ia_species = "Whitetail Deer"
            applicationData.id_species_1 = "Sheep\nMoose\nGoat"
            applicationData.id_species_3 = "Mule Deer\nElk\nAntelope"
            applicationData.ks_mule_deer_stamp = "True"
            applicationData.ks_species = "Whitetail Deer"
            applicationData.ky_species = "Elk"
            applicationData.mt_species = "Sheep\nMoose\nGoat\nDeer\nElk\nAntelope\n"
            applicationData.nm_species = "Desert Sheep\nBarbary Sheep\nAntelope\nDeer\nOryx\nElk\nIbex"
            applicationData.nd_species = "Sheep\nPronghorn\nDeer\nElk\nMoose"
            applicationData.nv_species = "CA Sheep\nDesert Sheep\nMule Deer\nAntelope\nElk Silver State Tag\nAnte Silver State Tag\nDeer Silver State Tag\nDesert Silver State Tag\n-Elk\nGoat\n"
            applicationData.ore_species = "Antelope\nElk\nColumbian Whitetail\nCalifornia Sheep\nGoat\nDeer\n"
            applicationData.pa_species = "Elk Lottery\nElk Quota\n"
            applicationData.sd_species = "Deer\nElk\nAntelope\n"
            applicationData.tx_species = "Sheep\n"
            applicationData.ut_species_1 = "Deer\nElk\nAntelope\nGeneral Deer\nYouth Elk\n"
            applicationData.ut_species_2 = "Moose\nRocky Mtn Sheep\nDesert Sheep\nGoat\nBuffalo\n"
            applicationData.wa_species = "Sheep\nMoose\nGoat\nCR Goat\n"
            applicationData.vt_species = "Moose\n"
            applicationData.wy_species = "Antelope\nSheep\nMoose\nGoat\nDeer\nElk\nBison\n"

          applicationData.ak_check = "False"
          applicationData.az_check = "False"
          applicationData.ca_check = "False"
          applicationData.co_check = "False"
          applicationData.fl_check = "False"
          applicationData.ia_check = "False"
          applicationData.id_check = "False"
          applicationData.ks_check = "False"
          applicationData.ky_check = "False"
          applicationData.mt_check = "False"
          applicationData.nd_check = "False"
          applicationData.nm_check = "False"
          applicationData.nv_check = "False"
          applicationData.ore_check = "False"
          applicationData.pa_check = "False"
          applicationData.sd_check = "False"
          applicationData.tx_check = "False"
          applicationData.ut_check = "False"
          applicationData.vt_check = "False"
          applicationData.wa_check = "False"
          applicationData.wy_check = "False"

          applicationData.ak_check = "True" if userClient.ak_check is true or userClient.ak_check is "True"
          applicationData.az_check = "True" if userClient.az_check is true or userClient.az_check is "True"
          applicationData.ca_check = "True" if userClient.ca_check is true or userClient.ca_check is "True"
          applicationData.co_check = "True" if userClient.co_check is true or userClient.co_check is "True"
          applicationData.fl_check = "True" if userClient.fl_check is true or userClient.fl_check is "True"
          applicationData.ia_check = "True" if userClient.ia_check is true or userClient.ia_check is "True"
          applicationData.id_check = "True" if userClient.id_check is true or userClient.id_check is "True"
          applicationData.ks_check = "True" if userClient.ks_check is true or userClient.ks_check is "True"
          applicationData.ky_check = "True" if userClient.ky_check is true or userClient.ky_check is "True"
          applicationData.mt_check = "True" if userClient.mt_check is true or userClient.mt_check is "True"
          applicationData.nd_check = "True" if userClient.nd_check is true or userClient.nd_check is "True"
          applicationData.nm_check = "True" if userClient.nm_check is true or userClient.nm_check is "True"
          applicationData.nv_check = "True" if userClient.nv_check is true or userClient.nv_check is "True"
          applicationData.ore_check = "True" if userClient.ore_check is true or userClient.ore_check is "True"
          applicationData.pa_check = "True" if userClient.pa_check is true or userClient.pa_check is "True"
          applicationData.sd_check = "True" if userClient.sd_check is true or userClient.sd_check is "True"
          applicationData.tx_check = "True" if userClient.tx_check is true or userClient.tx_check is "True"
          applicationData.ut_check = "True" if userClient.ut_check is true or userClient.ut_check is "True"
          applicationData.vt_check = "True" if userClient.vt_check is true or userClient.vt_check is "True"
          applicationData.wa_check = "True" if userClient.wa_check is true or userClient.wa_check is "True"
          applicationData.wy_check = "True" if userClient.wy_check is true or userClient.wy_check is "True"

          applicationData.client_id = userClient.client_id if userClient.client_id

          for key, value of userClient
            applicationData[key] = value if key?.toString().toLowerCase().indexOf("notes") != -1

          HuntinFoolState.upsert applicationData, (err, application) ->
            if err
              logger.error "Failed to create client state options for user #{userClient.userId}.", err
              next err
            next null, application

      ], (err, application) ->
        logger.error "users.updateClient() failed with error: ", err if err
        return res.json {error: err}, 500 if err
        res.json application



    updateReminders: (req, res) ->
      return res.json {error: 'Bad request'}, 400 unless req?.body
      User.updateReminders req.user._id, req.body, (err) ->
        return res.json {error: err}, 500 if err
        return res.json {status: 'success'}

    verify: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless req.user?._id
      res.json {message: "user verified"}

    checkRefer: (req, res) ->
      @checkReferById req.body._id, @_getIp(req), (err, response) ->
        return res.json err, 500 if err
        return res.json response


    _getIp: (req) ->
      xForward = req.headers['x-forwarded-for'].split(",")[0] if req.headers['x-forwarded-for']
      if xForward or req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket.remoteAddress
        return xForward or req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket.remoteAddress
      return null

    checkReferById: (userId, ip, cb) =>
      return cb {error: 'User id required'} unless userId
      ip = ip.replace("::ffff:","")

      #Had to do this because for some reason @ this is out of scope despite the => calls and @processClientParentId is not a function.
      processClientParentId = (user, cb) ->
        return cb null, user if user.parentId
        return cb null, user unless user.parent_clientId or user.parent_memberId
        user.parent_clientId = "RB17" if user.parent_clientId == "R17"  #unfortunate hack to fix rolling bones Brandon URL he has sent all over social media
        User.byClientIdOrMemberId user.parent_clientId, user.parent_memberId, user.tenantId, (err, parent) ->
          return cb err if err
          return cb null, user unless parent
          userData = {
            _id: user._id,
            parentId: parent._id
          }
          User.upsert userData, {upsert: false}, (err, user) ->
            logger.info "assigned user #{user._id} to parent #{parent._id} based on the user's parent clientId '#{user.parent_clientId}' and/or member parent id '#{user.parent_memberId}'"
            return cb {error: err} if err
            return cb null, user

      # get the user and see if it is already associated with a referral.  If not, check the IP for a matching Refer IP and update it
      User.findById userId, (err, user) =>
        if err
          logger.info "checkRefer find user error:", err
          return cb({error: err})
        return cb({message: userId+" user not found"}) unless user
        return cb({message: user.referral.referrer+": referral already exists for the user"}) if user.referral and user.referral.ip
        return cb({message: "This is a GMT Admin user, skipping referral check/assignment"}) unless user.tenantId

        assignReferralToUser = (user, refer, cb) =>
          # we have a matching IP refer, update the user referral and tenant
          userData = []
          response = {}
          referPrefix = "none"
          referParentClientId = null
          referCampaign = ""
          referArray = refer.referrer.split("_")
          for item, i in referArray
            referPrefix = item if i == 0
            referParentClientId = item if i == 1
            referCampaign = item if i == 2
            referCampaign = "_#{item}" if i > 2

          Tenant.findByReferralPrefix referPrefix, (err, tenant) =>
            if err
              logger.info "checkRefer find tenant prefix error:", err
              return cb({error: err})
            if tenant
              if user.tenantId == GotMyTagTenantId or user.tenantId.toString() == GotMyTagTenantId or user.tenantId == GotMyTagDevTenantId or user.tenantId.toString() == GotMyTagDevTenantId
                if user.tenantId != tenant._id
                  logger.info "Re-assigning user tenant based on referral ip check. Referrer: #{}, Previous user.tenantId: #{user.tenantId}, New user.tenantId: #{tenant._id}"
                  userData.tenantId = tenant._id
                  response.newTenantAssignment = userData.tenantId
            userData._id = user._id
            userData.parent_clientId = referParentClientId if referParentClientId and !user.parent_clientId
            response.parent_clientId = referParentClientId if referParentClientId and !user.parent_clientId
            userData.referral = {}
            userData.referral.referId = refer._id
            userData.referral.ip = refer.ip
            userData.referral.referrer = refer.referrer
            userData.referral.refer_parent_clientId = referParentClientId if referParentClientId
            userData.referral.refer_campaign = referCampaign if referCampaign
            userData.referral.modified = moment()
            User.upsert userData, {upsert: false}, (err, user) =>
              return cb {error: err} if err
              processClientParentId user, (err, user) =>
                return cb {error: err} if err
                response.message = refer.referrer+": refer udpated for ip "+ip
                return cb null, response

        # get the current user's IP
        if ip
          # see if there is a matching refer IP
          Refer.byIP ip, (err, refer) =>
            if err
              logger.info "checkRefer find refer error:", err
              return cb({error: err})
            if refer
              assignReferralToUser user, refer, cb
            else
              #handle special case ipv6 socket using ipv4 communication for backwards compatibility before we started stipping the "::ffff:"
              ipv6 = "::ffff:" + ip
              #try again
              Refer.byIP ipv6, (err, refer) =>
                if err
                  logger.info "checkRefer find refer error:", err
                  return cb({error: err})
                if refer
                  assignReferralToUser user, refer, cb
                else
                  return cb {message: "no refer match for ip "+ip+", or ip "+ipv6}
        else
          cb {message: "no ip to check for refer"}

    processClientParentId: (user, cb) ->
      return cb null, user if user.parentId
      return cb null, user unless user.parent_clientId or user.parent_memberId
      User.byClientIdOrMemberId user.parent_clientId, user.parent_memberId, user.tenantId, (err, parent) ->
        return cb err if err
        return cb null, user unless parent
        userData = {
          _id: user._id,
          parentId: parent._id
        }
        User.upsert userData, {upsert: false}, (err, user) ->
          logger.info "assigned user #{user._id} to parent #{parent._id} based on the user's parent clientId '#{user.parent_clientId}' and/or member parent id '#{user.parent_memberId}'"
          return cb {error: err} if err
          return cb null, user

    getParentAndRep: (req, res) ->
      res.json {error: "userId is required."}, 500 unless req.param('userId')
      userId = req.param('userId')

      User.byId userId, (err, user) ->
        return res.json {error: err}, 500 if err
        return res.json {} unless user

        User.byId user.parentId, (err, parent) ->
          return res.json {error: err}, 500 if err
          return res.json {
            parent: _.pick(parent, 'name', 'clientId')
            rep: _.pick(parent, 'name', 'clientId')
          }


    getUserByClientId_public: (req, res) ->
      res.json {error: "clientId is required."}, 500 unless req.param('clientId')
      clientId = req.param('clientId')
      User.byClientId clientId, {}, (err, user) ->
        return res.json {error: err}, 500 if err
        return res.json {} unless user
        return res.json {error: "Requesting TenantId and tenantId of the Client do not match."}, 500 unless req.tenant?._id?.toString() is user.tenantId?.toString()
        #This is for showing minimal info on a public page so only return the name and ids.
        client = _.pick(user, '_id', 'name', 'clientId', 'tenantId', 'email')
        return res.json client

    getEmails: (req, res) ->
      res.json {error: "clientIds is required."}, 500 unless req.param('clientIds')
      clientIds = req.param('clientIds')
      clientIds = clientIds.split(",")
      tClientIds = []
      for clientId in clientIds
        tClientIds.push clientId.trim()
      clientIds = tClientIds

      User.byClientIds clientIds, {}, (err, users) ->
        return res.json {error: err}, 500 if err
        return res.json {} unless users

        emails = []
        for user in users
          emails.push {email: user.email} if user.email

        return res.json emails

    sendWelcomeEmails: (req, res) ->
      res.json {error: "userIds is required."}, 500 unless req.body?.userIds
      res.json {error: "tenant is required."}, 500 unless req.tenant?
      res.json {error: "tenantId is required."}, 500 unless req.user?.tenantId?
      userIds = req.body.userIds

      User.byIdsTenant userIds, req.user.tenantId, {}, (err, users) =>
        return res.json {error: err}, 500 if err
        return res.json {} unless users

        processUser = (user, done) =>
          user.repDisabled = true
          @sendWelcomeEmail req.tenant, user, "new", (err, result) ->
            return done err, user

        async.mapSeries users, processUser, (err, results) ->
          console.log err if err
          return res.json({error: "Error occurred sending welcome emails", errorMsg: ""}, 500) if err
          return res.json results

    userImport: (req, res) ->
      #return res.json({error: "Unauthorized"}, 401) unless req.user?.isAdmin and req.user?.userType is "super_admin"
      return res.json "Unauthorized User", 401 unless req.user?.isAdmin and (req.user?.userType is "tenant_admin" or req.user?.userType is "super_admin")
      tenantId = req.tenant._id
      users = req.body?.users
      return res.json({error: "Missing required fields users"}, 400) unless users?.length

      importUserCount = 0
      saveUser = (tUser, done) =>
        importUserCount++
        #return done null, null unless importUserCount < 2
        requiredFields = {
          #'first_name': 'First Name'
          #'last_name': 'Last Name',
          'email': 'email'
        }
        missing = _.difference Object.keys(requiredFields), Object.keys(tUser)
        missing = missing.map (item) ->
          return requiredFields[item]
        return done {error: "Missing required fields: " + missing.join(', ')} if missing.length

        tUser.type = 'local'
        tUser.tenantId = req.tenant._id
        tUser.needsWelcomeEmail = false unless tUser.needsWelcomeEmail?
        tUser.email = tUser.email.toLowerCase() if tUser.email

        #Check if existing by userId and clientId.  Note: It Shouldn't!
        userId = tUser._id if tUser._id
        userId = tUser.id if tUser.id
        userId = tUser.userId if tUser.userId

        async.waterfall [
          (next) ->
            #Check if user already exists (by userId and tenant)
            return next null unless userId
            User.findOne({_id: userId, tenantId: tenantId}).lean().exec (err, user) ->
              return next "Create user account failed.  A user already exists for user id: #{userId}" if user
              return next err

          (next) ->
            #Check if user already exists (by clientId and tenant)
            return next null unless tUser.clientId
            User.findOne({type: "local", clientId: tUser.clientId, tenantId: tenantId}).lean().exec (err, user) ->
              return next "Create user account failed.  A user already exists for clientId: #{tUser.clientId}" if user
              return next err

          (next) ->
            #Check if email already belongs to a different user
            return next null unless tUser.email
            User.findOne({email: tUser.email, tenantId: tenantId}).lean().exec (err, user) ->
              return next "Create user account failed.  A user already exists for email: #{tUser.email}" if user
              return next err

          (next) ->
            #Check if username already belongs to a different user
            return next null unless tUser.username
            User.findOne({username: tUser.username, tenantId: tenantId}).lean().exec (err, user) ->
              return next "Create user account failed.  A user already exists for username: #{tUser.username}" if user
              return next err

          (next) =>
            #Check and assign parent user
            return next null unless tUser.parent_clientId
            User.byClientId tUser.parent_clientId, {}, (err, parent) =>
              return next err if err
              if parent
                tUser.parentId = parent._id if parent
                return next null
              else
                console.log "Could not find parent for parent client id: ", tUser.parent_clientId
                tUser.referredBy = tUser.parent_clientId unless tUser.referredBy
                return next null

          #Assign the new user a Client Id
          (next) ->
            return next null if tUser.clientId
            Tenant.findById tenantId, (err, tenant) ->
              return next err if err
              return next "Unable to retrieve tenant for tenantId #{tenantId}" unless tenant

              #FOR TESTING PURPOSES, ALLOW SKIPPING GENERATING A NEW CLIENT ID
              HARD_CLIENT_ID = false
              if HARD_CLIENT_ID
                tUser.clientId = "TEST1"
                return next null

              Tenant.getNextClientId tenantId, (err, newClientId) ->
                return next err if err
                return next {error: "new ClientId not found for tenant id: #{tenantId}"} unless newClientId
                tUser.clientId = "#{tenant.clientPrefix}#{newClientId}"
                return next null

          (next) =>
            #Create the new user account
            console.log "User Import Creating New User with data: ", tUser
            #SKIP ACTUALLY CREATING THE USER
            SKIP_UPSERT_USER = false
            if SKIP_UPSERT_USER
              return next null, tUser
            User.upsert tUser, (err, user) ->
              console.log "User Import successfully created user: ", user
              return next err, user

          (user, next) =>
            #Send new user email
            if user.sendWelcomeEmail is true
              Tenant.findById tenantId, (err, tenant) =>
                console.log "Error: failed to send welcome email.  Error: ", err if err
                if tenant
                  @sendWelcomeEmail tenant, user, "", (err) ->
                    console.log "Welcome email failed to send with error: ", err if err
                    console.log "Welcome email sent." unless err
            return next null, user

        ], (err, user) =>
          if err
            console.log "Error failed import users create user account: ", err
            return done err

          user = JSON.stringify(user)
          user = JSON.parse(user)
          return done null, user

      async.mapSeries users, saveUser, (err, results) ->
        console.log "Error creating users from user import: Error: ", err if err
        return res.json({error: err}, 500) if err
        return res.json results

    parseUserImport: (req, res) ->
      token = req.param('token')
      return res.json "Unauthorized", 500 unless token is APITOKEN
      return res.json "Missing param id", 500 unless req.param('id')
      userId = req.param('id')
      tenantId = req.tenant._id
      User.byId userId, (err, user) =>
        return res.json err, 500 if err
        return res.json {error: "user doesn't exist for id: #{userId}"}, 500 if err
        return res.json "Unauthorized User", 401 unless user?.isAdmin and (user?.userType is "tenant_admin" or user?.userType is "super_admin")
        return res.json "Invalid File", 401 unless req.files?.uploadedFiles?.length is 1

        typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
        headers = {}
        processLine = (line, done) =>
          #return next null  #Skip processing this line
          lineCount++
          #return done null, null unless lineCount < 10
          console.log "****************************************Processing #{lineCount} of #{totalRows}"
          data = line.split('"')
          lineMod = ""
          i=0
          for x in data
            x = x.replace(/,/g, "~") if i % 2 > 0
            #console.log "x: ", x
            lineMod = lineMod + x
            i++
          data = lineMod.split(",")
          if lineCount is 1
            index = 0
            for header in data
              if header?.length
                header = header.toLowerCase().trim()
                headers[header] = index
              index++
            console.log "Import file headers row: ", headers
            return done null, null
          tUser = {}
          tUser.email = data[headers['email']] if data[headers['email']]
          tUser.first_name = data[headers['first name']] if data[headers['first name']]
          tUser.middle_name = data[headers['middle name']] if data[headers['middle name']]
          tUser.last_name = data[headers['last name']] if data[headers['last name']]
          tUser.name = data[headers['name']] if data[headers['name']]
          tUser.clientId = data[headers['client id']] if data[headers['client id']]
          tUser.parentId = data[headers['parent id']] if data[headers['parent id']]
          tUser.parentName = data[headers['parent name']] if data[headers['parent name']]
          tUser.phone_cell = data[headers['phone number']] if data[headers['phone number']]
          tUser.active = data[headers['active']] if data[headers['active']]
          tUser.createdAt = data[headers['created']] if data[headers['created']]
          tUser.modified = data[headers['last modified']] if data[headers['last modified']]
          tUser.referredBy = data[headers['referred by']] if data[headers['referred by']]
          tUser.isOutfitter = data[headers['is outfitter']] if data[headers['is outfitter']]
          tUser.isVendor = data[headers['is vendor']] if data[headers['is vendor']]
          tUser.imported = data[headers['imported source']] if data[headers['imported source']]
          tUser.internalNotes = data[headers['internal notes']] if data[headers['internal notes']]
          tUser.needsWelcomeEmail = data[headers['send welcome email']] if data[headers['send welcome email']]
          tUser.mail_address = data[headers['mailing address']] if data[headers['mailing address']]
          tUser.mail_city = data[headers['mailing city']] if data[headers['mailing city']]
          tUser.mail_country = data[headers['mailing country']] if data[headers['mailing country']]
          tUser.mail_postal = data[headers['mailing zipcode']] if data[headers['mailing zipcode']]
          tUser.mail_state = data[headers['mailing state']] if data[headers['mailing state']]
          tUser.physical_address = data[headers['physical address']] if data[headers['physical address']]
          tUser.physical_city = data[headers['physical city']] if data[headers['physical city']]
          tUser.physical_country = data[headers['physical country']] if data[headers['physical country']]
          tUser.physical_postal = data[headers['physical zipcode']] if data[headers['physical zipcode']]
          tUser.physical_state = data[headers['physical state']] if data[headers['physical state']]
          tUserKeys = Object.keys(tUser)
          return done null, null unless tUserKeys?.length

          #For now hard code wither to create the user as a member.
          CREATE_MEMBER = false
          if CREATE_MEMBER
            tUser.isMember = true
            mStarted = new moment()
            mExp = new moment()
            tUser.memberStarted = mStarted
            #tUser.memberExpires = mExp.add(1,'years').add(3,'months')
            tUser.memberExpires = mExp.add(1,'years')

          #Defaults
          tUser.row = lineCount
          tUser.email = tUser.email.toLowerCase() if tUser.email
          tUser.parentId = user._id unless tUser.parentId
          tUser.parentName = user.name unless tUser.parentName
          if !tUser.first_name and tUser.name
            names = @parseName(tUser.name, true)
            tUser.first_name = names.first_name
            tUser.last_name = names.last_name
          else if !tUser.name and (tUser.first_name or tUser.last_name)
            tUser.name = ""
            tUser.name = "#{tUser.first_name}" if tUser.first_name
            tUser.name += " #{tUser.last_name}" if tUser.last_name
            tUser.name = tUser.name.trim() if tUser.name

          tUser.imported = "import file" unless tUser.imported
          now = moment()
          tUser.createdAt = new moment(tUser.createdAt) if tUser.createdAt
          tUser.createdAt = now unless tUser.createdAt?
          tUser.modified = now
          tUser.active = true unless tUser.active?
          tUser.needsWelcomeEmail = false unless tUser.needsWelcomeEmail?

          #CHECK IF USER IS VALID TO CREATE
          async.waterfall [
            (next) ->
              #Check if email is missing
              tUser.missing_email = true unless tUser.email?.length
              return next null

            (next) ->
              console.log 'ddfgddd'
              #Check if user already exists (by userId and tenant)
              return next null unless tUser.userId? or tUser._id?
              User.findOne({_id: userId, tenantId: tenantId}).lean().exec (err, rUser) ->
                tUser.alreadyExists_id = true if rUser
                return next err

            (next) ->
              console.log 'ddfgddd'
              #Check if user already exists (by clientId and tenant)
              return next null unless tUser.clientId
              User.findOne({type: "local", clientId: tUser.clientId, tenantId: tenantId}).lean().exec (err, rUser) ->
                tUser.alreadyExists_clientId = true if rUser
                return next err

            (next) ->
              console.log 'dddd'
              #Check if email already belongs to a different user
              return next null unless tUser.email
              User.findOne({email: tUser.email, tenantId: tenantId}).lean().exec (err, rUser) ->
                tUser.alreadyExists_email = true if rUser
                return next err

            (next) ->
              console.log 'ddfdd'
              #Check if username already belongs to a different user
              return next null unless tUser.username
              User.findOne({username: tUser.username, tenantId: tenantId}).lean().exec (err, rUser) ->
                tUser.alreadyExists_username = true if rUser
                return next err

          ], (err) =>
            if err
              console.log "Error failed import users create user account: ", err
              return done err
            #console.log "Parsed row: tUser: ", tUser
            return done null, tUser


        #Convert Buffer to Stream for readLine input
        importBuffer = req.files.uploadedFiles[0].buffer
        return res.json "Invalid File", 500 unless importBuffer
        bufferStream = new stream.PassThrough()
        bufferStream.end(importBuffer)

        totalRows = 0
        lines = []
        lineCount = 0
        totalRows = 0
        async.waterfall [
          # Read File
          (next) ->
            try
              console.log 'Reading file...'
              lineReader = readline.createInterface({
                input: bufferStream
              });

              lineReader
                .on 'line', (line) ->
                  #console.log 'Line from file:', line
                  #console.log 'lines.length:', lines.length
                  lines.push line
                .on 'close', () ->
                  console.log 'Finished reading file.', lines.length
                  return next null, lines
            catch ex
              console.log "parseImportUsers catch error:", ex
              return next ex

          # For each line create user objects
          (lines, next) =>
            lines = [lines] unless typeIsArray lines
            console.log "found #{lines.length} lines"
            totalRows = lines.length
            async.mapSeries lines, processLine, (err, usersParsed) ->
              users = []
              for tUser in usersParsed
                users.push tUser if tUser
              return next err, users

        ], (err, users) ->
          results = {
            alreadyExists_id: []
            alreadyExists_clientId: []
            alreadyExists_email: []
            alreadyExists_username: []
            missing_email: []
            users: []
            total_entries: 0
          }
          for user in users
            results.total_entries += 1
            if user?.alreadyExists_id or user?.alreadyExists_clientId or user?.alreadyExists_email or user?.alreadyExists_username
              results.alreadyExists_id.push user if user?.alreadyExists_id
              results.alreadyExists_clientId.push user if user?.alreadyExists_clientId
              results.alreadyExists_email.push user if user?.alreadyExists_email
              results.alreadyExists_username.push user if user?.alreadyExists_username
            else if user?.missing_email
              results.missing_email.push user
            else if user
              results.users.push user

          if err
            console.log "Error parsing import users file: ", err
            return res.json {error: "An error occurred trying to parse the user import file."}, 500 if err
          return res.json results


    fileAdd: (req, res) ->
      try
        token = req.param('token')
        return res.json "Unauthorized", 500 unless token is APITOKEN
        console.log "fileAdd req.files", req.files

        userId = req.param('id')

        User.byId userId, (err, user) ->
          return res.json err, 500 if err
          return res.json {error: "user doesn't exist for id: #{userId}"}, 500 if err
          user.files = [] unless user.files?.length

          if req.files?.uploadedFiles?.length
            for file in req.files.uploadedFiles
              ext = ""
              extArray = file.path.split(".")
              ext = extArray[extArray.length-1] if extArray.length > 0
              user.files.push {
                originalName: file.originalname
                extension: ".#{ext}"
                mimetype: file.mimetype
                url: file.path
                size: file.size
                encoding: file.encoding
              }

            User.upsert user, (err, user) ->
              return res.json err, 500 if err
              return res.json user
          else
            return res.json {msg: "No files found to upload"}

      catch ex
        console.log "fileAdd catch error:", ex
        return res.json {error: "An error occurred trying to update media for user: #{userId}"}, 500 if err


    fileRemove: (req, res) ->
      try
        token = req.param('token')
        return res.json "Unauthorized", 500 unless token is APITOKEN

        userId = req.param('id')
        newFileList = []

        console.log "fileRemove req.body.fileNames", req.body?.fileNames

        removeFilename = req.body.fileNames


        User.byId userId, (err, user) ->
          return res.json err, 500 if err
          return res.json {error: "user doesn't exist for id: #{userId}"}, 500 if err
          user.files = [] unless user.files?.length

          for file in user.files
            newFileList.push file unless file.originalName is removeFilename

          user.files = newFileList

          User.upsert user, (err, user) ->
            return res.json err, 500 if err
            return res.json user

    updateSubscriptions: (user, updated_subscriptions, updateMailchimp, cb) ->
      user.subscriptions = {} unless user.subscriptions
      #For convieence and downstream login convert reminders.email to subscriptions.statereminders_email
      if user.reminders?.email is true
        user.subscriptions.statereminders_email = true
      else
        user.subscriptions.statereminders_email = false
      if user.reminders?.text is true
        user.subscriptions.statereminders_text = true
      else
        user.subscriptions.statereminders_text = false
      changed = false
      changed = true if (user.subscriptions.hunts and !updated_subscriptions.hunts) or (!user.subscriptions.hunts and updated_subscriptions.hunts)
      changed = true if (user.subscriptions.products and !updated_subscriptions.products) or (!user.subscriptions.products and updated_subscriptions.products)
      changed = true if (user.subscriptions.newsletters and !updated_subscriptions.newsletters) or (!user.subscriptions.newsletters and updated_subscriptions.newsletters)
      changed = true if (user.subscriptions.rifles and !updated_subscriptions.rifles) or (!user.subscriptions.rifles and updated_subscriptions.rifles)
      changed = true if (user.subscriptions.statereminders_email and !updated_subscriptions.statereminders_email) or (!user.subscriptions.statereminders_email and updated_subscriptions.statereminders_email)
      changed = true if (user.subscriptions.statereminders_text and !updated_subscriptions.statereminders_text) or (!user.subscriptions.statereminders_text and updated_subscriptions.statereminders_text)

      user.subscriptions.hunts = updated_subscriptions.hunts if updated_subscriptions.hunts?
      user.subscriptions.products = updated_subscriptions.products if updated_subscriptions.products?
      user.subscriptions.newsletters = updated_subscriptions.newsletters if updated_subscriptions.newsletters?
      user.subscriptions.rifles = updated_subscriptions.rifles if updated_subscriptions.rifles?
      user.subscriptions.statereminders_email = updated_subscriptions.statereminders_email if updated_subscriptions.statereminders_email?
      user.subscriptions.statereminders_text = updated_subscriptions.statereminders_text if updated_subscriptions.statereminders_text?

      if updated_subscriptions.statereminders_email is true or updated_subscriptions.statereminders_email is "true"
        user.reminders = {} unless user.reminders
        user.reminders.email = true
        user.reminders.types = ["app-start", "app-end"]
      else if updated_subscriptions.statereminders_email is false or updated_subscriptions.statereminders_email is "false"
        user.reminders = {} unless user.reminders
        user.reminders.email = false

      if updated_subscriptions.statereminders_text is true or updated_subscriptions.statereminders_text is "true"
        user.reminders = {} unless user.reminders
        user.reminders.text = true
        user.reminders.types = ["app-start", "app-end"]
      else if updated_subscriptions.statereminders_text is false or updated_subscriptions.statereminders_text is "false"
        user.reminders = {} unless user.reminders
        user.reminders.text = false

      if updated_subscriptions.statereminders_states
        user.reminders.states = updated_subscriptions.statereminders_states

      return cb "User missing id. Subscription update failed." unless user._id
      userData = _.pick user, "_id", "subscriptions", "reminders"
      User.upsert userData, {upsert: false}, (err, user) ->
        if updateMailchimp
          mailchimpapi.upsertUser "MASTER", user, (err, mailchimp_user) ->
            return cb err if err
            return cb "User missing id. Subscription update failed." unless user._id
            return cb err, user
        else
          return cb err, user


    sendWelcomeEmail: (tenant, user, password, cb) ->
      return cb "Missing user email" unless user?.email
      return cb "Missing tenant rrads domain" unless tenant?.rrads_api_base_url

      repDisabled = false
      repDisabled = true if tenant.disableReps? and tenant.disableReps is true
      repDisabled = true if user.repDisabled

      async.waterfall [
        (next) ->
          return next null, null unless user?.parentId
          User.byId user.parentId, {}, (err, parent) ->
            return next null, parent

        (parent, next) ->
          return next null, parent, null if password
          User.defaultPassword user, (err, defaultPassword) ->
            return next null, parent, defaultPassword

        (parent, defaultPassword, next) ->
          payload = {
            user_email: user.email
          }
          payload.user_name = ""
          payload.user_name = user.name if user?.name
          source_domain = tenant.rrads_api_base_url
          source_domain = "rads.rollingbonesoutfitters.com" if tenant.rrads_api_base_url.indexOf("heroku") > -1
          source_domain = "https://#{source_domain}" unless source_domain.indexOf("http") > -1 #check for http or https already there
          if password is "new"
            tEmail = encodeURI(user.email)
            payload.user_password = '<a href="'+source_domain+'/setup_account?email='+tEmail+'">Click here to create your password</a>'
          else if password
            payload.user_password = "******" + '       <br/><a href="'+source_domain+'/forgot_password">Change my password</a>'
          else
            payload.user_password = defaultPassword + '       <br/><a href="'+source_domain+'/forgot_password">Change my password</a>'

          if parent?.name
            payload.parent_name = parent.name
          else
            payload.parent_name = "Rolling Bones Concierge Service"

          if parent?.email
            payload.parent_email = parent.email
          else
            payload.parent_email = "info@rollingbonesoutfitters.com"

          if parent?.phone_cell
            payload.parent_phone = parent.phone_cell
          else
            payload.parent_phone = "(605) 644-8000"


          return next null, payload

      ], (err, payload) ->
        return cb err if err
        template_name = "Welcome"
        if tenant.tmp_email_from_name
          subject = "Welcome to #{tenant.tmp_email_from_name}"
        else
          subject = "Welcome to #{tenant.name}"
        #send emails
        mandrilEmails = []
        if user.email?.length
          email = user.email.toLowerCase().trim()
          to = {
            email: email
            type: "to"
          }
          to.name = user.name if user.name
          mandrilEmails.push to if to
        if payload.parent_email?.length and !repDisabled
          cc = {
            email: payload.parent_email
            type: "cc"
          }
          cc.name = payload.parent_name if payload.parent_name
          mandrilEmails.push cc if cc
        if mandrilEmails.length > 0 #and user.tenantId?.toString() isnt "53a28a303f1e0cc459000127" and user.tenantId?.toString() isnt "5bd75eec2ee0370c43bc3ec7"
          mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, payload, null, null, null, true, null
        return cb()


    parseName: (name, onlyFirstAndLast) ->
      names =
        prefix: ""
        first_name: ""
        middle_name: ""
        last_name: ""
        suffix: ""

      if !name
        return names

      if name is "n/a"
        names =
          first_name: "n/a"
          middle_name: ""
          last_name: "n/a"
        return names

      nameSplit = name.split(" ")

      # NEAL E TOKOWITZ
      if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]

      # ARNOLD CHARLES PITTS
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]

      # CLAIRE PHELAN
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          last_name: matches[2]

      # EARL BENEDICT AXALAN MACASAET
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})\s+(\w{4,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2] + ' ' + matches[3]
          last_name: matches[4]

      # JOHN TITO BERTILACCHI JR
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})\s+(\w{1,3})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]
          suffix: matches[4]

      # JAMES W CRAWFORD III
      else if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w{2,})\s+(\w{1,3})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]
          suffix: matches[4]

      # MR. SCOTT ALLEN FINLEY
      else if matches = name.match(/^([\w\.]{1,3})\s+(\w{2,})\s+(\w{2,})\s+(\w{2,})$/)
        names =
          prefix: matches[1]
          first_name: matches[2]
          middle_name: matches[3]
          last_name: matches[4]

      # BRETT D K VISSER
      else if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w)\s+(\w{4,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2] + ' ' + matches[3]
          last_name: matches[4]

      else if nameSplit?.length > 1
        console.log "Could not parse name! Splitting into two halfs:", name
        i=0
        for nm in nameSplit
          names.first_name = "#{names.first_name} #{nameSplit[i]}" if i < nameSplit.length - 1
          names.last_name = "#{names.last_name} #{nameSplit[i]}" if i == nameSplit.length - 1
          i++
          console.log "Parsed names: ", names

      else
        console.log "Could not parse name!:", name

      if onlyFirstAndLast
        names.first_name = "#{names.prefix} #{names.first_name}" if names.prefix?.length
        names.first_name = "#{names.first_name} #{names.middle_name}" if names.middle_name?.length
        names.last_name = "#{names.last_name} #{names.suffix}" if names.suffix?.length

      return names

  }

  _.bindAll.apply _, [Users].concat(_.functions(Users))
  return Users
