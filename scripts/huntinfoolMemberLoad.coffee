_ = require 'underscore'
argv = require('minimist')(process.argv.slice(2))
async = require "async"
config = require '../config'
fs = require 'fs'
moment = require 'moment'
ObjectMapper = require 'object-mapper'
path = require 'path'
request = require "request"

config.resolve (
  HuntinFoolTenantId
  HuntinFoolClient
  HuntinFoolUser
  HuntinFoolLoadDOB
  HuntinFoolLoadNoDOB
  HuntinFoolLoadGeneric
  NavTools
  Secure
  User
  State
  UserState
) ->

  totalDOBProcessed = 0
  totalUsersUpdate = 0
  totalHFClientUsers = 0
  totalStatesProcessed = 0
  totalErrors = 0
  totalMissingMemberIds = 0
  totalParsedDOBs = 0
  totalParsedSSNs = 0
  totalSavedStateCids = 0

  async.waterfall [

    #Process HF w/ DOB records
    (next) ->
      #console.log "Get the HF With DOBs"
      HuntinFoolLoadDOB.index (err, records) ->
        return next err if err

        saveTmpUser = (record, done) ->
          #console.log "Processing w/ DOB record memberId: #{record.member_id} : #{record.first_name} #{record.last_name}"
          hfUserRecord = {}
          hfUserRecord.member_id = record.member_id
          hfUserRecord.first_name = record.first_name
          hfUserRecord.last_name = record.last_name
          hfUserRecord.mail_address = record.mail_address
          hfUserRecord.mail_city = record.mail_city
          hfUserRecord.mail_zip = record.mail_zip


          dobArray = record.dob.split("/")
          if dobArray.length == 3
            year = parseInt( dobArray[2], 10 );
            if year < 17
              yyyy = "20"+year
            else
              yyyy = "19"+year

            if dobArray[1].length == 2
              dd = dobArray[1]
            else
              dd = "0"+dobArray[1]

            if dobArray[0].length == 2
              mm = dobArray[0]
            else
              mm = "0"+dobArray[0]
          else
            return done {"error: invalid dob encountered"}

          hfUserRecord.dob = "#{yyyy}-#{mm}-#{dd}"
          hfUserRecord.mail_state = NavTools.stateFromAbbreviation(record.mail_state)
          hfUserRecord.residence = NavTools.stateFromAbbreviation(record.mail_state)
          hfUserRecord.states = []
          state = {
            state: record.mail_state
          }
          hfUserRecord.states.push(state)

          #See if this user already exists
          ssn = "" #TODO, fill in SSN
          cids = "" #TODO, fill in CIDS
          name = {
            first_name: hfUserRecord.first_name
            last_name: hfUserRecord.last_name
          }

          HuntinFoolClient.byMemberId hfUserRecord.member_id, (err, hfClient) ->
            return next err if err

            if hfClient
              hfUserRecord.userId = hfClient.userId

            #User.findMatch name, ssn, dob, hfUserRecord.mail_zip (err, users) ->
              #if users.length = 1, found a match
              #if users.lenth > 1, user the first one,...log that we found a match
              #if users.length = 0, insert a new user.

            query = {member_id: hfUserRecord.member_id}

            #console.log "query: ", query
            #console.log "HuntinFoolUser.upsert hfUserRecord: ", hfUserRecord
            HuntinFoolUser.upsert hfUserRecord, {upsert: true, query}, (err, hfUser) ->
              console.log "err: ", err if err
              totalDOBProcessed++ unless err
              done err

        #For each HF w/ DOB record, import them to tpm collection
        #console.log "Found #{records.length} HF w/ DOB records to process..."
        async.map records, saveTmpUser, (err) ->
          totalErrors++ if err
          next err


    #Now import as real users
    (next) ->
      console.log "Get the HF Users"
      HuntinFoolUser.index (err, hfUsers) ->
        return next err if err

        importUser = (hfUser, done) ->
          console.log "Importing HF User memberId: #{hfUser.member_id} : #{hfUser.first_name} #{hfUser.last_name}"

          userRecord = {}
          if hfUser.userId
            totalHFClientUsers++
            userRecord._id = hfUser.userId
            userRecord.memberId = hfUser.member_id
            query = {_id: userRecord._id}

          else
            userRecord.imported = "HFMemberLoad"
            userRecord.tenantId = HuntinFoolTenantId
            userRecord.type = "local"
            userRecord.dob = hfUser.dob
            userRecord.name = hfUser.first_name + " " + hfUser.last_name
            userRecord.first_name = hfUser.first_name
            userRecord.last_name = hfUser.last_name
            userRecord.mail_address = hfUser.mail_address
            userRecord.mail_city = hfUser.mail_city
            userRecord.mail_state = hfUser.mail_state
            userRecord.mail_postal = hfUser.mail_zip
            userRecord.mail_country = "United States"
            userRecord.physical_address = hfUser.mail_address
            userRecord.physical_city = hfUser.mail_city
            userRecord.physical_state = hfUser.mail_state
            userRecord.physical_postal = hfUser.mail_zip
            userRecord.physical_country = "United States"
            query = {memberId: hfUser.member_id}

          User.upsert userRecord,  {upsert: true, query}, (err, user) ->
            totalUsersUpdate++ if user
            #console.log "IMPORTED/UPDATED USER: ", user
            done err


        #For each HF w/ DOB record, import them to tpm collection
        console.log("Found #{hfUsers.length} users to import")
        async.map hfUsers, importUser, next


    #Process state cids
    (next) ->
      #console.log "Get the HF With state info"
      HuntinFoolLoadGeneric.index (err, records) ->
        return next err if err

        saveTmpUser = (record, done) ->
          #console.log "Processing member state record memberId: #{record.member_id} : #{record.state} #{record.cid}"

          #first grab the user if one exists for the member_id
          User.byMemberId record.member_id, (err, user) ->
            console.log "err", err if err
            #console.log "RAN INTO A MEMBER ID THAT DIDNT FIND A USER? MemberId: ", record.member_id unless user
            totalMissingMemberIds++
            return done err if err
            return done unless user

            ssn = null
            cid = null
            dob = null

            return done if user.clientId #already a huntinfool client with full data so skip it
            return done unless record.state
            return done unless record.cid

            #Get 9 digit SSN's first
            if record.state == "Arizona" or record.state == "Arizona" or record.state == "Nevada" or record.state == "Utah"
              tSSN = record.cid.replace(/[^0-9]/g, '') #git rid of everything that isn't a digit
              if tSSN.length == 9
                ssn = tSSN
              else
                console.log "unknown cid #{record.state}: #{record.cid} for memberId: #{record.member_id}"

            #Utah
            #   If they are < 9 long and digits, and do not have characters use them as cids
            tCid = record.cid.replace(/[^0-9]/g, '') #git rid of everything that isn't a digit
            if tCid.length < 9 and tCid.length == record.cid.length
              cid = record.cid.length

            #Arizona
            if isNaN(record.cid.substr(0,1))
              tCid = record.cid.substr(1)
            else
              tCid = record.cid

            #Colorado
            #   If they are 9 long and digits, and do not have characters use them as cids
            tCid = record.cid.replace(/[^0-9]/g, '') #git rid of everything that isn't a digit
            if tCid.length == 9 and tCid.length == record.cid.length
              cid = record.cid.length


            #Oregon
            #   Take them as is if numbers only
            tCid = record.cid.replace(/[^0-9]/g, '') #git rid of everything that isn't a digit
            if tCid.length == record.cid.length
              cid = record.cid.length

            #New Mexico
            #   Examples: 10011962-DET, 09281947NRY, 09528-01
            #   Grab the birthday if in form 04161977-NPQ (like montana)
            if record.state == "New Mexico"
              tCid = record.cid
              tDOB = tCid.replace(/[^0-9]/g, '') #git rid of everything that isn't a digit
              if tDOB.length >= 8
                tDOB = record.cid.substr(0,8)
                dob = "#{tDOB.substr(4,4)}-#{tDOB.substr(0,2)}-#{tDOB.substr(2,2)}"
                dob = null if tDOB.replace(/[^0-9]/g, '').length != 8

              console.log "unknown cid #{record.state}: #{record.cid} for memberId: #{record.member_id}" #what should the cid be for NV after we grab the DOB?
              #tCid = tCid.replace(/-/g, "")
              #tCid = tCid.replace(/\s/g, "")
              #tCid = tCid.replace(/\//g, "")


            #Montata:
            #   montana extra massaging.  examples: 09071978-55, 09/30/1941-42, 09/30/1947/66, 1/1/1963-71, 1/15/1984/-32, 1/16/1970 - 67, 10-09-1955-06, 08 - 23 -1980 - 44, 12-09-1954  ALS#38, 12 13 68 55, 1171975-36
            if record.state == "Montana"
              tCid = record.cid
              tCidArray = tCid.split("-")
              if tCidArray.length > 0
                cid = tCidArray[tCidArray.length - 1].replace(/[^0-9]/g, '')
              else
                console.log "unknown cid #{record.state}: #{record.cid} for memberId: #{record.member_id}"


            #Nevada
            #   just take them.  they look pretty good
            if record.state == "Nevada"
                cid = record.cid

            #CALIFORNIA, WY, PENN, KANSAS, etc. ignorning for now
            if cid == null
              console.log "unknown cid #{record.state}: #{record.cid} for memberId: #{record.member_id}"


            async.waterfall [

              #save the user if we found an ssn or dob
              (nextII) ->
                return nextII() unless dob or ssn
                #console.log "found a DOB or SSN, saving it for userId: ", user._id
                if dob
                  totalParsedDOBs++
                  user.dob = dob
                  console.log "found dob #{dob} - userId #{user._id}"
                if ssn
                  totalParsedSSNs++
                  user.ssn = ssn if ssn
                  console.log "found ssn #{ssn} - userId #{user._id}"

                User.upsert user, (err, user) ->
                  nextII err if err
                  return nextII()

              #save the state cid if we found one
              (nextII) ->
                return nextII() unless cid
                State.byName record.state, (err, state) ->
                  return nextII err if err
                  return nextII "invalid state name encountered #{record.state}" unless state
                  userstate = {
                    "cid" : cid,
                    "stateId" : state._id,
                    "userId" : user._id
                  }
                  console.log "Found a #{record.state} state cid and saving it.  #{record.state} cid: #{userstate.cid}, userId: #{userstate.userId}"

                  #uncomment when done testing
                  #UserState.upsert userstate, (err, rsp) ->
                  #  nextII err if err
                  #  totalSavedStateCids++
                  #  nextII null
                  nextII null #TAKE THIS LINE OUT WHEN DONE TESTING

            ], (err) ->
                console.log "error", err if err
                #console.log "calling done"
                done err



        #For each HF state record, import them to tpm collection's users
        console.log "Found #{records.length} HF state records to process..."
        async.map records, saveTmpUser, (err) ->
          next err



  ], (err) ->
    console.error "Ended with an error", err if err
    console.log "Done"
    console.log "totalDOBProcessed = #{totalDOBProcessed}"
    console.log "totalUsersUpdate = #{totalUsersUpdate}"
    console.log "totalHFClientUsers = #{totalHFClientUsers}"
    console.log "totalStatesProcessed = #{totalStatesProcessed}"
    console.log "totalErrors = #{totalErrors}"
    console.log "totalMissingMemberIds = #{totalMissingMemberIds}"
    console.log "totalParsedDOBs = #{totalParsedDOBs}"
    console.log "totalParsedSSNs = #{totalParsedSSNs}"
    console.log "totalSavedStateCids = #{totalSavedStateCids}"

    process.exit(0)
