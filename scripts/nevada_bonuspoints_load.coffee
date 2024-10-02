$              = require "cheerio"
_              = require 'underscore'
async          = require "async"
config         = require '../config'
moment         = require 'moment'
request        = require 'request'
uuid           = require "uuid"


config.resolve (
  logger
  NavTools
  HuntinFoolLoadNoDOB
  HuntinFoolLoadNoDOBDrawResult
  User
  DrawResult
) ->

  #DRAWRESULT_STATUS = "Successful"
  #DRAWRESULT_STATUS = "Unsuccessful"
  DRAWRESULT_STATUS = "Bonus Point"
  URLPREFIX = "https://www.huntnevada.com/sci/draw/draw.aspx?draw=draw5&year=2017&page="

  if DRAWRESULT_STATUS is "Successful"
    STARTPAGE = 40000001
    ENDPAGE = 40000745
  else if DRAWRESULT_STATUS is "Unsuccessful"
    STARTPAGE = 50000001
    ENDPAGE = 50003907
  else if DRAWRESULT_STATUS is "Bonus Point"
    URLPREFIX = "#{URLPREFIX}B"
    STARTPAGE = "0000001"
    ENDPAGE = "0001197"
  else
    STARTPAGE = 0
    ENDPAGE = 0

  HF_TenantId = "52c5fa9d1a80b40fd43f2fdd"   #HuntinFool
  stateId = "52aaa4cbe4e055bf33db649d"    #Nevada

  totalHFNoDOBDraws = 0
  totalUserNVDraws = 0


  getDrawResults = (url, cb) ->
    console.log("")
    console.log "####################################################################################################"
    opts = {
      jar: request.jar()
    }

    plan = [
      # Get NV Page
      {
        label: "Get NV Draw Result Page"
        action: "link"
        url: url
        after: errorCheck(opts)
#        after: reportBody
      }
    ]

    NavTools.run opts, plan, (err, response, body) ->
      return cb err if err

      $body = $.load body

      matchedDrawResults = []
      drawResults = []


      $body('table').find('tr').each (rowIndex, row) ->
        return if rowIndex is 0

        $cells = $(row).find('td')

        drawResult = {
          userName: $cells.eq(0).text().trim()
          city: $cells.eq(1).text().trim()
          huntName: $cells.eq(2).text().trim()
          unit: $cells.eq(3).text().trim()
          status: DRAWRESULT_STATUS
          year: moment().year()
          stateId: stateId
        }
        drawResults.push drawResult

      #success: 40000408, unsuccess: 50000276, bonus:
      processResultForHFNoDOB = (drawResult, done) ->
        return done null #TODO: SKIPPING THIS FOR NOW
        fullNameFirstLastArray = drawResult.userName.split(",")
        fullNameFirstLast = fullNameFirstLastArray[1].trim()
        fullNameFirstLast = fullNameFirstLast + " " + fullNameFirstLastArray[0].trim() if fullNameFirstLastArray[1]

        #Check for match in HFNoDB collection and update it
        name = NavTools.parseName(fullNameFirstLast)
        console.log "ERROR: Could not compare names for NV draw result:", drawResult unless name
        return done() unless name

        console.log "HFNoDOB: comparing #{name.first_name} #{name.last_name}, NV draw result: #{drawResult.huntName}, #{drawResult.unit}"
        HuntinFoolLoadNoDOB.matchUser name.first_name, name.last_name, drawResult, (err, noDOBUser) ->
          console.log err if err
          return done err if err
          return done() unless noDOBUser

          console.log "MATCH FOUND! HFNoDOB: #{noDOBUser.first_name} #{noDOBUser.last_name}, #{noDOBUser.memberId}"
          console.log "NV Draw Result:", drawResult

          data = {
            memberId: noDOBUser.memberId
            hfLoadNoDOBId: noDOBUser._id
            first_name: noDOBUser.first_name
            last_name: noDOBUser.last_name
            mail_address: noDOBUser.mail_address
            mail_city: noDOBUser.mail_city
            mail_state: noDOBUser.mail_state
            mail_postal: noDOBUser.mail_postal
            userName: drawResult.userName
            city: drawResult.city
            huntName: drawResult.huntName
            unit: drawResult.unit
            status: drawResult.status
            year: drawResult.year
            stateId: drawResult.stateId
            tenantId: HF_TenantId
          }
          HuntinFoolLoadNoDOBDrawResult.upsert data, (err, hfNoDBDrawResult) =>
            console.log err if err
            return done err if err
            return done() unless hfNoDBDrawResult

            #console.log "Updated hfNoDBDrawResult:", hfNoDBDrawResult
            totalHFNoDOBDraws++
            done null, drawResult



      processResult = (drawResult, done) ->
        fullNameFirstLastArray = drawResult.userName.split(",")
        fullNameFirstLast = fullNameFirstLastArray[1].trim()
        fullNameFirstLast = fullNameFirstLast + " " + fullNameFirstLastArray[0].trim() if fullNameFirstLastArray[1]

        #Check for multiple matches in User collection by first_name, last_name, mail_city or physicial_city
        name = NavTools.parseName(fullNameFirstLast)
        console.log "ERROR: Could not compare user names for NV draw result:", drawResult unless name
        return done() unless name
        return done() unless name.first_name
        return done() unless name.last_name
        return done() unless drawResult.city

        console.log "Users: comparing #{name.first_name} #{name.last_name}, NV draw result: #{drawResult.huntName}, #{drawResult.unit}"
        User.matchNVUser name.first_name, name.last_name, drawResult.city, (err, users) ->
          console.log err if err
          return done err if err
          return done() unless users

          updateDrawResults = (user, complete) ->
            console.log "MATCH FOUND! User: _id: #{user._id}, first_name: #{user.first_name}, last_name: #{user.last_name}, mail_city: #{user.mail_city}, physical_city: #{user.physical_city}, tenantId: #{user.tenantId}, clientId: #{user.clientId}, name: #{user.name}"
            drawResult.tenantId = user.tenantId
            console.log "NV Draw Result:", drawResult

            data = {
              name: drawResult.huntName
              unit: drawResult.unit
              status: drawResult.status
              year: drawResult.year
              stateId: drawResult.stateId
              userId: user._id
              tenantId: user.tenantId
            }

            DrawResult.upsert data, (err, drawresultRsp) =>
              console.log err if err
              return done err if err
              return done() unless drawresultRsp

              console.log "Updated DrawResults:", drawresultRsp
              totalUserNVDraws++
              complete null, drawResult

          async.mapSeries users, updateDrawResults, (err, results) ->
            console.error "ERROR:", err if err
            done err if err
            sumResults = []
            for result in results
              sumResults.push result if result
            done null, sumResults

      #Run NV results against HFNoDOB
      async.mapSeries drawResults, processResultForHFNoDOB, (err, results) ->
        console.error "ERROR:", err if err
        drawResultsHFNoDOB = []
        for result in results
          drawResultsHFNoDOB.push result if result

        #Run NV results against Normal Users
        async.mapSeries drawResults, processResult, (err, results) ->
          console.error "ERROR:", err if err
          drawResults = []
          for result in results
            drawResults.push result if result

          cb null, [drawResultsHFNoDOB, drawResults]


  errorCheck = (opts, localIgnores) ->
    (err, response, body, cb) ->
