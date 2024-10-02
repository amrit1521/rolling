_ = require "underscore"
async = require "async"
util = require "util"

module.exports = (
  User
  Hunt
  HuntOption
  HuntinFoolState
  Point
  State
  logger
) ->

  Hunts = {

    adminAllApplications: (req, res) ->
      cb = res if !res.json?

      if cb
        return cb {error: 'Tenant id required'} unless req?.tenant?._id
      else
        return res.json {error: "Unauthorized"}, 401 unless req.user.isAdmin
        return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id


      tenantId = req.tenant._id

      async.waterfall [

        #Get all applications
        (next) =>
          HuntinFoolState.byTenantId tenantId, (err, apps) ->
            return next err, apps

        #Get Users who have checked apply for me and authorized power of attorney
        (apps, next) =>
          app_user_id_list = {}
          for app in apps
            app_user_id_list[app.userId] = app.userId if app.userId
          app_user_id_list = _.toArray(app_user_id_list)
          chunkSize = 2000
          allChunks = _.groupBy app_user_id_list, (element, index) ->
            return Math.floor(index/chunkSize)
          allChunks = _.toArray(allChunks)

          getUsers = (chunckIdList, done) ->
            User.byIds chunckIdList, {}, (err, users) ->
              return done err, users

          users = []
          async.mapSeries allChunks, getUsers, (err, group_of_users) =>
            console.log err if err
            return next err if err
            for group in group_of_users
              for tUser in group
                users.push tUser
            return next err, users, apps

        #Add user info to apps objects
        (users, apps, next) =>
          results = []
          for user in users
            foundApp = false
            for app in apps
              if user._id.toString() is app.userId.toString()
                #console.log "DUPLICATE HFSTATE ENTRIES FOR clientId: ", user.clientId, app.client_id if foundApp
                userApp = {}
                #_.extend userApp, user
                userApp = _.pick user, "name", "clientId", "first_name", "last_name", "dob", "email", "phone_cell","powerOfAttorney", "memberStatus", "memberType", "memberExpires", "isMember", "isRep"
                _.extend userApp, app
                results.push userApp
                foundApp = true
                #break
            if !foundApp
              user.AppNotFound = true
              results.push user

          next null, results, users, apps

        #CHECK FOR HFS discrepancies with User
        (results, users, apps, next) =>
          #return next null, results
          indexedUsers = {}
          for user in users
            indexedUsers[user._id.toString()] = user
          for app in apps
            userId = app.userId.toString()
            if !indexedUsers[userId]
              userApp = {missingUser: true, userId: userId, clientId: app.client_id}
              hfs_keys = Object.keys(app)
              for key in hfs_keys
                if key.indexOf("check") > -1 and app[key] is "True"
                  console.log "User application request without POA found for UserId: ", userId, app.client_id
                  userApp.missingPowerOfAttorney = true
                  break
              _.extend userApp, app
              results.push userApp

          return next null, results

        #Add user data for any apps that didn't have power of attorney yet.  (This is a little faster than getting all users up front)
        (results, next) ->
          addUser = (app, done) ->
              return done null, app unless app.missingUser and app.userId
              User.byId app.userId, {}, (err, tUser) ->
                if err
                  console.log "Error1: Unable to retrieve user for missing POA userId #{app.userId}: ", app
                  return done null, app
                else if !tUser
                  console.log "Error2: Unable to retrieve user for missing POA userId #{app.userId}: ", app unless tUser or app.year is '2018'
                  return done null, app
                else
                  userAppInfo = _.pick tUser, "name", "clientId", "first_name", "last_name", "dob", "email", "powerOfAttorney", "memberStatus", "memberExpires", "isMember", "isRep"
                  _.extend app, userAppInfo
                  return done null, app

          async.mapSeries results, addUser, (err, apps) ->
            return next err, apps

        #Clean-up the data
        (results, next) ->
          for item in results
            keys = Object.keys(item)
            for key in keys
              #if key.indexOf("species") > -1
              #  value = item[key]
              #  item[key] = value.replace(/\n/g, ", ") if typeof value is "string" and value?.length
              if key.indexOf("picked") > -1
                picked = item[key]
                pickedStr = ""
                i = 0
                for pick in picked
                  if i == 0
                    pickedStr = pick
                  else
                    pickedStr = "#{pickedStr},  #{pick}"
                  i++
                picked_key = key.replace("_picked", "")
                item[picked_key] = pickedStr

          return next null, results


      ], (err, results) ->
        if cb
          return cb err if err
          return cb null, results
        else
          return res.json err, 500 if err
          res.json results


    adminIndex: (req, res) ->
      Hunt.byStateId req.params.stateId,  (err, hunts) ->
        return res.json err, 500 if err
        res.json hunts

    adminRead: (req, res) ->
      Hunt.byId req.params.id, (err, hunt) ->
        return res.json err, 500 if err
        res.json hunt

    available: (req, res) ->
      State.byId req.params.stateId, (err, state) ->
        return res.json err, 500 if err

        try
          logger.info "State name:", state.name
          model = eval(state.name)
        catch error
          return res.json error, 500

        if model?.availableHunts?
          logger.info "Found availableHunts"
          model.availableHunts req.user, (err, hunts) ->
            return res.json err, 500 if err
            res.json hunts
        else
          res.json []

    byState: (req, res) ->
      Hunt.byStateId req.params.stateId, (err, hunts) ->
        return res.json err, 500 if err
        res.json hunts

    create: (req, res) ->
      hunt = new Hunt req.body
      hunt.save (err, hunt) ->
        if err
          logger.info "Failed to create new hunt:", err
          return res.json({error: err}, 500)

        return res.json({error: "Failed to create new hunt"}, 500) unless hunt

        res.json hunt

    currentByState: (req, res) ->
      State.byId req.params.stateId, (err, state) =>
        return res.json err, 500 if err

        @saveHuntOptions req.user, state._id, (err, hunts) ->
          return res.json err, 500 if err
          res.json hunts
#
#        try
#          model = eval(state.name)
#        catch error
#          return res.json error, 500
#        model.currentHunts req.user, (err, hunts) ->
#          return res.json err, 500 if err
#          res.json hunts

    saveHuntOptions: (user, stateId, done) ->
      save = (huntData, options, cb) ->
        logger.info "call the save callback with options:", arguments
        Hunt.byStateIdAndMatch stateId, huntData.name, (err, hunt) ->
          return done err if err
          logger.info "hunt:", hunt
          logger.info "match:", huntData.name
          logger.info "stateId:", stateId

          huntOption = new HuntOption({
            huntId: hunt._id
            stateId
            active: hunt.active
            data: util.inspect({
              huntData: huntData
              options
            }, {depth: null})
          })

          huntOption.save (err) ->
            cb err

      Wyoming.allHuntOptions user, save, done

    get: (req, res) ->
      Hunt.byId req.params.id, (err, hunt) ->
        return res.json err, 500 if err
        res.json hunt

    options: (req, res) ->
      Hunt.byId req.params.id, (err, hunt) ->
        return res.json err, 500 if err

        State.byId hunt.stateId, (err, state) ->
          return res.json err, 500 if err

          try
            model = eval(state.name)
          catch error
            return res.json error, 500

          model.huntOptions req.user, hunt, (err, options) ->
            return res.json err, 500 if err
            res.json options

    update: (req, res) ->
      return res.json {error: 'Hunt id required'}, 400 unless req?.body?._id

      huntId = req.body._id
      delete req.body._id

      Hunt.findOne {_id: huntId}, (err, hunt) ->
        return res.json {error: err}, 500 if err

        for index, value of req.body
          hunt.set index, value

        logger.info "save hunt:", hunt.toJSON()
        hunt.save (err) ->
          return res.json {error: err}, 500 if err
          res.json hunt.toJSON()

  }

  _.bindAll.apply _, [Hunts].concat(_.functions(Hunts))
  return Hunts


