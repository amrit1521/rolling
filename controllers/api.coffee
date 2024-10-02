_ = require "underscore"
async = require "async"
MobileDetect = require 'mobile-detect'
moment = require "moment"
request = require "request"
util = require "util"
http = require 'http'
crypto = require "crypto"

module.exports = (APITOKEN, APITOKEN_ZGF, APITOKEN_RB, APITOKEN_TOI, APITOKEN_DEV, APITOKEN_GMT,
  ZeroGuideFeesTenantId, RollingBonesTenantId, TheOutdoorInsidersTenantId, GotMyTagDevTenantId, GotMyTagTenantId,
  email, logger, NavTools, State, Refer, User, AZPortalAccount, Application, Hunt
  HuntinFoolClient, HuntinFoolState, UserState, Tenant, salt, DrawResult, Secure,
  Point, Reminder, HuntCatalog, points) ->

  API = {

    pointsClientState: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless req.param('token') is APITOKEN

      requiredFields = {
        'token': 'The API token supplied by RBO'
        'state': 'The state for which you want the points'
      }

      conditions = req.body
      conditions.ssn = conditions.ssn.replace(/[^\d]+/g, '') if conditions.ssn?.length and typeof conditions.ssn is 'string'
      console.log "conditions:", conditions

      missing = NavTools.required requiredFields, conditions
      return res.json {error: "The following parameters are required:" + missing.join(', ')}, 400 if missing.length

      if conditions.dob?.length
        sendDOBError = ->
          return res.status(400).json {error: "Date of Birth not a valid date"}

        bParts = conditions.dob.split('-')

        return sendDOBError() if bParts.length isnt 3
        year = parseInt(bParts[0], 10)
        month = parseInt(bParts[1], 10)
        day = parseInt(bParts[2], 10)
        return sendDOBError() if year < moment().subtract(130, 'years').year() or year > moment().subtract(1, 'year').year()
        return sendDOBError() if month < 1 or month > 12
        return sendDOBError() if day < 1 or day > 31

      async.waterfall [

        # Search for user
        (next) ->
          return next() unless conditions.clientId

          User.byClientId conditions.clientId, {internal: true}, (err, user) ->
            if err
              logger.error err if err
              return next {error: "System error", code: 500}

            return next() unless user

            user.userId = user._id
            delete user._id
            _.extend conditions, user
            next()

        # Find state
        (next) ->
          State.byName conditions.state, (err, state) ->
            if err
              logger.error err if err
              return next {error: "System error", code: 500}
            return next {error: "Points are not provided for this state", code: 400} if not state or not state.hasPoints
            conditions.stateId = state._id

            next null, state

        (state, next) ->

          console.log "state:", state

          State.initModel state.name, (err, model) ->
            return next {error: "Points are not provided for this state", code: 400} if err or not model
            next null, model

        (model, next) ->

          model.points conditions, conditions, (err, results) ->
            return next err if err
            return next null, [] unless results?.points

            points = []

            for point in results.points
              newPoint = {
                animal: point.name
                points: point.count
              }
              newPoint.weight = point.weight if point.weight
              points.push newPoint

            return next null, points

      ], (err, points) ->
        if err and err.code and err.code < 1000
          return res.json err, err.code
        else if err
          errorDate = moment().format('YYYY-MM-DD HH:mm:ss ZZ')
          console.log "Something bad happened at [API::pointsClientState] #{errorDate}:", err
          mailOptions =
            from: "RBO Errors <info@rolligbonesoutfitters.com>"
            to: "info@rolligbonesoutfitters.com"
            subject: "An unexptected API::pointsClientState API error occurred: #{errorDate} - rollingbones.com"
            text: util.inspect(err, {depth: 5})

          email.sendMail mailOptions, (err, response) ->
            return console.log "API error email failed:", err if err
            console.log "API error email sent:", response

          return res.json {error: "Something unexpected happened.  Please report to info@rollingbonesoutfitters.com"}, 500

        res.json points

    handleReferrer: (req, res) ->
      referrer = req.param('referrer') #should be format "<tenantPrefix>_<clientId>_<campaign>"

      #TODO: Try replacing this section when you can test by calling out to: @checkRefer req, (err, refer) ->
      md = new MobileDetect req.headers['user-agent']

      ###
      console.log "req.headers['x-forwarded-for']: " + req.headers['x-forwarded-for'] if req.headers['x-forwarded-for']
      console.log "req.connection.remoteAddress: " + req.connection.remoteAddress if req.connection and req.connection.remoteAddress
      console.log "req.socket.remoteAddress: " + req.socket.remoteAddress if req.socket and req.socket.remoteAddress
      console.log "req.connection.socket.remoteAddress: " + req.connection.socket.remoteAddress if req.connection.socket and req.connection.socket.remoteAddress
      ###

      #handles proxies
      xForward = req.headers['x-forwarded-for'].split(",")[0] if req.headers['x-forwarded-for']

      if xForward or req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket.remoteAddress
        ip = xForward or req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket.remoteAddress
        refer = {}
        refer.ip = ip.replace("::ffff:","")
        refer.referrer = referrer
        refer.modified = moment()
        logger.info "Refer upsert: ", refer
        Refer.upsert refer, (err, refer) ->
          logger.error err if err
          return

      #HuntinFool App
      huntinFoolAppPrefix = '/download/hf'
      if req.url.toLowerCase().slice(0, huntinFoolAppPrefix.length) == huntinFoolAppPrefix
        return res.redirect('https://itunes.apple.com/us/app/huntin-fool-app/id921898470?mt=8&uo=4&at=1l3vpF5&ct=' + referrer) if md.os() is 'iOS'
        return res.redirect('https://play.google.com/store/apps/details?id=com.gotmytag.huntintool&referrer=utm_source%3Daffiliate%26utm_medium%3Dwebsite%26utm_campaign%3D' + referrer) if md.os() is 'AndroidOS'
        #return res.redirect 'https://www.huntintool.com/#!/register?referrer=' + referrer
        return res.redirect 'https://www.huntinfool.com/app/'

      #PointHunter App
      return res.redirect('https://itunes.apple.com/us/app/pointhunter/id900742380?mt=8&uo=4&at=1l3vpF5&ct=' + referrer) if md.os() is 'iOS'
      return res.redirect('https://play.google.com/store/apps/details?id=com.gotmytag.pointhunter&referrer=utm_source%3Daffiliate%26utm_medium%3Dwebsite%26utm_campaign%3D' + referrer) if md.os() is 'AndroidOS'

      #OGTV browser register page
      OGTVPrefix = '/download/ogtv'
      if req.url.toLowerCase().slice(0, OGTVPrefix.length) == OGTVPrefix
        return res.redirect 'https://ogtv.gotmytag.com/#!/register?referrer=' + referrer

      #RollingBones browser register page
      RBPrefix = '/download/rb'
      if req.url.toLowerCase().slice(0, RBPrefix.length) == RBPrefix
        return res.redirect 'https://rollnbones.gotmytag.com/#!/register?referrer=' + referrer

      #NorthWest Hunting browser register page
      NWPrefix = '/download/nw'
      if req.url.toLowerCase().slice(0, NWPrefix.length) == NWPrefix
        return res.redirect 'https://nw.gotmytag.com/#!/register?referrer=' + referrer

      #TheOutdoorInsiders  browser register page
      TOIPrefix = '/download/toi'
      if req.url.toLowerCase().slice(0, TOIPrefix.length) == TOIPrefix
        return res.redirect 'https://theoutdoorinsiders.gotmytag.com/#!/register?referrer=' + referrer

      #BowHuntingSafari  browser register page
      BHSPrefix = '/download/bhs'
      if req.url.toLowerCase().slice(0, BHSPrefix.length) == BHSPrefix
        return res.redirect 'https://bowhuntingsafari.gotmytag.com/#!/register?referrer=' + referrer

      #GetNDrawn  browser register page
      GNDPrefix = '/download/gnd'
      if req.url.toLowerCase().slice(0, GNDPrefix.length) == GNDPrefix
        return res.redirect 'https://getndrawn.gotmytag.com/#!/register?referrer=' + referrer

      #HuntersDomain  browser register page
      HDPrefix = '/download/hd'
      if req.url.toLowerCase().slice(0, HDPrefix.length) == HDPrefix
        return res.redirect 'https://huntersdomain.gotmytag.com/#!/register?referrer=' + referrer

      #The Draw  browser register page
      TDPrefix = '/download/td'
      if req.url.toLowerCase().slice(0, HDPrefix.length) == TDPrefix
        return res.redirect 'https://thedraw.gotmytag.com/#!/register?referrer=' + referrer

      #If we haven't gone anywhere else yet, redirect to browser point hunter app register page
      return res.redirect 'https://test.gotmytag.com/#!/register?referrer=' + referrer


    handleReferrerHuntCatalog: (req, res) ->
      referrer = req.param('referrer') #should be format "<tenantPrefix>_<clientId>_<campaign>"
      if referrer
        referrerArray = referrer.split("_")
        parentClientId = referrerArray[1] if referrerArray.length >= 2
      huntCatalogId = req.param('id')
      @checkRefer req, (err, refer) ->
        parentClientIdStr = ""
        parentClientIdStr = "?ref=#{parentClientId}" if parentClientId
        return res.redirect "/#!/huntcatalog/#{huntCatalogId}#{parentClientIdStr}" if huntCatalogId
        return res.redirect "/#!/huntcatalogs#{parentClientIdStr}"

    checkRefer: (req, cb) ->
      md = new MobileDetect req.headers['user-agent']
      referrer = req.param('referrer')  #should be format "<tenantPrefix>_<clientId>_<campaign>"
      return cb null, null unless referrer

      ###
      console.log "req.headers['x-forwarded-for']: " + req.headers['x-forwarded-for'] if req.headers['x-forwarded-for']
      console.log "req.connection.remoteAddress: " + req.connection.remoteAddress if req.connection and req.connection.remoteAddress
      console.log "req.socket.remoteAddress: " + req.socket.remoteAddress if req.socket and req.socket.remoteAddress
      console.log "req.connection.socket.remoteAddress: " + req.connection.socket.remoteAddress if req.connection.socket and req.connection.socket.remoteAddress
      ###

      #handles proxies
      xForward = req.headers['x-forwarded-for'].split(",")[0] if req.headers['x-forwarded-for']

      if xForward or req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket.remoteAddress
        ip = xForward or req.connection.remoteAddress or req.socket.remoteAddress or req.connection.socket.remoteAddress
        refer = {}
        refer.ip = ip.replace("::ffff:","")
        refer.referrer = referrer
        refer.modified = moment()
        logger.info "Refer upsert: ", refer
        Refer.upsert refer, (err, refer) ->
          logger.error err if err
          return cb err, refer
      else
        return cb null, null

    importUser: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body
      logger.info "api user import data:", data

      # Assign TenantId based on token
      if req.param('token') is APITOKEN_ZGF
        data.tenantId = ZeroGuideFeesTenantId
        data.imported = "ZGFMemberImport"
      else if req.param('token') is APITOKEN_RB
        data.tenantId = RollingBonesTenantId
        data.imported = "RBMemberImport"
      else if req.param('token') is APITOKEN_TOI
        data.tenantId = TheOutdoorInsidersTenantId
        data.imported = "TOIMemberImport"
      else if req.param('token') is APITOKEN_DEV
        data.tenantId = GotMyTagDevTenantId
        data.imported = "GMTDEV_MemberImport"
      else
        return res.json {error: "Unauthorized"}, 401

      return res.json {error: "missing memberId: memberId is required to import a user through this API."}, 400 unless data.memberId

      # clean data
      data.ssn = data.ssn.replace(/[^\d]+/g, '') if data.ssn?.length and typeof data.ssn is 'string'
      data.drivers_license = data.drivers_license.replace(/[^\w\d]+/g, '') if data.drivers_license
      data.phone_cell = (''+ data.phone_cell).replace(/[^0-9]+/g, '') if data.phone_cell
      data.phone_day = (''+ data.phone_day).replace(/[^0-9]+/g, '') if data.phone_day
      data.phone_home = (''+ data.phone_home).replace(/[^0-9]+/g, '') if data.phone_home

      data.azUnencryptedAZPassword = data.azPassword if data.azPassword
      data.azPassword = Secure.encrypt data.azPassword if data.azPassword
      data.nmPassword = Secure.encrypt data.nmPassword if data.nmPassword
      data.idPassword = Secure.encrypt data.idPassword if data.idPassword
      data.waPassword = Secure.encrypt data.waPassword if data.waPassword
      data.coPassword = Secure.encrypt data.coPassword if data.coPassword
      data.mtPassword = Secure.encrypt data.mtPassword if data.mtPassword
      data.nvPassword = Secure.encrypt data.nvPassword if data.nvPassword

      # validate dob format yyyy-mm-dd
      if data.dob?.length
        sendDOBError = ->
          return res.status(400).json {error: "Date of Birth not a valid date"}
        bParts = data.dob.split('-')
        return sendDOBError() if bParts.length isnt 3
        year = parseInt(bParts[0], 10)
        month = parseInt(bParts[1], 10)
        day = parseInt(bParts[2], 10)
        return sendDOBError() if year < moment().subtract(130, 'years').year() or year > moment().subtract(1, 'year').year()
        return sendDOBError() if month < 1 or month > 12
        return sendDOBError() if day < 1 or day > 31

      data.name = "#{data.first_name} #{data.last_name}" if data.first_name and data.last_name
      data.password = @hashPassword(data.password) if data.password and data.tenantId != RollingBonesTenantId #if it's RB, the are sending us already encrypted passwords

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null, null unless data.userId
          User.findOne({_id: data.userId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          return next null, user if user
          #Check if user already exists (by memberId and tenant)
          User.findOne({type: "local", memberId: data.memberId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          #Check if username already belongs to a different user
          return next null, user, null unless data.username
          User.findOne({username: data.username, tenantId: data.tenantId}).lean().exec (err, usernameCheck) ->
            next err, user, usernameCheck

        (user, usernameCheck, next) ->
          #Check if username already belongs to a different user
          return next "User import failed.  The username already exists for a different user, memberId = " + usernameCheck.memberId if usernameCheck?.memberId and usernameCheck.memberId != data.memberId

          if data.tenantId.toString() is RollingBonesTenantId
            data.isMember = true if data.memberType is "RBO Member"
            data.isRep = true if data.memberType is "Adventure Advisor"
            data.repType = data.memberType if data.isRep

          if user
            #========UPDATE THE USER========
            data._id = user._id
            logger.info "user update:", data
            User.upsert data, {internal: false, upsert: false}, (err, user) ->
              next err, user
          else
            #========INSERT NEW USER========
            #logger.info "user insert:", data
            requiredFields = {
              'token': "'token' (the API token supplied by GotMyTag)",
              'first_name': "'first_name' (users first name)",
              'last_name': "'last_name' (users last name)",
              'memberId': "'memberId' (the unique identifier for a user)",
              'powerOfAttorneyGranted' : "'powerOfAttorneyGranted' (true/false the power of Attorney has been granted by this user to apply for state applications)"
            }
            missing = NavTools.required requiredFields, data
            return res.json {error: "The following parameters are required when creating a new user: " + missing.join(', ')}, 400 if missing.length

            if data.powerOfAttorneyGranted == true || data.powerOfAttorneyGranted == "true" || data.powerOfAttorneyGranted == "1"
              data.powerOfAttorney = true
            else
              data.powerOfAttorney = false

            data.type = 'local'

            #Assign the new user a Client Id
            Tenant.findById data.tenantId, (err, tenant) ->
              return next err if err
              return next "Error: Could not find tenant for tenant id ''#{data.tenantId}" unless tenant

              Tenant.getNextClientId tenant._id, (err, newClientId) ->
                return next err if err
                next {error: "tenant not found for id: #{data.tenantId}"} unless newClientId
                data.clientId = "#{tenant.clientPrefix}#{newClientId}"

                #Insert the new user
                User.upsert data, {internal: false, upsert: true}, (err, user) ->
                  next err, user

        (user, next) ->
          #Attach the user to the parent if there is a member parent id
          return next null, user unless user.parent_memberId
          User.byMemberId user.parent_memberId, data.tenantId, (err, parent) ->
            return next err if err
            return next null, user unless parent
            userData = {
              _id: user._id,
              parentId: parent._id
            }
            User.upsert userData, {upsert: false}, (err, user) ->
              logger.info "assigned user #{user._id} to parent #{parent._id} based on the user's member parent id '#{user.parent_memberId}'"
              return next {error: err} if err
              return next null, user

        (user, next) ->
          #Update the AZPortalAccount if a azUsername and azPassword were provided
          return next null, user unless data.azUsername and data.azPassword
          azPAcctData = {
            userId: user._id
            azUsername: data.azUsername
          }
          azPAcctData.azPassword = data.azUnencryptedAZPassword if data.azUnencryptedAZPassword

          #AZPortalAccount encryptes the password on upsert
          AZPortalAccount.upsert azPAcctData, (err, azPAcct) ->
            return next err if err
            return next null, user

        (user, next) ->
          return next null, user unless data.powerOfAttorneyGranted

          # Insert into Clients and StateApplications table
          clientData = {
            client_id: user.clientId
            needEncryptCC: false
            nmfst: user.first_name
            nmlt: user.last_name
            userId: user._id
          }
          HuntinFoolClient.upsert clientData, (err, client) ->
            if err
              logger.error "Failed to create client for user #{user._id}.", err
              next err



            # Insert into state application options collection
            applicationData = {
              client_id: client.client_id
              userId: user._id
              year: moment().year()
              az_species : "Desert Sheep\nMule Deer\nBuffalo\nElk\nAntelope\n"
              ca_species : "Desert Sheep\nMule Deer \nTule Elk\nAntelope\n"
              co_species : "Elk\nRM Sheep\nDesert Sheep\nDeer\nMoose\nAntelope\nGoat\n"
              ia_species : "Whitetail Deer"
              id_species_1 : "Sheep\nMoose\nGoat"
              id_species_3 : "Mule Deer\nElk\nAntelope"
              ks_mule_deer_stamp : "True"
              ks_species : "Whitetail Deer"
              ky_species : "Elk"
              mt_species : "Sheep\nMoose\nGoat\nDeer\nElk\nAntelope\n"
              nm_species : "Desert Sheep\nBarbary Sheep\nAntelope\nDeer\nOryx\nElk\nIbex"
              nd_species : "Sheep\nPronghorn\nDeer\nElk\nMoose"
              nv_species : "CA Sheep\nDesert Sheep\nMule Deer\nAntelope\nElk Silver State Tag\nAnte Silver State Tag\nDeer Silver State Tag\nDesert Silver State Tag\n-Elk\nGoat\n"
              ore_species : "Antelope\nElk\nColumbian Whitetail\nCalifornia Sheep\nGoat\nDeer\n"
              pa_species : "Elk Lottery\nElk Quota\n"
              sd_species : "Deer\nElk\nAntelope\nGeneral Deer\nYouth Elk\n"
              tx_species : "Sheep\n"
              ut_species_1 : "Deer\nElk\nAntelope\nGeneral Deer\nYouth Elk\n"
              ut_species_2 : "Moose\nRocky Mtn Sheep\nDesert Sheep\nGoat\nBuffalo\n"
              vt_species : "Moose\n"
              wa_species : "Sheep\nMoose\nGoat\nCR Goat\n"
              wy_species : "Antelope\nSheep\nMoose\nGoat\nDeer\nElk\nBison\n"
            }

            if data.tenantId.toString() is ZeroGuideFeesTenantId
              data.applyAllStates = true

            if data.applyAllStates
              applicationData.az_check = "True"
              applicationData.ca_check = "True"
              applicationData.co_check = "True"
              applicationData.ia_check = "True"
              applicationData.id_check = "True"
              applicationData.ks_check = "True"
              applicationData.ky_check = "True"
              applicationData.mt_check = "True"
              applicationData.nd_check = "True"
              applicationData.nm_check = "True"
              applicationData.nv_check = "True"
              applicationData.ore_check = "True"
              applicationData.pa_check = "True"
              applicationData.sd_check = "True"
              applicationData.tx_check = "True"
              applicationData.ut_check = "True"
              applicationData.vt_check = "True"
              applicationData.wa_check = "True"
              applicationData.wy_check = "True"

            HuntinFoolState.upsert applicationData, (err, application) ->
              if err
                logger.info "Failed to create state options for user #{user._id}.", err
                next err
              next null, user



      ], (err, user) ->
        return res.json {error: err}, 500 if err
        # Create successful response
        user = {id: user._id}
        result = {
          user
        }
        res.json result


    state: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body
      logger.info "api state data:", data

      # Assign TenantId based on token
      if req.param('token') is APITOKEN_ZGF
        data.tenantId = ZeroGuideFeesTenantId
      else if req.param('token') is APITOKEN_RB
        data.tenantId = RollingBonesTenantId
      else if req.param('token') is APITOKEN_TOI
        data.tenantId = TheOutdoorInsidersTenantId
      else if req.param('token') is APITOKEN_DEV
        data.tenantId = GotMyTagDevTenantId
      else
        return res.json {error: "Unauthorized"}, 401

      requiredFields = {
        'token': 'The API token supplied by GotMyTag'
        'memberId': 'Unique identifier for a user'
        'state': 'State (full name, i.e "Utah")'
        'stateId': 'Unique state id (such as California GO Id)'
        'applicationNotes': 'User application notes for this state'
      }

      missing = NavTools.required requiredFields, data
      return res.json {error: "The following parameters are required:" + missing.join(', ')}, 400 if missing.length

      User.findOne({type: "local", memberId: data.memberId, tenantId: data.tenantId}).lean().exec (err, user) =>
        if err
          logger.error "find local user error:", err
          res.json({error: err}, 500)

        return res.json({error: "memberId doesn't exist yet.  Please register this user first and try again."}, 409) unless user

        #logger.info "updating user state info:", data

        State.byName data.state, (err, state) =>
          if err
            logger.error "Failed to get state for #{data.state}", err
            return res.json({error: err}, 500)
          return res.json({error: "Invalid state #{data.state}.  Please use the state's full proper name and try again."}, 500) unless state

          userStateDate = {
            cid: data.stateId
            stateId: state._id
            userId: user._id
          }

          UserState.upsert userStateDate, (err, userStateresult) =>
            if err
              logger.error "Failed to update UserState", err
              return res.json({error: err}, 500)
            return res.json({error: "Failed to save user state data."}, 500) unless userStateresult

            HuntinFoolState.byClientId user.clientId, (err, hfState) =>
              if err
                logger.error "Failed to retrieve hfState document", err
                return res.json({error: err}, 500)
              return res.json({error: "State document doesn't exist for client_id #{user.clientId}."}, 500) unless hfState
              notesField = "#{state.abbreviation.toLocaleLowerCase()}_notes"
              hfState[notesField] = data.applicationNotes

              #logger.info "HuntinFoolState upsert:", hfState
              opts = {
                query: {
                  client_id: user.clientId
                }
                upsert: false
              }
              HuntinFoolState.upsert hfState, opts, (err, application) =>
                if err
                  logger.error "Failed to update State Application notes", err
                  return res.json({error: err}, 500)
                return res.json({error: "Failed to save State Application notes."}, 500) unless application

                # Create successful response
                status = {status: "State info updated successfully"}
                result = {
                  status
                }

                res.json result


    drawresult: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body
      logger.info "api drawresult data:", data

      data.tenantId = @assignTenantId(req.param('token'))
      return res.json {error: "Unauthorized"}, 401 if data.tenantId == "none"
      return res.json {error: "missing memberId or userId: memberId or userId is required."}, 400 unless data.memberId or data.userId
      return res.json {error: "missing field 'state' is required."}, 400 unless data.state
      return res.json {error: "missing field 'year' is required."}, 400 unless data.year

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null, null unless data.userId
          User.findOne({_id: data.userId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          return next null, user if user
          #Check if user already exists (by memberId and tenant)
          User.findOne({type: "local", memberId: data.memberId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          if !user
            return next "Failed to find user for userId: #{data.userId}" if data.userId
            return next "Failed to find user for memberId: #{data.memberId}" if data.memberId
          State.byName data.state, (err, state) ->
            return next err if err
            return next "Invalid State. No state found for '#{data.state}'" unless state
            return next null, user, state

        (user, state, next) ->

          DrawResult.byUserStateYear data.userId, state._id, data.year, data.tenantId, (err, results) ->
            return next err if err
            return next "No draw results found for user #{user.name}, memberId: #{user.memberId}, userId: #{user._id}, state: #{data.state}, year: #{data.year}" unless results
            return next err, results, user

      ], (err, drawresults, user) ->
        return res.json {error: err}, 500 if err
        rsp = {}
        rsp.userId = user._id
        rsp.memberId = user.memberId if user.memberId
        rsp.clientId = user.clientId if user.clientId
        rsp.state = data.state
        rsp.year = data.year
        rsp.drawresults = []
        for drawresult in drawresults
          tDrawResult = {
            name: drawresult.name
            status: drawresult.status
            notes: drawresult.notes
            unit: drawresult.unit
            year: drawresult.year
          }
          rsp.drawresults.push(tDrawResult)

        res.json rsp


    huntCatalogs: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body

      data.tenantId = @assignTenantId(req.param('token'))
      return res.json {error: "Unauthorized"}, 401 if data.tenantId == "none"
      return res.json {error: "missing userId: userId is required."}, 400 unless data.userId
      return res.json {error: "missing tenantId: tenantId is required."}, 400 unless data.tenantId

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant), just for extra security
          return next null, null unless data.userId
          User.findOne({_id: data.userId, tenantId: data.tenantId}).lean().exec (err, user) ->
            return next err if err
            return next "Failed to find user for userId: #{data.userId}" unless user
            return next err, user

        (user, next) ->
          HuntCatalog.byTenant req.tenant._id, (err, huntCatalogs) ->
            return err if err

            addHuntCatalog = (huntCatalog, done) ->
              if huntCatalog.isActive
                tHuntCatalog = _.pick(huntCatalog, '_id','huntNumber','title','isHuntSpecial','memberDiscount','country',
                  'state','area','species','weapon','price','startDate','endDate','pricingNotes','description','huntSpecialMessage',
                  'classification','updatedAt','status','type')
                tHuntCatalog.media = huntCatalog.media if huntCatalog.media
                delete tHuntCatalog.startDate unless huntCatalog.startDate and new Date(huntCatalog.startDate.toISOString()) > new Date("2000-01-01")
                delete tHuntCatalog.endDate unless huntCatalog.endDate and new Date(huntCatalog.endDate.toISOString()) > new Date("2000-01-01")
                return done err, tHuntCatalog
              else
                return done err, null

            async.mapSeries huntCatalogs, addHuntCatalog, (err, huntCatalogs) ->
              return err if err
              tHuntCatalogs = []
              for huntCatalog in huntCatalogs
                tHuntCatalogs.push huntCatalog if huntCatalog
              return next null, tHuntCatalogs
              res.json tHuntCatalogs

      ], (err, huntCatalogs) ->
        return res.json {error: err}, 500 if err
        res.json huntCatalogs

    createStateAccount: (req, res) ->
      return res.json {error: "Deprecated and Removed"}, 401

    populateStateAccount: (req, res) ->
      return res.json {error: "Deprecated and Removed"}, 401

    receipts: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body
      logger.info "api receipts data:", data

      data.tenantId = @assignTenantId(req.param('token'))
      return res.json {error: "Unauthorized"}, 401 if data.tenantId == "none"
      return res.json {error: "missing memberId or userId: memberId or userId is required."}, 400 unless data.memberId or data.userId
      return res.json {error: "missing field 'state' is required."}, 400 unless data.state
      return res.json {error: "missing field 'year' is required."}, 400 unless data.year

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null, null unless data.userId
          User.findOne({_id: data.userId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          return next null, user if user
          #Check if user already exists (by memberId and tenant)
          User.findOne({type: "local", memberId: data.memberId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          if !user
            return next "Failed to find user for userId: #{data.userId}" if data.userId
            return next "Failed to find user for memberId: #{data.memberId}" if data.memberId
          State.byName data.state, (err, state) ->
            return next err if err
            return next "Invalid State. No state found for '#{data.state}'" unless state
            return next null, user, state

        (user, state, next) ->
          Application.receiptsByUserState data.userId, state._id, (err, results) ->
            return next err if err
            return next "No application receipts found for user #{user.name}, userId: #{user._id}, memberId: #{user.memberId}, state: #{data.state}, year: #{data.year}" unless results
            return next err, results, user

        (applications, user, next) ->

          processHunt = (huntId, done) ->
            Hunt.byId huntId, (err, hunt) ->
              return done err, hunt.name

          processApplication = (application, done) ->
            application.hunts = []
            async.mapSeries application.huntIds, processHunt, (err, huntNames) ->
              return done err if err
              for huntName in huntNames
                application.hunts.push huntName if huntName
              return done null, application

          async.mapSeries applications, processApplication, (err, applications) ->
            return next err, applications, user


      ], (err, applications, user) ->
        return res.json {error: err}, 500 if err
        rsp = {}
        rsp.userId = user._id
        rsp.state = data.state
        rsp.year = data.year
        rsp.receipts = []
        for app in applications
          #continue if app.year == data.year
          rData = {
            name: app.name
            status: app.status
            timestamp: app.timestamp
            transactionId: app.transactionId
            receipt: app.receipt
          }
          rData.hunts = app.hunts if app.hunts
          rData.licenses = app.license if app.license
          rData.licenses = app.licenses if app.licenses
          rsp.receipts.push rData

        res.json rsp


    usersummary: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body
      logger.info "api usersummary data:", data

      data.tenantId = @assignTenantId(req.param('token'))
      return res.json {error: "Unauthorized"}, 401 if data.tenantId == "none"
      return res.json {error: "missing memberId or userId: memberId or userId is required."}, 400 unless data.memberId or data.userId

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null, null unless data.userId
          User.findOne({_id: data.userId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          return next null, user if user
          #Check if user already exists (by memberId and tenant)
          User.findOne({type: "local", memberId: data.memberId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          if !user
            return next "Failed to find user for userId: #{data.userId}" if data.userId
            return next "Failed to find user for memberId: #{data.memberId}" if data.memberId
          return next null, user

        #Get Reminders
        (user, next) ->
          return next null, user, null unless user?.reminders?.states
          Reminder.byStatesTenant data.tenantId, user.reminders.states, (err, reminders) ->
            return next err if err
            tReminders = []
            for reminder in reminders
              reminder = _.pick reminder, ['state', 'title','start','end','emailStart','emailEnd','startSubject','endSubject']
              tReminders.push reminder
            return next err, user, tReminders

        #Get Points
        (user, reminders, next) ->
          Point.byUser data.userId, (err, points) ->
            return next err if err

            addState = (point, done) ->
              State.byId point.stateId, (err, state) ->
                return done err if err
                point.state = state.name if state
                point = _.pick point, ['userId','name','count','state','area','lastPoint','weight']
                return done null, point

            async.mapSeries points, addState, (err, points) ->
              return next err, user, reminders, points

      ], (err, user, reminders, points) ->
        return res.json {error: err}, 500 if err
        rsp = {}
        rsp.user = _.pick user, ['_id','clientId','memberId', 'isMember', 'isRep', 'dob','email','first_name','middle_name','last_name','memberType','phone_cell', 'residence']
        rsp.reminders = reminders
        rsp.points = points
        res.json rsp


    refreshPoints: (req, res) ->
      return res.json {error: "Unauthorized"}, 401 unless @isValidToken(req.param('token'))

      data = req.body
      logger.info "api refreshPoints data:", data

      data.tenantId = @assignTenantId(req.param('token'))
      return res.json {error: "Unauthorized"}, 401 if data.tenantId == "none"
      return res.json {error: "missing memberId or userId: memberId or userId is required."}, 400 unless data.memberId or data.userId

      async.waterfall [
        (next) ->
          #Check if user already exists (by userId and tenant)
          return next null, null unless data.userId
          User.findOne({_id: data.userId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          return next null, user if user
          #Check if user already exists (by memberId and tenant)
          User.findOne({type: "local", memberId: data.memberId, tenantId: data.tenantId}).lean().exec (err, user) ->
            next err, user

        (user, next) ->
          if !user
            return next "Failed to find user for userId: #{data.userId}" if data.userId
            return next "Failed to find user for memberId: #{data.memberId}" if data.memberId
          return next null, user

        (user, next) ->
          State.hasPoints (err, states) ->
            next err, user, states

        #Refresh Points
        (user, states, next) ->
          async.mapSeries states, points.getState(user), (err, results) ->
            return next err, user, results

      ], (err, user, results) ->
        return res.json {error: err}, 500 if err
        rsp = {}
        rsp.user = _.pick user, ['_id','clientId','memberId', 'isMember','isRep', 'dob','email','first_name','middle_name','last_name','memberType','phone_cell', 'residence']
        #rsp.results = results
        res.json rsp

    hashPassword: (password) ->
      shasum = crypto.createHash('sha1')
      shasum.update(password)
      shasum.update(salt)
      shasum.digest('hex')

    isValidToken: (token) ->
      return false
      return token is APITOKEN_ZGF || APITOKEN_RB || APITOKEN_TOI || APITOKEN_DEV || APITOKEN_GMT

    assignTenantId: (token) ->
      if token is APITOKEN_ZGF
        return ZeroGuideFeesTenantId
      else if token is APITOKEN_RB
        return RollingBonesTenantId
      else if token is APITOKEN_TOI
        return TheOutdoorInsidersTenantId
      else if token is APITOKEN_DEV
        return GotMyTagDevTenantId
      else if token is APITOKEN_GMT
        return GotMyTagTenantId
      else
        return "none"

  }

  _.bindAll.apply _, [API].concat(_.functions(API))
  return API
