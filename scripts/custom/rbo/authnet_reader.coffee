_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#   ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/authnet_reader.coffee

config.resolve (
  logger
  Secure
  User

) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  INPUT_FILE = "/Users/scottwallace/Desktop/Main/GotMyTag/RollingBones/from wsm data/authorize_net_old_trans.csv"

  processLine = (line, done) ->
    #return next null  #Skip processing this line
    userCount++
    #return done null unless userCount < 10
    #console.log "****************************************Processing #{userCount} of #{userTotal}"
    data = line.split(",")
    transaction = {
      created: new Date(data[5])
      desc: data[9]
      amount: data[11]
      action_code: data[13]
      auth_customerId: data[14]
      first_name: data[15]
      last_name: data[16]
      phone: data[23]
      email: data[25]
    }
    #console.log "transaction: ", transaction
    return done null, transaction


  lines = []
  async.waterfall [

    # Read File
    (next) ->
      console.log 'Reading file...'
      lineReader = require('readline').createInterface({
        input: require('fs').createReadStream(INPUT_FILE)
      });

      lineReader
        .on 'line', (line) ->
          #console.log 'Line from file:', line
          #console.log 'lines.length:', lines
          lines.push line
        .on 'close', () ->
          console.log 'Finished reading file.', lines.length
          return next null, lines

    # For each line create objects
    (lines, next) ->
      lines = [lines] unless typeIsArray lines
      console.log "found #{lines.length} lines"
      userTotal = lines.length
      async.mapSeries lines, processLine, (err, transactions) ->
        return next err, transactions

    # For each transaction...
    (transactions, next) ->
      #Orgainze by user
      userTrans = {}
      for tran in transactions
        continue unless tran?.auth_customerId
        #console.log "DEBUG: tran: ", tran.auth_customerId
        if !userTrans[tran.auth_customerId]
          userTrans[tran.auth_customerId] = {
            trans: []
            auth_customerId: tran.auth_customerId,
            first_name: tran.first_name,
            last_name: tran.last_name,
            phone: tran.phone,
            email: tran.email
          }
        userTrans[tran.auth_customerId].trans.push {created: tran.created, desc: tran.desc, amount: tran.amount, action_code: tran.action_code}
      #console.log "DEBUG: userTrans: ", userTrans
      return next null, userTrans

    # Report by month
    (userTrans, next) ->
      for key, tran of userTrans
        logStrUser = "User: ****** #{tran.auth_customerId.trim()}, #{tran.first_name.trim()}, #{tran.last_name.trim()}, #{tran.phone.trim()}, #{tran.email.trim()} *****"
        logStrUser = logStrUser.replace(/(?:\r\n|\r|\n|\u0020\u0020\u0020\u0020\u0020)/g, '')

        trans = tran.trans
        found = false
        for tran in trans
          dateStr = (tran.created.getMonth() + 1) + '/' + tran.created.getDate() + '/' +  tran.created.getFullYear()
          tranType = "UNKNOWN"
          tran.amount = parseFloat(tran.amount)
          if tran.amount == 154.96
            tranType = "Membership Yearly"
          if tran.amount == 149
            tranType = "Membership Yearly"
          if tran.amount == 17.24
            tranType = "Membership Monthly"
          if tran.amount == 16.50
            tranType = "Membership Monthly"
          if tran.amount == 26.50 and tran.desc.indexOf("Hunt Specialist Center") > -1
            tranType = "Rep Monthly"
          if tran.amount == 26 and tran.desc.indexOf("Hunt Specialist Center") > -1
            tranType = "Rep Monthly"
          if tran.amount == 25 and tran.desc.indexOf("Hunt Specialist Center") > -1
            tranType = "Rep Monthly"


          if tranType is "UNKNOWN"
            console.log logStrUser unless found
            logStr = "  #{tranType}, #{dateStr}, #{tran.amount}, #{tran.action_code}, #{tran.desc}"
            logStr = logStr.replace(/(?:\r\n|\r|\n|\u0020\u0020\u0020\u0020\u0020)/g, '')
            console.log logStr
            found = true


          #if tranType isnt "Membership Monthly" and tranType isnt "Membership Yearly" and tranType isnt "UNKNOWN"
          #  console.log logStrUser unless found
          #  logStr = "  #{tranType}, #{dateStr}, #{tran.amount}, #{tran.action_code}, #{tran.desc}"
          #  logStr = logStr.replace(/(?:\r\n|\r|\n|\u0020\u0020\u0020\u0020\u0020)/g, '')
          #  console.log logStr
          #  found = true
      return next null, userTrans


  ], (err, transactions) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Unique Users: ", Object.keys(transactions).length
      console.log "Done"
      process.exit(0)
