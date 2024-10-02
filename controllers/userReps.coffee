_ = require "underscore"
async = require "async"
moment = require "moment"

module.exports = (UserRep, User, TENANT_IDS) ->

  UserReps = {

    get_user_reps: (userId, cb) ->
      UserRep.byRepId userId, (err, userReps) ->
        return cb err, 500 if err
        return cb null, userReps


    update_user_reps: (userId, cb) ->
      async.waterfall [
        #First get the user for the given userId
        (next) ->
          User.byId userId, {}, (err, user) =>
            return next err if err
            return next "Failed to find user for userId: ", userId unless user
            return next null, user

        #Now check if this user has a parent.  If it does not, assign it to the default parent account
        (user, next) ->
          if user.parentId and user.parentId?.toString() isnt user._id.toString()
            return next null, user
          else
            console.log "NOTICE: User encountered without assigned parent. Assigning to default parent id now."
            console.log "User: ", user._id, user.clientId, user.name
            if user.tenantId.toString() is TENANT_IDS.RollingBones
              defaultParentId = "570419ee2ef94ac9688392b0" #Hard coded to Brian and Lynley Mehmen for now.
            else if user.tenantId.toString() is TENANT_IDS.RollingBonesTest
              defaultParentId = "5bd7607b02c467db3f70eda2" #Hard coded to top admin user
            else
              return next "update_user_reps() attempted to run on a non RBO tenant which is not allowed."
            userData = {
                _id: user._id
                parentId: defaultParentId
            }
            console.log "DEBUG: Updating User model, User.upsert userData: ", userData
            #return next null, user #DON"T UPDATE USER
            User.upsert userData, {upsert: false, multi: false}, (err, user) ->
              return next err, user

        #Now calculate the user's rep chain, and update UserRep
        (user, next) =>
          UserRep.byUserId userId, (err, userRepObj) =>
            return next err if err
            if !userRepObj
              userRepObj = {
                userId: userId
                tenantId: user.tenantId
              }
            results = {} #Does this need to be userRepObj and pass through? or is it fine outside the waterfall scope?
            async.waterfall [
              (next) =>
                repField = "rbo_rep0"
                #repTypeMatch = "Associate Adventure Advisor,Adventure Advisor,Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "Affiliate Partner,Adventure Specialist,District Sales Manager,Division Sales Manager,Regional Sales Manager,Assistant Agency Manager,Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep1"
                #repTypeMatch = "Adventure Advisor,Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "Adventure Specialist,District Sales Manager,Division Sales Manager,Regional Sales Manager,Assistant Agency Manager,Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep2"
                #repTypeMatch = "Senior Adventure Advisor,Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "District Sales Manager,Division Sales Manager,Regional Sales Manager,Assistant Agency Manager,Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep3"
                #repTypeMatch = "Regional Adventure Advisor,Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "Division Sales Manager,Regional Sales Manager,Assistant Agency Manager,Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep4"
                #repTypeMatch = "Agency Manager,Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "Regional Sales Manager,Assistant Agency Manager,Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep5"
                #repTypeMatch = "Senior Agency Manager,Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "Assistant Agency Manager,Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep6"
                #repTypeMatch = "Executive Agency Manager,Senior Executive Agency Manager"
                repTypeMatch = "Agency Manager,Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

              (results, next) =>
                repField = "rbo_rep7"
                #repTypeMatch = "Senior Executive Agency Manager"
                repTypeMatch = "Executive Agency Manager"
                safteyCheck = 0
                @getParentRep user, repField, repTypeMatch, safteyCheck, (err, rep) =>
                  return next err if err
                  userRepObj[repField] = rep._id
                  return next null, results

            ], (err, results) ->
              return next err if err
              #console.log "DEBUG: About to upsert UserRep entry with: ", userRepObj
              UserRep.upsert userRepObj, (err, userRep) ->
                return next err, userRep
      ], (err, userRep) ->
        return cb err, userRep

    getParentRep: (tUser, repField, repTypeMatch, safteyCheck, cb) ->
      #console.log "DEBUG: safteyCheck: #{safteyCheck}, repField: #{repField}, tUser.name: #{tUser.name}, tUser.repType: #{tUser.repType},"
      repTypeMatchArray = repTypeMatch.split(",")
      for rType in repTypeMatchArray
        rType = rType.trim()
      repFound = null
      if safteyCheck > 10000
        console.log "getParentRep: reached safteyCheck recursion limit!"
        return cb "Error: getParentRep: reached safteyCheck recursion limit!"

      if tUser._id.toString() is "5bd7607b02c467db3f70eda2" or tUser._id.toString() is "570419ee2ef94ac9688392b0"
          #Root user special case
          repFound = tUser
          return cb null, repFound
      else if tUser.isRep and repTypeMatchArray.indexOf(tUser.repType) > -1
        #console.log "DEBUG: FOUND MATCH, returning this user as the rep. Rep Name: #{tUser.name}, Rep Type: #{tUser.repType}"
        #console.log ""
        #console.log ""
        repFound = tUser
        return cb null, repFound
      else
        if !tUser.parentId or tUser.parentId?.toString() is tUser._id?.toString()
          errMsg = "getParentRep: reached end of parent chain without finding #{repField}, tUser: #{tUser._id}, #{tUser.name}"
          console.log errMsg
          return cb errMsg
        else
          User.findById tUser.parentId, {internal: false}, (err, parent) =>
            return cb err if err
            return cb "Error: getParentRep cannot find user for userId: #{tUser._id}, parentId: #{tUser.parentId}" unless parent
            safteyCheck++
            @getParentRep parent, repField, repTypeMatch, safteyCheck, cb
            return



  }
  _.bindAll.apply _, [UserReps].concat(_.functions(UserReps))
  return UserReps
