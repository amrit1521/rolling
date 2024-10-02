$              = require "cheerio"
_              = require 'underscore'
async          = require "async"
config         = require './config'
moment         = require 'moment'
request        = require 'request'
uuid           = require "uuid"


stateId = "52aaa4cbe4e055bf33db64a2"
huntInserts = []
optionInserts = []

config.resolve (
  logger
  NavTools
) ->

  addLicense = (opts, user, oRes, oBody, cb) ->
    plan = [
      # California purchase licenses
      {
        label: "California purchase licenses"
        action: "link"
        url: "https://www.ca.wildlifelicense.com/InternetSales/Sales/ItemSelection"
        after: errorCheck(opts)
#        after: reportBody
      }

      # California hunts page
      {
        label: "California hunts page"
        action: "link"
        url: "https://www.ca.wildlifelicense.com/InternetSales/Sales/ChangeTabs/1"
        after: errorCheck(opts)
#        after: reportBody
      }

      # California add license to cart
      {
        label: "California add license to cart"
        action: "link"
#        url: "https://www.ca.wildlifelicense.com/InternetSales/Sales/SelectItem?itemID=6940"
        before: (response, body, done) ->
          console.log "called before"

          itemId = if user.residence is 'California' then "8169" else "8194"
          url = "https://www.ca.wildlifelicense.com/InternetSales/Sales/SelectItem?itemID=#{itemId}"
          done null, {url}

        after: errorCheck(opts)
#        after: reportBody
      }
    ]

    NavTools.run opts, plan, oRes, oBody, cb

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

  login = (opts, user, cb) ->

    plan = [
      # California home page
      {
        label: "California home page"
        action: "link"
        url: "http://www.dfg.ca.gov/licensing/ols/"
        after: errorCheck(opts)
#        after: reportBody
      }

      # California login start page
      {
        label: "California login start page"
        action: "link"
        url: "https://www.ca.wildlifelicense.com/InternetSales/"
        after: errorCheck(opts)
#        after: reportBody
      }

      # California login page
      {
        label: "California login page"
        action: "link"
        url: "https://www.ca.wildlifelicense.com/InternetSales/Customer/Options"
        after: errorCheck(opts)
#        after: reportBody
      }

      # California login form 1
      {
        label: "California login form 1"
        action: "form"
        useBody: true
        fields: ["DateOfBirth", "LastName", "Next"]
        data: {
          "DateOfBirth": moment(user.dob, 'YYYY-MM-DD').format('MM/DD/YYYY')
          "LastName": user.last_name
          "Next": "Next"
        }
        after: errorCheck(opts)
#        after: reportBody
      }

      # California login form 2
      {
        label: "California login form 2"
        action: "form"
        useBody: true
        fields: ["LastName", "DateOfBirth", "IdentityTypeId", "IssuedStateId", "IssuedCountryId", "IdNumber", "Next"]
        data: {
          "IdentityTypeId": "1"
          "IssuedStateId": "6"
          "IssuedCountryId": "1"
          "IdNumber": user.cid
          "Next": "Next"
        }
        after: errorCheck(opts)
#        after: reportBody
      }
    ]

    NavTools.run opts, plan, cb

  parseHunts = (user, huntIDs, body) ->
    #NON RESIDENT HUNTS:
      #2016 - Deer Tag Drawing Application - 1st Deer (Nonres)              8255
      #2016 - Elk Tag Drawing Application (Nonres)                          8260
      #2016 - Pronghorn Antelope Tag Drawing Application (Nonres)           8262
      #2016 - Bighorn Sheep Tag Drawing Application (Nonres)                8264
    #RESIDENT HUNTS:
      #2016 - Deer Tag Drawing Application - 1st Deer (Res)                 8254
      #2016 - Elk Tag Drawing Application (Res)                             8259
      #2016 - Pronghorn Antelope Tag Drawing Application (Res)              8261
      #2016 - Bighorn Sheep Tag Drawing Application (Res)                   8263

    hunts = []
    $body = $.load body

    if user.residence is 'California'
      hunts.push
        name: "Deer Tag Drawing Application - 1st Deer (Res)"
        id: "8254"
      hunts.push
        name: "Elk Tag Drawing Application (Res)"
        id: "8259"
      hunts.push
        name: "Pronghorn Antelope Tag Drawing Application (Res)"
        id: "8261"
      hunts.push
        name: "Bighorn Sheep Tag Drawing Application (Res)"
        id: "8263"
    else
      hunts.push
        name: "Deer Tag Drawing Application - 1st Deer (Nonres)"
        id: "8255"
      hunts.push
        name: "Elk Tag Drawing Application (Nonres)"
        id: "8260"
      hunts.push
        name: "Pronghorn Antelope Tag Drawing Application (Nonres)"
        id: "8262"
      hunts.push
        name: "Bighorn Sheep Tag Drawing Application (Nonres)"
        id: "8264"

