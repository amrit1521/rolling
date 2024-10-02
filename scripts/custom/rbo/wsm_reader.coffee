_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'

#   ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/wsm_reader.coffee

config.resolve (
  logger
  Secure
  User

) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  INPUT_FILE = "/Users/scottwallace/Desktop/Main/GotMyTag/RollingBones/from wsm data/rbo_contacts.csv"

  processLine = (line, done) ->
    #return next null  #Skip processing this line
    userCount++
    #return done null unless userCount < 10
    #console.log "****************************************Processing #{userCount} of #{userTotal}"
    data = line.split('"')
    lineMod = ""
    i=0
    for x in data
      x = x.replace(/,/g, "~") if i % 2 > 0
      #console.log "DEBUG: x: ", x
      lineMod = lineMod + x
      i++
    data = lineMod.split(",")
    transaction = {
      id: data[0]
      name: data[1]
      first_name: data[2]
      last_name: data[3]
      email: data[4]
      dob: data[6]
      phone: data[10]
      address1: data[29]
      address2: data[30]
      city: data[31]
      state: data[32]
      zip: data[33]
      country: data[36]
      tags: data[65]
      newsletter: data[66]
      specials: data[67]
      created: data[83]
      memberId: data[92]
      memberStartDate: data[94]
      amount: data[103]
      lastDate: data[108]
      lastAmount: data[109]
      lastProduct: data[117]
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
      #Orgainze by Product Type
      uniqueProducts = {}
      memberships = []
      newsletters = []
      specials = []
      for tran in transactions
        if tran.lastProduct
          uniqueProducts[tran.lastProduct] = tran.lastProduct
          memberships.push tran if tran.lastProduct?.toLowerCase().indexOf("membership") > -1
        if tran.newsletter
          newsletters.push tran
        if tran.specials
          specials.push tran

      #console.log "uniqueProducts: ", uniqueProducts
      console.log "memberships: ", memberships.length
      console.log "newsletters: ", newsletters.length
      console.log "specials: ", specials.length
      return next null, memberships, newsletters, specials

      # Now check if users already exist:
    (memberships, newsletters, specials, next) ->

      memberMatches = {}
      memberMatchesNoMember = {}
      memberMatchesOffDates = {}
      memberNOTMatches = {}
      total = memberships.length
      tCount = 1

      findUser = (tran, done) ->
        console.log "****************************************Processing #{tCount} of #{total}"
        tCount++
        return done null, tran unless tran
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
        #console.log "DEBUG: conditions", JSON.stringify(conditions)
        User.find(conditions).lean().exec (err, results) ->
          console.log "ERROR: ", err if err
          return done err if err
          if results?.length
            console.log "FOUND RADS MATCH FOR TRAN: ", tran.id, tran.first_name, tran.last_name, tran.email
            tran_memberStartDate = new Date(tran.memberStartDate) if tran.memberStartDate
            tran_memberStartDate = new Date(tran.lastDate) unless tran_memberStartDate
            console.log "member start date: ", tran_memberStartDate
            foundMember = false
            for user in results
              if user.isMember
                foundMember = true
                tUser = _.pick(user,"_id","clientId","isMember","memberExpires","name", "email")
                tUser.created = user._id.getTimestamp()
                console.log "RADS USER: ", tUser
                memberMatches[user.clientId] = tran
                diff = Math.round((tUser.created - tran_memberStartDate)/(1000*60*60*24))
                diff = 1000 if isNaN(diff)
                console.log "DEBUG: tUser.created - tran_memberStartDate: ", diff, tUser.created, tran_memberStartDate, tUser.created - tran_memberStartDate if diff > 10
                memberMatchesOffDates[tran.id] = {tran: tran, users: results} if diff > 10 or diff < -10
            memberMatchesNoMember[tran.id] = {tran: tran, users: results} unless foundMember
          else
            console.log "NO MATCH: ", tran
            memberNOTMatches[tran.id] = tran
          return done null, tran

      async.mapSeries memberships, findUser, (err, transactions) ->
        console.log "FOUND MATCHES IN RADS: ", Object.keys(memberMatches).length
        console.log "MATCHES IN RADS DIFF LARGE CREATED DATES: ", Object.keys(memberMatchesOffDates).length
        console.log "MATCHES IN RADS BUT IS MEMBER FALSE: ", Object.keys(memberMatchesNoMember).length
        console.log "NO MATCHES FOUND IN RADS: ", Object.keys(memberNOTMatches).length

        datediffStr = ""
        for key, item of memberMatchesOffDates
          if item.users?.length == 1
            datediffStr = "#{datediffStr}, #{item.users[0]._id}"
          else if item.users?.length > 1
            console.log "ITEM HAS MULTPLE USERS MATCHED: "
            for u in item.users
              console.log "    #{u._id}, #{u.name}, #{u.clientId}, #{u.isMember}"
              datediffStr = "#{datediffStr}, #{item.users[0]._id}"
          else
            console.log "ITEM MISSING USER: ", item
        console.log "Dates diff > month: ", datediffStr
        return next err, transactions


  ], (err, transactions) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      #console.log "Unique Users: ", Object.keys(transactions).length
      console.log "Done"
      process.exit(0)
