_          = require "underscore"
async      = require "async"
creditcard = require 'creditcard'
fs         = require "fs"
util       = require "util"


module.exports = (
  Hunt
  HuntChoice
  HuntinFoolClient
  HuntinFoolTenantId
  logger
  NavTools
  Secure
  State
  User
  UserState
  ZGFfeeCC
  ZeroGuideFeesTenantId
) ->

  # Use the admin email address instead of the user's femail address
  useAdminEmailTenants = [
    HuntinFoolTenantId
    ZeroGuideFeesTenantId
  ]

  HuntChoices = {
    get: (req, res) ->
      HuntChoice.byUserHunt req.param('userId'), req.param('huntId'), (err, choices) ->
        return res.json {error: err}, 500 if err
        res.json choices

    _save: (choice, cb) ->
      async.waterfall [
        (next) ->
          Hunt.byId choice.huntId, next

        (hunt, next) ->
          choice.groupable = true if hunt.groupable

          HuntChoice.byUserHunt choice.userId, choice.huntId, (err, huntChoice) ->
            return next err if err
            next null, hunt, huntChoice

        (hunt, huntChoice, next) ->
          #save the choice here
          stateId = hunt?.stateId.toString()
          hunt = ''
          hunt = JSON.stringify choice.hunt if typeof choice?.hunt is 'object'

          if not huntChoice
            huntChoice = new HuntChoice _.extend choice, {stateId: stateId, hunt}
          else
            huntChoice.choices = choice.choices
            huntChoice.hunt = hunt
            huntChoice.stateId = stateId
            huntChoice.preferecePoint = choice.preferecePoint

          console.log "hunt_choices:_save", huntChoice
          huntChoice.save (err) ->
            if err
              console.log "huntChoice:", huntChoice
              console.log "HuntChoices::_save err:", err
            next err, hunt

      ], cb

    purchase: (stream, data, cb) ->
      return cb {error: "Your browser needs to be refreshed.  Please logout, force refresh, and log back in."}, 401 unless stream.user.isAdmin

      applicationData = _.extend {
        adminUser: if stream.user.isAdmin then stream.user else null
        tenant: stream.tenant
      }, data

      #console.log "purchase called with applicationData:", applicationData

      #ZeroGuideFees pays for all their users applicatiosn and licenses.
      if applicationData.tenant._id.toString() is ZeroGuideFeesTenantId
         applicationData.card = ZGFfeeCC

      async.waterfall [

        #Update the User with any info set during the purchase on the application
        (next) =>
          return next() unless applicationData.licenseNumber or applicationData.licenseNumberYear

          if applicationData.stateId is "547fee39ac604956f8b14370" #Alaska
            userUpdate = {
              alaska_license: applicationData.licenseNumber
              alaska_license_year: applicationData.licenseNumberYear
            }
          else if applicationData.stateId is "52aaa4cbe4e055bf33db649b" #Idaho
            userUpdate = {
              idaho_license: applicationData.licenseNumber
              idaho_license_year: applicationData.licenseNumberYear
            }
          return next() unless userUpdate
          User.findByIdAndUpdate applicationData.userId, userUpdate, (err) ->
            return next err if err
            return next()

        #Get User
        (next) =>
          User.findById applicationData.userId, {internal: true}, (err, user) ->
            return next err if err
            applicationData.user = user
            next()

        #Get CCard
        (next) ->
          cardId = data.cardId
          cardIndex = data.cardIndex
          cardId = cardIndex.index if not cardId and cardIndex and not cardIndex.isNew
          if cardId in ['1', '2']
            user = applicationData.user
            # Get HuntinFoolClient record
            HuntinFoolClient.byUserId user._id, (err, huntinFoolClient) ->
              return next err if err

              if huntinFoolClient['billing' + cardId + '_address']?.length
                # use billing info
                address = {
                  address: huntinFoolClient["billing" + cardId + "_address"]
                  address2: huntinFoolClient["billing" + cardId + "_address2"]
                  city:     huntinFoolClient["billing" + cardId + "_city"]
                  country:  if user.mail_country?.length then user.mail_country else if user.physical_country?.length then user.physical_country else 'United States'
                  state:    NavTools.stateFromAbbreviation(huntinFoolClient["billing" + cardId + "_state"])
                  postal:   huntinFoolClient["billing" + cardId + "_zip"]
                  phone:   huntinFoolClient["billing" + cardId + "_phone"]
                  email:   huntinFoolClient["billing" + cardId + "_email"]
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

              switch cardId
                when '1'
                  {credit, exp} = Secure.decredit [user.field6, user.field7]
                  # Get card from db if cardId
                  type = creditcard.parse(credit).scheme
                  ccName = Secure.decrypt user.field4

                  applicationData.card = _.extend {
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

                  applicationData.card = _.extend {
                    code: Secure.decrypt user.field10
                    month: exp.substr 0, 2
                    year: exp.substr 2, 4
                    name: if ccName.length then ccName else user.name
                    number: credit
                    phone: user.phone_day
                    type: type
                  }, address

              next()

          else if cardIndex?.isNew
            applicationData.card = cardIndex
            applicationData.card.number = ('' + applicationData.card?.number).replace /[^\d]/g, ''
            applicationData.cardIndex = null
            next()
          else
            return next() unless data.card
            applicationData.card = data.card
            applicationData.card.number = ('' + applicationData.card?.number).replace /[^\d]/g, ''
            next()

        # add hunt data
        (next) ->
          Hunt.byStateId applicationData.stateId, (err, stateHunts) ->
            return next err if err

            applicationData.stateHunts = stateHunts

            next()

        (next) =>
          # Need to validate the card data here
          next()

        (next) =>
          # Remove previous hunt choices
          if applicationData.blankHunts
            HuntChoice.removeByUserHuntIds applicationData.userId, applicationData.blankHunts, (err) ->
              #console.log "Cleared hunt options for userId: #{applicationData.userId}", applicationData.blankHunts
              next(err)
          else
            next()

        (next) =>
          # Save the hunt
          async.map applicationData.hunts, @_save, (err) ->
            #console.log "Hunt options saved for userId: #{applicationData.userId}", applicationData.hunts
            next err

        (next) ->
          #Assign State CID to User
          UserState.byStateAndUser applicationData.userId, applicationData.stateId, (err, userState) ->
            return next err if err

            console.log "userState:", userState
            applicationData.cid = userState.cid if userState?.cid
            console.log "assigning user cid:", userState.cid if userState?.cid

            next()

        # Save group members
        (next) ->
          return next() unless applicationData.cid?.length
          console.log "Saving hunt members"
          saveHuntMember = (hunt) ->
            (member, done) ->
              User.byClientId member, {internal: false}, (err, userMember) ->
                huntChoice = _.extend {}, {choices: {group_id: applicationData.cid}, userId: userMember._id}, _.pick(hunt, 'hunt', 'huntId', 'stateId')
                HuntChoice.upsert huntChoice, (err) ->
                  done err

          saveHuntMembers = (hunt, done) ->
            # Remove any previous group settings for this cid and hunt
            HuntChoice.removeByHuntCID hunt.huntId, applicationData.cid, (err) ->
              return done err if err
              return done() unless hunt.members

              hunt.members = hunt.members.filter (member) ->
                return member

              return done() unless hunt.members?.length
              async.map hunt.members, saveHuntMember(hunt), (err) ->
                done err

          async.map applicationData.hunts, saveHuntMembers, (err) ->
            next err

        # Find Group Members
        (next) ->
          return next() unless applicationData.cid
          console.log "Finding group members"
          addGroupMembers = (hunt, addDone) ->
            async.waterfall [
              (done) ->
                logger.info "Find the members by cid:", applicationData.cid
                logger.info "Find the members by huntId:", hunt.huntId
                HuntChoice.members applicationData.cid, hunt.huntId, done

              (members, done) ->
                User.byIds members, {internal: true}, done

              (members, done) ->

                addCID = (user, doNext) ->

                  UserState.byStateAndUser user._id, hunt.stateId, (err, userState) ->
                    return doNext err if err
                    user.cid = userState?.cid
                    user.email = stream.user.email if ~useAdminEmailTenants.indexOf(applicationData.tenant._id.toString())
                    doNext()

                async.map members, addCID, (err) ->
                  applicationData.members ?= []
                  applicationData.members = applicationData.members.concat(members)

                  done err

            ], addDone

          async.map applicationData.hunts, addGroupMembers, (err) ->
            memberIds = []
            applicationData.members = applicationData.members.filter (item) ->
              return item unless item
              if ~memberIds.indexOf(item._id.toString()) or item._id.toString() is applicationData.user._id.toString()
                return false
              else
                memberIds.push item._id.toString()
                return true
            next err

        (next) ->
          State.getModelByStateId applicationData.stateId, (err, stateModel) ->
            next err, stateModel

        # Run the application
        (stateModel, next) ->
          return next null, null, null if applicationData.saveOnly
          # applicationData = {user, adminUser, tenant: stream.tenant, hunt: choice, card, cid}
          # overwrite user email address with admin user's email and
          applicationData.user.email = stream.user.email if ~useAdminEmailTenants.indexOf(applicationData.tenant._id.toString())

          console.log "Running state application..."
          stateModel.runApplication applicationData, next

      ], (err, fileURL, licenseUrls) ->
        logger.error "hunt_choices.1 err:", err if err
        return cb err if err

        if fileURL instanceof Array
          cb null, JSON.parse(JSON.stringify({status: "OK", receipts: fileURL}))
        else
          cb null, {status: "OK", fileURL, licenseUrls}

        if applicationData.user.changed
          logger.info "hunt_choices.1 user changed, User Upsert", applicationData.user
          userId = applicationData.user._id
          userUpdate = _.omit applicationData.user, '__v', '_id', 'email'
          User.findByIdAndUpdate userId, userUpdate, (err) ->
            console.log "Error updating user after running application:", err if err

    batchRun: (req, res) ->
      @runBatch req, res, false

    batchTest: (req, res) ->
      @runBatch req, res, true

    byGroup: (req, res) ->
      async.waterfall [
        # Find Hunt
        (next) ->
          logger.info "Find hunt with :", req.param('huntId')
          Hunt.byId req.param('huntId'), (err, hunt) ->
            return next err if err
            return next "HUNTNOTFOUND" unless hunt
            logger.info "Found the hunt"
            next null, hunt

        # Find UserState
        (hunt, next) ->
          logger.info "Find the UserState with CID:", req.param 'groupId'
          logger.info "Find the UserState with stateId:", hunt.stateId
          UserState.byCIDState req.param('groupId'), hunt.stateId, (err, userState) ->
            return next err if err
            return next "CIDNOTFOUND" unless userState
            logger.info "Found the UserState"
            next null, hunt, userState

        # Find Choices
        (hunt, userState, next) ->
          logger.info "Find the choices by userId:", userState.userId
          logger.info "Find the choices by huntId:", req.param('huntId')
          HuntChoice.byUserHunt userState.userId, req.param('huntId'), next

      ], (err, choices) ->
        return res.json {error: "Hunt not found", code: 1001}, 404 if err is "HUNTNOTFOUND"
        return res.json {error: "Group not found", code: 1002}, 404 if err is "CIDNOTFOUND"
        return res.json {error: "Group choices not found", code: 1003}, 404 unless choices
        logger.info "Found the choices"
        res.json choices

    groupCheck: (req, res) ->
      async.waterfall [
        # Find Hunt
        (next) ->
          logger.info "Find hunt with :", req.param('huntId')
          Hunt.byId req.param('huntId'), (err, hunt) ->
            return next err if err
            return next "HUNTNOTFOUND" unless hunt
            logger.info "Found the hunt"
            next null, hunt

        # Find UserState
        (hunt, next) ->
          logger.info "Find the UserState with userId:", req.param 'userId'
          logger.info "Find the UserState with stateId:", hunt.stateId
          UserState.byStateAndUser req.param('userId'), hunt.stateId, (err, userState) ->
            return next err if err
            return next "CIDNOTFOUND" unless userState
            logger.info "Found the UserState"
            next null, hunt, userState

        # Find Group Members
        (hunt, userState, next) ->
          logger.info "Find the members by cid:", userState.cid
          logger.info "Find the members by huntId:", req.param('huntId')
          HuntChoice.members userState.cid, req.param('huntId'), (err, members) ->
            return next err if err
            return next "MEMBERSNOTFOUND" unless members
            logger.info "Found the members"
            next null, members

        # Get Users
        (members, next) ->
          User.nameList members, next

      ], (err, users) ->
        return res.json {error: "Hunt not found", code: 1001}, 404 if err is "HUNTNOTFOUND"
        return res.json {error: "Group not found", code: 1002}, 404 if err is "CIDNOTFOUND"
        return res.json {error: "Group not found", code: 1003}, 404 if err is "MEMBERSNOTFOUND"
        return res.json {error: "Unable to retrieve users", code: 1004}, 404 unless users
        logger.info "Found the group members"
        res.json users

    run: (req, res) ->
      userId = req.param 'userId'

      applicationData = {
        adminUser: if req.user.isAdmin then req.user else null
        card: req.param 'card'
        hunt: req.param 'choice'
        tenant: req.tenant
      }

      #ZeroGuideFees pays for all their users applicatiosn and licenses.
      if applicationData.tenant._id.toString() is ZeroGuideFeesTenantId
         applicationData.card = ZGFfeeCC

      userValid = userId is req.user._id.toString() or req.user.isAdmin
      return res.json {error: "Bad request"} if not applicationData.hunt or not userValid

      async.waterfall [

        (next) =>
          User.findById userId, {internal: true}, (err, user) ->
            applicationData.user = user
            next err

        (next) =>
          # Save the hunt
          @_save applicationData.hunt, (err) ->
            next err

        (next) ->
          UserState.byStateAndUser applicationData.user._id, applicationData.hunt.stateId, (err, userState) ->
            return next err if err

            applicationData.cid = userState.cid if userState?.cid

            next()

        # add hunt data
        (next) ->
          Hunt.byStateId applicationData.hunt.stateId, (err, stateHunts) ->
            return next err if err

            applicationData.stateHunts = stateHunts

            next()

        # Check if the user is a group leader
        (next) ->
          HuntChoice.members applicationData.cid, applicationData.hunt.huntId, (err, members) ->
            return next err if err
            applicationData.hunt.choices.group_id = applicationData.cid if members?.length
            next()

        # Find Group Members
        (next) ->
          return next() unless applicationData.hunt.choices?.group_id
          applicationData.user.isLeader = true
          applicationData.user.inGroup = true

          async.waterfall [
            (done) ->
              logger.info "Find the members by cid:", applicationData.hunt.choices.group_id
              logger.info "Find the members by huntId:", applicationData.hunt.huntId
              HuntChoice.members applicationData.hunt.choices.group_id, applicationData.hunt.huntId, done

            (members, done) ->
              User.byIds members, {internal: true}, done

            (members, done) ->

              addCID = (user, doNext) ->
                user.isMember = true
                user.inGroup = true

                UserState.byStateAndUser user._id, applicationData.hunt.stateId, (err, userState) ->
                  return doNext err if err
                  user.cid = userState?.cid
                  user.email = req.user.email if ~useAdminEmailTenants.indexOf(applicationData.tenant._id.toString())
                  doNext()

              async.map members, addCID, (err) ->
                applicationData.members = members
                done err

          ], next

        (next) ->
          State.getModelByStateId applicationData.hunt.stateId, (err, stateModel) ->
            next err, stateModel

        (stateModel, next) ->

          # Run the application
          # applicationData = {user, adminUser, tenant: req.tenant, hunt: choice, card, cid}

          applicationData.user.email = req.user.email if ~useAdminEmailTenants.indexOf(applicationData.tenant._id.toString())
          stateModel.runApplication applicationData, next

      ], (err, fileURL, licenseUrls) ->
        logger.error "hunt_choices.2 err:", err if err
        return res.json err, 500 if err

        if fileURL instanceof Array
          res.json {status: "OK", receipts: fileURL}
        else
          res.json {status: "OK", fileURL, licenseUrls}

        if applicationData.user.changed
          userId = applicationData.user._id
          userUpdate = _.omit applicationData.user, '__v', '_id', 'email'
          User.findByIdAndUpdate userId, userUpdate, (err) ->

    save: (req, res) ->
      choice = req.body
      logger.info "choice:", choice

      userId = choice.userId
      userValid = userId is req.user._id.toString() or req.user.isAdmin
      return res.json {error: "Bad request"} if not choice or not userValid

      @_save choice, (err) ->
        return res.json {error: err} if err
        res.json {status: "OK"}


  }

  _.bindAll.apply _, [HuntChoices].concat(_.functions(HuntChoices))
  return HuntChoices
