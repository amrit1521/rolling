_ = require "underscore"
async = require "async"
request = require "request"
moment    = require 'moment'


module.exports = (
  Application
  Hunt
  HuntinFoolClient
  HuntinFoolGroup
  HuntinFoolState
  HuntOption
  logger
  Point
  State
  User
  UserState
  HuntChoice
  MAX_APPLICATION_QUERYSIZE
  HuntinFoolTenantId
  Secure
) ->

  Searches = {

    addGroup: (users, groups) ->
      (user, cb) ->
        for group in groups
          if user.clientId in group.members
            foundMembers = false
            user.group = _.without group.members, user.clientId
            for member, index in user.group
              for candidate in users
                if member is candidate.clientId
                  foundMembers = true
                  user.group[index] = _.pick candidate, '_id', 'mail_city', 'clientId', 'dob', 'first_name', 'last_name', 'name', 'suffix'
                  break

            if foundMembers
              user.group = user.group.filter (member) ->
                return typeof member isnt 'string'

            if not foundMembers or not user.group?.length
              user.group = null

            break

        cb()

    addHuntsPointsReceipts: (hunts, pointsMap) ->
      stateId = hunts?[0]?.stateId
      (user, cb) ->
        return cb() if not user or not hunts?.length

        user.hunts = []
        async.parallel [

          (done) ->
            Point.byUserAndState user._id, stateId, done

          (done) ->
            Application.receiptsByUserState user._id, stateId, done

          (done) ->
            getHuntStatus = (hunt, next) ->
              Application.byUserHuntYear user._id, hunt._id, moment().year().toString(), (err, app) ->
                return next err if err
                return next null, null unless app
                huntStatus = {
                  huntId: hunt._id
                  status: app.status
                  transactionId: app.transactionId
                  cardTitle: app.cardTitle
                }
                return next err, huntStatus

            async.mapSeries hunts, getHuntStatus, (err, results) ->
              return done err if err
              huntStatusIndex = []
              for item in results
                if item?.huntId
                  huntStatusIndex[item.huntId] = item
              return done null, huntStatusIndex

          (done) ->
            getHuntChoice = (hunt, next) ->
              HuntChoice.byUserHunt user._id, hunt._id, (err, huntChoice) ->
                return next err, huntChoice

            async.mapSeries hunts, getHuntChoice, (err, results) ->
              return done err if err
              huntChoiceIndex = []
              for item in results
                if item?.huntId
                  huntChoice = _.pick item, 'choices'
                  keys = []
                  keys = Object.keys(huntChoice.choices) if huntChoice?.choices
                  for key in keys
                    huntChoice[key] = huntChoice.choices[key]
                  huntChoiceIndex[item.huntId] = huntChoice
              return done err, huntChoiceIndex


        ], (err, results) ->
          return cb err if err

          [points, applications, huntStatusIndex, huntChoiceIndex] = results
          points ?= []
          applications ?= []
          user.receipts = applications.filter (application) ->
            return !!application.receipt?.length or !!application.license?.length

          for huntObject in hunts
            continue if huntObject.match not in user.species
            #Special CA case so you include resident or non-resident hunts only seperately
            if huntObject.stateId?.toString() is "52aaa4cbe4e055bf33db64a2"
              isCA_Resident = false
              if user.residence
                isCA_Resident = true if user.residence is 'California'
              else if user.physical_state
                isCA_Resident = true if user.physical_state is 'California'
              else if user.mail_state
                isCA_Resident = true if user.mail_state is 'California'
              continue if huntObject.params?.resident isnt isCA_Resident

            hunt = _.pick huntObject, '_id', 'active', 'groupable', 'match', 'name', 'params', 'stateId'
            hunt.choice = huntChoiceIndex[hunt._id] if huntChoiceIndex[hunt._id]
            hunt.status = huntStatusIndex[hunt._id].status if huntStatusIndex[hunt._id]?.status
            hunt.transactionId = huntStatusIndex[hunt._id].transactionId if huntStatusIndex[hunt._id]?.transactionId
            hunt.cardTitle = huntStatusIndex[hunt._id].cardTitle if huntStatusIndex[hunt._id]?.cardTitle
            for point in points
              if pointsMap and pointsMap[point.name]
                point.name = pointsMap[point.name]
              continue unless point.name?.trim().toLowerCase() is hunt.match.toLowerCase()
              hunt.point = point
              break

            user.hunts.push hunt

          # x = y if user._id.toString() is '5339ba821530b4bc160002c6'
          cb()

    addUserHuntsAndPoints: (hunts, users, pointsMap, cb) ->
      if not cb and typeof pointsMap is 'function'
        cb = pointsMap
        pointsMap = null

      async.map users, @addHuntsPointsReceipts(hunts, pointsMap), (err) ->
        cb err, users

    getFilteredUsers: (req, results, stateResults, userStates, hunts, speciesMap, hfStateSpecies, cb) ->
      userIds = _.pluck results, 'userId'
      huntIds = _.pluck hunts, 'huntId'
      User.byIdsTenant userIds, req.tenant._id, {internal: true}, (err, users) ->
        return cb err if err
        console.log "users count before filtering:", users.length

        #apply filters
        filteredUsers = []
        async.waterfall [

          #Filter the user list by last name
          (done) ->
            console.log "Filtering by last name range:", req.params.range
            if req.params.range
              beginRange = req.params.range.toLowerCase().charCodeAt(0)
              endRange = req.params.range.toLowerCase().charCodeAt(req.params.range.length - 1)
            else
              beginRange = 'a'.charCodeAt(0)
              endRange = 'z'.charCodeAt(0)

            for user in users
              asciiCheck = user.last_name.toLowerCase().charCodeAt(0)
              if asciiCheck >= beginRange and asciiCheck <= endRange
                filteredUsers.push(user)
            users = filteredUsers
            console.log "users count after filting by last name #{req.params.range}:", users.length
            if users.length > MAX_APPLICATION_QUERYSIZE
              return done "This query for user applications is too large.  Please select additional filters and try again."
            done null, users


          #Filter HuntinFool Tenant users to this year only HuntinFoolState apps
          (users, done) ->
            return done null, users unless req.tenant._id?.toString() is HuntinFoolTenantId

            filteredUsers = []
            year = moment().year().toString()
            console.log "Filtering By Huntinfoolstates in the current year:", year
            for user in users
              for result in stateResults
                if user.clientId is result.client_id
                  if result.year is year and user.tenantId?.toString() is HuntinFoolTenantId
                    filteredUsers.push(user)
                  #else
                  #  console.log "FILTERED USER BY YEAR", user._id, user.name, result.year, result.client_id
            users = filteredUsers
            console.log "users count after filting by current year:", users.length
            return done null, users

          #Filter by status
          (users, done) ->
            if req.params.status isnt "all"
              console.log "Filtering by status:", req.params.status
              filteredUsers = []
              filterStatus = (user, done) ->
                huntLatestIndex = []
                huntLatestStatus = {}
                async.waterfall [
                  (next) ->
                    sort = { timestamp: -1 }
                    Application.byUsersHuntsYear [user._id], huntIds, moment().year().toString(), sort, (err, apps) ->
                      next err, apps
                  (apps, next) ->
                    includeUser = false
                    for app in apps
                      #console.log user.name, {status: app.status, huntIds: app.huntIds, timestamp: app.timestamp}
                      for huntId in app.huntIds
                        if not huntLatestStatus[huntId]
                          huntLatestStatus[huntId] = app.status
                          huntLatestIndex.push {huntId, status: app.status }
                    #console.log "HUNTID/STATUS", huntLatestStatus
                    for hsLatest in huntLatestIndex
                      #console.log "hsLatest", hsLatest, req.params.status is hsLatest.status
                      includeUser = true if req.params.status is hsLatest.status
                    #console.log user.name, includeUser
                    next null, includeUser
                ], (err, includeUser) ->
                  if includeUser
                    done err, user
                  else
                    done err, null

              async.mapSeries users, filterStatus, (err, results) ->
                console.log "error in filter by status:", err if err
                if not err
                  filteredUsers = []
                  for result in results
                    filteredUsers.push result if result
                  users = filteredUsers
                  console.log "users count after filting by status #{req.params.status}:", users.length
                done null, users
            else
              done null, users

          #Add user state application credentials
          (users, done) ->
            akStateId = "547fee39ac604956f8b14370"
            wyStateId = "52aaa4cbe4e055bf33db64a0"
            azStateId = "52aaa4cae4e055bf33db6499"
            utStateId = "52aaa4cbe4e055bf33db649f"
            nmStateId = "52aaa4cbe4e055bf33db649e"
            coStateId = "52aaa4cae4e055bf33db649a"
            nvStateId = "52aaa4cbe4e055bf33db649d"
            mtStateId = "52aaa4cbe4e055bf33db649c"
            idStateId = "52aaa4cbe4e055bf33db649b"
            orStateId = "52aaa4cbe4e055bf33db64a1"
            caStateId = "52aaa4cbe4e055bf33db64a2"
            waStateId = "52aaa4d2e4e055bf33db64a3"
            sdStateId = "548a11fb94a663719435738e"

            stateId = hunts[0].stateId if hunts.length
            return done null, users unless stateId
            stateId = stateId.toString()
            for user in users
              #Clear out unwanted fields
              c1 = if user.field8?.length then user.field8 else ''
              c2 = if user.field13?.length then user.field13 else ''
              user.postal2 = "#{c1} #{c2}"
              for key, value of user
                delete user[key] if key?.indexOf('field') > -1
              if user.ssn?.length > 4
                user.aid = user.ssn.substr(0,4)
                user.bid = user.ssn.substr(4)
              delete user.ssn

              switch stateId
                when azStateId
                  username = user.azUsername
                  password = user.azPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when coStateId
                  username = user.coUsername
                  password = user.coPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when idStateId
                  username = user.idUsername
                  password = user.idPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when mtStateId
                  username = user.mtUsername
                  password = user.mtPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when nmStateId
                  username = user.nmUsername
                  password = user.nmPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when nvStateId
                  username = user.nvUsername
                  password = user.nvPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when sdStateId
                  username = user.sdUsername
                  password = user.sdPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password
                when waStateId
                  username = user.waUsername
                  password = user.waPassword
                  user.stateUsername = username if username
                  if password
                    try
                      user.statePassword = Secure.decrypt password
                    catch err
                      user.statePassword = password


            return done null, users

        ], (err, users) ->
          return cb err if err
          hfAbrv = hfStateSpecies[0].split("_")[0]
          return cb "Error, failed to determine abbreviation to user for hunting state species and notes. hfStateSpecies:", hfStateSpecies unless hfAbrv
          for user in users
            for result in stateResults
              if user.clientId is result.client_id
                #Todo: HF is the only tenant with guarenteed HuntinfoolState having tenantId and year so can't filter by those for everyone yet with pulling initial applications from Mongo
                #console.log "UserState Year: #{result.year}, tenantId: #{user.tenantId}, userId: #{user._id}"
                #console.log "FOUND missing userstate tenantId:", result unless result.tenantId
                user.notes = if result["#{hfAbrv}_notes"] then result["#{hfAbrv}_notes"].trim() else ''
                species = []
                for hfs in hfStateSpecies
                  if result[hfs]
                    for animal in result[hfs].split("\n")
                      species.push speciesMap[animal.trim()] if speciesMap[animal.trim()]
                user.species = _.uniq species
                break

            for userState in userStates
              if userState.userId.toString() is user._id.toString()
                user.cid = userState.cid
                break

          console.log "Filtering by species list..."
          users = users.filter (user) ->
            return !!user.species?.length
          console.log "users count after filting by species:", users.length

          console.log "final user count", users.length
          cb null, users, hunts


    alaska: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Bison": "Bison"
          "Black Bear": "Black Bear"
          "Brown Bear": "Brown Bear"
          "Caribou": "Caribou"
          "Elk": "Elk"
          "Emperor Goose": "Emperor Goose"
          "Goat": "Goat"
          "Moose": "Moose"
          "Muskox": "Muskox"
          "Sheep": "Sheep"
        }


        pointsMap = {
          "Bison": "Bison"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'AK', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'ak', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["ak_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, pointsMap, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}



    arizona_antelope_elk: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Antelope"
          "Elk": "Elk"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'AZ', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'az', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["az_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    arizona_buffalo_deer_sheep: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Buffalo": "Buffalo"
          "Coues Deer": "Deer"
          "Deer": "Deer"
          "Mule Deer": "Deer"
          "Desert Sheep": "Sheep"
          "Rocky Mtn Sheep": "Sheep"
          "Sheep": "Sheep"
        }

        pointsMap = {
          "Bighorn Sheep": "Sheep"
          "Bison": "Buffalo"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'AZ', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'az', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["az_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, pointsMap, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    arizona_fall: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Buffalo": "FallBuffalo"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'AZ', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'az', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          userIds = _.pluck results, 'userId'
          User.byIdsTenant userIds, req.tenant._id, {internal: false}, (err, users) ->
            return next err if err

            for user in users
              for result in stateResults
                if user.clientId is result.client_id
                  user.notes = if result.az_notes then result.az_notes.replace(/\n+/g, ' ').trim() else ''
                  azSpecies = result.az_species.split("\n")

                  species = []

                  for animal in azSpecies
                    animal = animal.trim()

                    species.push speciesMap[animal] if speciesMap[animal]

                  user.species = _.uniq species
                  break

              for userState in userStates
                if userState.userId.toString() is user._id.toString()
                  user.cid = userState.cid
                  break

            users = users.filter (user) ->
              return !!user.species?.length

            next null, users

        (results, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups

        (results, groups, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, results

        (results, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    california: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Antelope"
          "Desert Sheep": "Sheep"
          "Mule Deer": "Deer"
          "RM Elk": "Elk"
          "Roosevelt Elk": "Elk"
          "Tule Elk": "Elk"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'CA', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'ca', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["ca_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}



    colorado: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Pronghorn"
          "Bear": "Bear"
          "Deer": "Deer"
          "Elk": "Elk"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'CO', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'co', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["co_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    find: (req, res) ->
      type = req.body.type
      logger.info "type:", type

      switch type
        when 'name'
          opts = {
            internal: false
          }
          opts.outfittersOnly = true if req?.body?.outfitters
          if req?.body?.parentId
            User.findByNameAndParent req.body.text, req.tenant._id, req.body.parentId, opts, (err, results) ->
              return res.json {error: err}, 500 if err
              res.json results
          else
            User.findByName req.body.text, req.tenant._id, opts, (err, results) ->
              return res.json {error: err}, 500 if err
              res.json results

    idaho: (speciesMap, huntNumber, req, res) ->
      stateId = null

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'ID', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'id', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["id_species_#{huntNumber}"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}



    idaho_goat_moose_sheep: (req, res) ->
      speciesMap = {
        "Goat": "Goat"
        "Moose": "Moose"
        "Sheep": "Sheep"
      }


      @idaho speciesMap, 1, req, res

    idaho_antelope_deer_elk: (req, res) ->
      speciesMap = {
        "Antelope": "Antelope"
        "Deer": "Deer"
        "Elk": "Elk"
        "Mule Deer": "Deer"
      }

      @idaho speciesMap, 3, req, res

    montana: (speciesMap, req, res) ->
      stateId = null

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'MT', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'mt', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["mt_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    montana_antelope_buffalo_goat_moose_sheep: (req, res) ->
      speciesMap = {
        "Antelope": "Antelope"
        "Buffalo": "Bison"
        "Bison": "Bison"
        "Goat": "Goat"
        "Moose": "Moose"
        "Sheep": "Sheep"
      }

      @montana speciesMap, req, res

    montana_deer_elk: (req, res) ->
      speciesMap = {
        "Deer": "Deer"
        "Elk": "Elk"
      }

      @montana speciesMap, req, res

    nevada: (req, res) ->
      stateId = null
      speciesMap = {
        "-Elk": "Antlered Elk"
        "Ante Silver State Tag": "Silver State Antelope"
        "Antelope": "Antelope Horns Longer"
        "CA Sheep": "California Bighorn"
        "Deer": "Antlered Mule Deer"
        "Deer Silver State Tag": "Silver State Deer"
        "Desert Sheep": "Nelson Bighorn"
        "Desert Silver State Tag": "Silver State Nelson BHS"
        "Elk": "Antlered Elk"
        "Elk Silver State Tag": "Silver State Elk"
        "Goat": "Mountain Goat"
        "Mule Deer": "Antlered Mule Deer"
        "RM Sheep": "NR California Bighorn"
      }

      pointsMap = {
        "Antlered Mule Deer ": "Antlered Mule Deer"
        "NR Antelope Horns Longer ": "Antelope Horns Longer"
        "NR Nelson Bighorn ": "Nelson Bighorn"
        "NR Antlered Elk ": "Antlered Elk"
        "NR California Bighorn ": "California Bighorn"
        "NR Rocky Mountain Bighorn ": "Rocky Mountain Bighorn"
        "NR Mountain Goat ": "Mountain Goat"
        "Antlered Mule Deer": "Antlered Mule Deer"
        "NR Nelson Bighorn": "Nelson Bighorn"
        "NR Antlered Elk": "Antlered Elk"
        "NR California Bighorn": "California Bighorn"
        "NR Rocky Mountain Bighorn": "Rocky Mountain Bighorn"
        "NR Antelope Horns Longer": "Antelope Horns Longer"
        "Res Nelson Bighorn": "Nelson Bighorn"
        "Res Antlered Elk": "Antlered Elk"
        "Res Mountain Goat": "Mountain Goat"
        "Res California Bighorn": "California Bighorn"
        "Res Rocky Mountain Bighorn": "Rocky Mountain Bighorn"
        "NR Mountain Goat": "Mountain Goat"
        "Res Antelope Horns Longer": "Antelope Horns Longer"
        "Res Black Bear": "Black Bear"
        "Res Elk Depredation": "Elk Depredation"
        "NR Black Bear": "Black Bear"
        "Res Antelope Horns Shorter": "Antelope Horns Shorter"
        "Res Wild Turkey": "Wild Turkey"
        "NR Antlerless Elk": "Antlerless Elk"
        "Res California Bighorn Ewe": "California Bighorn Ewe"
        "Res Antlerless Elk": "Antlerless Elk"
        "NR Wild Turkey": "Wild Turkey"
        "Res Junior Wild Turkey": "Junior Wild Turkey"
        "Res Antlerless Mule Deer Depredation": "Antlerless Mule Deer Depredation"
        "Res Junior Mule Deer": "Junior Mule Deer"
        "Res Antlerless Mule Deer": "Antlerless Mule Deer"
        "Res Nelson Bighorn Ewe": "Nelson Bighorn Ewe"
        "Res Elk Depredation Antlerless": "Elk Depredation Antlerless"
        "Res Spike Elk": "Spike Elk"
        "NR Nelson Bighorn Ewe": "Nelson Bighorn Ewe"
      }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'NV', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'nv', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["nv_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, pointsMap, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}


    new_mexico: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap =
          "Antelope":        "Antelope"
          "Deer":            "Deer"
          "Elk":             "Elk"
          "Ibex":            "Ibex"
          "Javelina":        "Javelina"
          "Oryx":            "Oryx"
          "Rocky Mtn Sheep": "Sheep"
          "Desert Sheep":    "Sheep"
          "Barbary Sheep":    "Barbary Sheep"

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'NM', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'nm', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["nm_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    oregon: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Antelope"
          "Blacktail Deer": "Deer"
          "California Sheep": "Sheep"
          "Columbian Whitetail": "Deer"
          "Deer": "Deer"
          "Elk": "Elk"
          "Goat": "Goat"
          "Mule Deer": "Deer"
          "Rocky Mtn Sheep": "Sheep"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'OR', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'ore', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["ore_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    search: (req, res, next) ->
      search = req.param 'search'
      return res.json {error: "Search not available"}, 404 unless @[search]
      @[search] req, res, next

    applicationByUserHuntYear: (req, res) ->
      userId = req.param 'userId'
      huntId = req.param 'huntId'
      year = req.param 'year'
      Application.byUserHuntYear userId, huntId, year, (err, app) ->
        return res.json {error: err}, 404 if err
        return res.json {error: "Application not found for userId: #{userId}, huntId: #{huntId}, year: #{year}"}, 404 unless app
        return res.json app


    south_dakota: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Pronghorn"
          "Deer": "Deer"
          "Elk": "Elk"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'SD', (err, state) ->
            stateId = state._id
            next err

        (next) ->
          HuntinFoolState.stateApplicants 'sd', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["sd_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    utah_spring: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Antelope"
          "Buffalo": "Buffalo"
          "Deer": "Deer"
          "Desert Sheep": "Desert Sheep"
          "Elk": "Elk"
          "Youth Elk": "Youth Elk"
          "General Deer": "General Deer"
          "Goat": "Goat"
          "Moose": "Moose"
          "Rocky Mtn Sheep": "Rocky Mtn Sheep"
        }

        pointsMap = {
          "TURKEY, BONUS POINT": "Turkey"
          "General Buck": "General Deer"
          "Elk Bull": "Elk"
          "Desert Bighorn Sheep":"Desert Sheep"
          "Rocky Mountain Bighorn Sheep":"Rocky Mtn Sheep"
          "Bison": "Buffalo"
          "Bull Moose": "Moose"
          "Buck Deer": "Deer"
          "Bear": "Bear"
          "Cougar": "Cougar"
          "Pronghorn Buck": "Antelope"
          "Rocky Mountain Goat": "Goat"
          "Mountain Goat": "Goat"
          "Bull Elk": "Elk"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'UT', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'ut', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["ut_species_1", "ut_species_2"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, pointsMap, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    washington: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Goat": "Goat"
          "Moose": "Moose"
          "Sheep": "Sheep"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'WA', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'wa', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          userIds = _.pluck results, 'userId'
          User.byIdsTenant userIds, req.tenant._id, {internal: false}, (err, users) ->
            return next err if err

            for user in users
              for result in stateResults
                if user.clientId is result.client_id
                  user.notes = if result.wa_notes then result.wa_notes.replace(/\n+/g, ' ').trim() else ''
                  species = []
                  for animal in result.wa_species.split("\n")
                    species.push speciesMap[animal.trim()] if speciesMap[animal.trim()]
                  user.species = _.uniq species
                  break

              for userState in userStates
                if userState.userId.toString() is user._id.toString()
                  user.cid = userState.cid
                  break

            users = users.filter (user) ->
              return !!user.species?.length

            next null, users

        (results, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups

        (results, groups, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, results

        (results, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    wyoming_antelope_deer: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Antelope"
          "Deer": "Deer"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'WY', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'wy', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["wy_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

    wyoming_elk_goat_moose_sheep: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Elk": "Elk"
          "Moose": "Moose"
          "Goat": "Mountain Goat"
          "Sheep": "Sheep"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'WY', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'wy', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["wy_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}


    wyoming_points: (req, res, speciesMap) ->
      stateId = null

      if typeof speciesMap is 'function'
        speciesMap = {
          "Antelope": "Antelope Points"
          "Deer": "Deer Points"
          "Elk": "Elk Points"
          "Moose": "Moose Points"
          "Sheep": "Sheep Points"
        }

      async.waterfall [

        (next) ->
          State.findByAbbreviation 'WY', (err, state) ->
            stateId = state._id
            next err

        # get client ids
        (next) ->
          HuntinFoolState.stateApplicants 'wy', next

        (stateResults, next) ->
          clientIds = _.pluck stateResults, 'client_id'
          HuntinFoolClient.byIds clientIds, (err, clients) ->
            next err, clients, stateResults

        (results, stateResults, next) ->
          userIds = _.pluck results, 'userId'
          UserState.byStateUsers stateId, userIds, (err, userStates) ->
            next err, results, stateResults, userStates

        (results, stateResults, userStates, next) ->
          Hunt.byStateId stateId, (err, hunts) ->
            next err, results, stateResults, userStates, hunts

        (results, stateResults, userStates, hunts, next) =>
          @getFilteredUsers req, results, stateResults, userStates, hunts, speciesMap, ["wy_species"], next

        (results, hunts, next) =>
          HuntinFoolGroup.index (err, groups) ->
            next err, results, groups, hunts

        (results, groups, hunts, next) =>
          async.map results, @addGroup(results, groups), (err) ->
            next err, hunts, results

        (hunts, results, next) =>
          @addUserHuntsAndPoints hunts, results, next

        (results, next) ->
          HuntOption.byStateId stateId, (err, options) ->
            next err, options, results

      ], (err, options, results) ->
        return res.json {error: err}, 500 if err
        res.json {users: results, options}

  }

  _.bindAll.apply _, [Searches].concat(_.functions(Searches))
  return Searches