#    drawingsTable = null
#    $body(".head").each (headIndex, header) ->
#      headText = $(header).text().trim()
#      drawingsTable = $(header).parent().find("table").first()  if headText is "Drawings"
#      return
#
#    $(drawingsTable).children("tr").each (rowIndex, row) ->
#      $row = $(row)
#      name = $row.find(".itemdisplayname").text().trim()
#      url = $row.find(".linkButton").attr("href")
#      return if not url or not url.length
#      name = name.split("2014 - ")[1].trim()
#      id = url.split("/InternetSales/Sales/SelectItem?itemID=")[1].trim()
#      return if ~huntIDs.indexOf(id)
#      huntIDs.push id
#      hunts.push
#        name: name
#        id: id
#
#      return

    return hunts


  getHuntOptions = (opts, user, resident, resultSet) ->
    (hunt, cb) ->

      plan = [
        # California cancel previous hunt
        {
          label: "California cancel previous hunt"
          action: "link"
          url: "https://www.ca.wildlifelicense.com/InternetSales/BigGameApplication/Cancel"
          before: (response, body, done) ->
            # console.log "response:", response
            # console.log "body:", body
            x + y unless body
            return done 'SKIP', response, body unless ~body.search /href="\/InternetSales\/BigGameApplication\/Cancel"/
            done()

          after: errorCheck(opts)
#          after: reportBody
        }

        # California select hunt
        {
          label: "California select hunt"
          action: "link"
          url: "https://www.ca.wildlifelicense.com/InternetSales/Sales/SelectItem?itemID=" + hunt.id
          after: errorCheck(opts)
#          after: reportBody
        }

        # California select party type
        {
          label: "California select party type"
          action: "form"
          selector: "#MyForm"
          useBody: true
          fields: ["IsNewParty", "PartyNumber", "WorkflowStepID"]
          before: (response, body, done) ->
            unless ~body.search /id="PartyNumber"/

              hunt.groupable = false # Only for the group gather script

              return done 'SKIP', response, body

            hunt.groupable = true # Only for the group gather script

            stepId = body.match(/step\.value = "(.*)";/)[1]

            if not user.inGroup or user.isLeader
              data = {
                "IsNewParty": "true"
                "PartyNumber": ""
                "WorkflowStepID": stepId
              }
            else
              data = {
                "IsNewParty": "False"
                "PartyNumber": appData.partyId
                "WorkflowStepID": stepId
              }

            done null, {data}
          after: errorCheck(opts)
#          after: reportBody
        }
      ]

      console.log "Start getHuntOptions"
#      console.log "resultSet.body:", resultSet.body
      NavTools.run opts, plan, resultSet.response, resultSet.body, (err, response, body) ->
        return cb err if err

        #console.log "getHuntOptions result body:", body

        resultSet.response = response
        resultSet.body = body

        hunt.options = []
        $body = $.load body

        console.log hunt.name

        $body('.list-group > .list-group-item > .row').each (index, item) ->
          return unless index > 0
          rowText = $(item).text().trim()
          #rowParts = rowText.split("\n")
          #name = rowParts[0].trim() if rowParts[0]
          #value = rowParts[1].trim() if rowParts[1]
          value = rowText.substring(0, rowText.indexOf("\n")).trim()
          name = rowText.substring(rowText.indexOf("\n") + 1).trim()
          console.log "ROW #{index}     #{name}:#{value}"
          if name and value
            hunt.options.push {
              name: name
              value: value
            }

        if hunt.options.length
          id = uuid.v4()
          huntInserts.push "db.hunts.insert({id: ObjectId(\"#{id}\"), active: true, stateId: ObjectId(\"#{stateId}\"), name: \"#{hunt.name}\", match: \"#{hunt.name}\", groupable: false, params: {resident: #{resident}, value: \"#{hunt.id}\"}});"
          for option in hunt.options
            optionInserts.push "db.huntoptions.insert({active: true, huntId: ObjectId(\"#{id}\"), stateId: ObjectId(\"#{stateId}\"), data: #{JSON.stringify(option)}});"

        cb()

  getHunts = (type, cb) ->
    opts = {
      jar: request.jar()
    }
    huntIDs = []
    user = hunterTypes[type].user

    async.waterfall [
      # Login
      (next) ->
        login opts, user, next

      # Add License
      (response, body, next) ->
        addLicense opts, user, response, body, next

      # Get hunt options
      (response, body, next) ->
        hunts = parseHunts(user, huntIDs, body)

        resultSet = {response, body}
        console.log "hunts:", hunts
        async.mapSeries hunts, getHuntOptions(opts, user, type is 'res', resultSet), (err) ->
          console.error "getHunts error:", err if err
          return cb(err, hunts)


    ], (err, results) ->
      console.log "getHunts err if err:", err if err
      return cb err if err

  reportBody = (err, response, body, cb) ->
    console.log "reportBody err:", err if err
    console.log "body:", body
    x = y


  hunterTypes = {
    res: {
      user: {
        last_name: 'Attorri'
        dob: '1961-12-27' #12/27/1961
        cid: '1035182527'
        residence: "California"
      }
    }


    nonRes: {
      user: {
        last_name: 'Douglas'
        dob: '1967-07-06' # 07/06/1967
        cid: '1009507619'
        residence: "Texas"
      }
    }
  }

  types = Object.keys hunterTypes

  async.mapSeries types, getHunts, (err, results) ->
    console.error "ERROR:", err if err
    result = {res: results[0], nonRes: results[1]}
    # console.log "California hunts", JSON.stringify(result)
    console.log "\n\n\n\n\n\n\n\n\n\n// Hunts:\n"
    for insert in huntInserts
      console.log insert

    console.log "\n\n\n\n\n\n\n\n\n\n// Options:\n"
    for insert in optionInserts
      console.log insert
    process.exit(0)