#      console.log "errorCheck body:", body
      return cb null, response, body if err is 'SKIP'
      return cb err if err
      return cb err, response, body unless body

      if ~body.search /error_msg/
        $body = $.load body

        ignoreMessages = [
          "All Postal and Temporary fulfillment documents will be sent to your mailing address defined in 'Your Profile'"
          "Before applying for a controlled hunt, you must have a valid hunting, combination, or SportsPac license."
          "Please wait while your request is processed. Any action may result in an incomplete transaction."
          "There are no items under this tab for you to purchase. Please select another tab."
          "Verify your mailing address. An incorrect mailing address may result in a duplicate charge."
        ]

        messages = []
        $body('.error_msg').each (index, element) ->
          message = $(element).text().replace(/\s+/g, ' ').trim()

          return if message in ignoreMessages or not message.length
          if localIgnores and localIgnores instanceof Array
            return if message in localIgnores

          messages.push message

        if messages.length
          logger.error "messages:", messages
          console.log "Error Body lastBody:", opts.lastBody if opts.lastBody
          console.log "Error Body:", body
          logger.error "Error Url:", opts.lastURL
          return cb {error: messages.join("\n\n"), code: 1007}

      opts.lastBody = body
      cb err, response, body


  reportBody = (err, response, body, cb) ->
    console.log "reportBody err:", err if err
    console.log "body:", body
    x = y

  opts = ""
  urls = []
  pageNum = STARTPAGE
  while pageNum <= ENDPAGE
    urls.push("#{URLPREFIX}#{pageNum}")
    pageNum++

  console.log "URL LIST:", urls.length

  #types = Object.keys urls

  async.mapSeries urls, getDrawResults, (err, results) ->
    totalDraws = 0
    console.error "ERROR:", err if err
    #console.log "results:", results.length
    for result in results
      #console.log "results:", result.length
      totalDraws = totalDraws + result.length
    #console.log "TOTAL DRAWS:", totalDraws
    console.log "TOTAL HFNoDOB Draws:", totalHFNoDOBDraws
    console.log "TOTAL User NV Draws:", totalUserNVDraws
    process.exit(0)
