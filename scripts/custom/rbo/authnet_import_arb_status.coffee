_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'
AuthorizeNet  = require 'authorizenet'
AuthContracts = AuthorizeNet.APIContracts
AuthControllers = AuthorizeNet.APIControllers
AuthConstants = AuthorizeNet.Constants

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/authnet_import_arb_status.coffee

UPDATE_USER = true


config.resolve (
  logger
  Secure
  User
  CreditCardClients

) ->

  arbTotal = 0
  arbCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  #RBO AUTHORIZE.NET ACCOUNT
  ccClient = CreditCardClients.ccc_rbo
  SORT = AuthContracts.ARBGetSubscriptionListOrderFieldEnum.CREATETIMESTAMPUTC
  LIMIT = 1000 #up to 1000 at a time
  SEARCH_TYPE = null


  handleResponse = (response, done) ->
    #console.log "AUTH RESP :", JSON.stringify(response, null, 2)
    totalNumInResultSet = -1

    if response?.getMessages()
      if response.getMessages().getResultCode() is AuthContracts.MessageTypeEnum.OK
        console.log "ARB Listing Request was successful: "
        console.log 'Message Code : ' + response.getMessages().getMessage()[0].getCode()
        console.log 'Message Text : ' + response.getMessages().getMessage()[0].getText()
        subscriptions = response.getSubscriptionDetails().getSubscriptionDetail()
        totalNumInResultSet = response.totalNumInResultSet
        return done null, totalNumInResultSet, subscriptions
      else
        rCode = response.getMessages().getResultCode() if response.getMessages().getResultCode()
        mCode = response.getMessages().getMessage()[0].getCode() if response.getMessages().getMessage()?[0]?.getCode()
        mText = response.getMessages().getMessage()[0].getText() if response.getMessages().getMessage()?[0]?.getText()
        console.log 'Result Code: ' + rCode
        console.log 'Error Code: ' + mCode
        console.log 'Error message: ' + mText
        return done "ARB Listing Request failed with error: " + mText
    else
      err = "Authorize.net ARB Subscription List API returned an empty or bad response."
      console.log err
      return done err

  getAuthNetARBResultSet = (offset, cb) ->
    console.log "Getting Authorize.net ARB subscriptions result set for offset ", offset
    refId = Math.random().toString(36).substr(20) #From Auth Documentation: "If included in the request, this value is included in the response."
    sorting = new AuthContracts.ARBGetSubscriptionListSorting()
    sorting.setOrderDescending(true);
    sorting.setOrderBy(SORT);
    paging = new AuthContracts.Paging()
    paging.setOffset(offset)
    paging.setLimit(LIMIT)
    listRequest = new AuthContracts.ARBGetSubscriptionListRequest()
    listRequest.setMerchantAuthentication(ccClient)
    listRequest.setRefId(refId)
    listRequest.setSearchType(SEARCH_TYPE)
    listRequest.setSorting(sorting)
    listRequest.setPaging(paging)
    #console.log "AUTH REQ: ", JSON.stringify(listRequest.getJSON(), null, 2)

    ctrl = new AuthControllers.ARBGetSubscriptionListController(listRequest.getJSON())
    ctrl.setEnvironment(AuthConstants.endpoint.production) if CreditCardClients.ProductionEnviroment
    console.log "CreditCardClients.ProductionEnviroment: ", CreditCardClients.ProductionEnviroment
    ctrl.execute ()->
      apiResponse = ctrl.getResponse()
      abrListResponse = new AuthContracts.ARBGetSubscriptionListResponse(apiResponse)
      #console.log "AUTH RESP :", JSON.stringify(abrListResponse, null, 2)
      handleResponse abrListResponse, (err, totalNumInResultSet, subscriptions) ->
        return cb err, totalNumInResultSet, subscriptions

  processUser = (user, done) ->
    #return next null  #Skip processing this user
    userCount++
    #return done null unless userCount < 10
    User.byId user._id, {internal: true}, (err, user) ->
      console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"
      if skipList.indexOf(user._id) > -1
        console.log "SKIPPING USER!"
        return done null
      else
        console.log "#{user.memberStarted.getTime() is user.memberExpires.getTime()}    #{user.memberStarted}     ->     #{user.memberExpires}"
        return done null unless user.memberStarted and user.memberExpires

        if user.memberStarted.getTime() is user.memberExpires.getTime()
          #console.log "FOUND A MATCH, UPDATE EXPIRED OUT A YEAR: "

          #userInfo = _.pick(user, "_id", "clientId", "name", "memberStarted", "memberExpires")
          #userInfo.created = created
          #console.log userInfo

          newExpireDate = moment(user.memberExpires)
          newExpireDate = newExpireDate.add(1,'years').format('YYYY-MM-DD')

          if UPDATE_USER and user._id and user.memberExpires
            userData = { _id: user._id, memberExpires: newExpireDate}
            console.log "About to update user with data: ", userData
            #User.upsert userData, (err, updatedUser) ->
            #  console.log("User updated successfully! ", updatedUser);
            #  return done err, updatedUser
            return done err, userData
          else
            return done null
        else
          console.log "Memberships is good until #{user.memberExpires}"
          return done null



  getUsers = (cb) ->
    ###
    c_and = { $and: [
      {first_name: tran.first_name}
      {last_name: tran.last_name}
    ]
    }
    c_or = []
    c_or.push {email: tran.email} if tran.email
    c_or.push {phone_cell: tran.phone} if tran.phone
    c_or.push {phone_home: tran.phone} if tran.phone
    c_or.push {physical_address: tran.address1} if tran.address1
    c_or.push {mail_address: tran.address1} if tran.address1
    c_or.push {memberId: tran.memberId} if tran.memberId
    c_or.push c_and
    conditions = {
      $and: [
        { $or: c_or },
        { tenantId: "5684a2fc68e9aa863e7bf182"},
      ]
    }
    ###

    conditions = {
      isMember: true
    }
    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results
    #HuntinFoolState.find({tenantId: "5684a2fc68e9aa863e7bf182", mt_check: "True"}).lean().exec (err, results) ->
    #  users = []
    #  for result in results
    #    users.push {_id: result.userId}
    #  cb err, users



  getARBResultSetByType = (type, cb) ->
    async.waterfall [

      # Get total number of items in the results set from authorize.net
      (next) ->
        offset = 1
        getAuthNetARBResultSet offset, (err, totalNumInResultSet, subscriptions) ->
          return next err, totalNumInResultSet

      # Get List of All Authorize.net ARB Subscriptions
      (totalNumInResultSet, next) ->

        getARBResultSet = (offset, done) ->
          getAuthNetARBResultSet offset, (err, totalNumInResultSet, subscriptions) ->
            return done err, subscriptions

        tmpArray = []
        numPages = parseInt(((totalNumInResultSet / LIMIT) + 1).toFixed(0))
        for i in [1...numPages+1] by 1
          tmpArray.push i

        async.mapSeries tmpArray, getARBResultSet, (err, results) ->
          subscriptions = []
          for result in results
            for sub in result
              subscriptions.push sub
          return next err, subscriptions

    ], (err, subscriptions) ->
      console.log "Finished retrieving #{type} ARB subscriptions.  Found: #{subscriptions.length}"
      return cb err, subscriptions



  #*************START HERE****************
  async.waterfall [

    # Get authorize.net ACTIVE automatic recurring billing subscriptions:
    (next) ->
      SEARCH_TYPE = AuthContracts.ARBGetSubscriptionListSearchTypeEnum.SUBSCRIPTIONACTIVE
      getARBResultSetByType SEARCH_TYPE, (err, subscriptions_active) ->
        return next err, subscriptions_active

    # Get authorize.net INACTIVE automatic recurring billing subscriptions:
    (subscriptions_active, next) ->
      SEARCH_TYPE = AuthContracts.ARBGetSubscriptionListSearchTypeEnum.SUBSCRIPTIONINACTIVE
      getARBResultSetByType SEARCH_TYPE, (err, subscriptions_notactive) ->
        return next err, subscriptions_active, subscriptions_notactive

    # Get authorize.net INACTIVE automatic recurring billing subscriptions:
    (subscriptions_active, subscriptions_notactive, next) ->
      SEARCH_TYPE = AuthContracts.ARBGetSubscriptionListSearchTypeEnum.CARDEXPIRINGTHISMONTH
      getARBResultSetByType SEARCH_TYPE, (err, subscriptions_cardexpiring) ->
        return next err, subscriptions_active, subscriptions_notactive, subscriptions_cardexpiring

  ], (err, subscriptions_active, subscriptions_notactive, subscriptions_cardexpiring) ->
    console.log "Finished"
    console.log "Num subscriptions_active: ", subscriptions_active.length, subscriptions_active
    console.log "Num subscriptions_notactive: ", subscriptions_notactive.length, subscriptions_notactive
    console.log "Num subscriptions_cardexpiring: ", subscriptions_cardexpiring.length, subscriptions_cardexpiring
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
