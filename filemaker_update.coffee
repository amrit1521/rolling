_ = require 'underscore'
argv = require('minimist')(process.argv.slice(2))
async = require "async"
config = require './config'
# excel = require 'excel'
xlsx = require 'node-xlsx'
fs = require 'fs'
moment = require 'moment'
ObjectMapper = require 'object-mapper'
path = require 'path'

stateMap = {
  "Client ID": "client_id"
  "AZ Check": "az_check"
  "AZ Comments": "az_comments"
  "AZ License": "az_license"
  "AZ Notes": "az_notes"
  "AZ Species": "az_species"
  "CA Check": "ca_check"
  "CA Comments": "ca_comments"
  "CA Notes": "ca_notes"
  "CA Species": "ca_species"
  "CO Check": "co_check"
  "CO Comments": "co_comments"
  "CO Notes": "co_notes"
  "CO Species": "co_species"
  "IA Check": "ia_check"
  "IA Comments": "ia_comments"
  "IA Notes": "ia_notes"
  "IA Species": "ia_species"
  "ID Check": "id_check"
  "ID Comments": "id_comments"
  "ID Notes": "id_notes"
  "ID Species 1": "id_species_1"
  "ID Species 3": "id_species_3"
  "KS Check": "ks_check"
  "KS Comments": "ks_comments"
  "KS Mule Deer Stamp": "ks_mule_deer_stamp"
  "KS Notes": "ks_notes"
  "KS Species": "ks_species"
  "MT Check": "mt_check"
  "MT Comments": "mt_comments"
  "MT Notes": "mt_notes"
  "MT Species": "mt_species"
  "NM Check": "nm_check"
  "NM Comments": "nm_comments"
  "NM Notes": "nm_notes"
  "NM Species": "nm_species"
  "NV Check": "nv_check"
  "NV Comments": "nv_comments"
  "NV Notes": "nv_notes"
  "NV Species": "nv_species"
  "ORe Check": "ore_check"
  "ORe Comments": "ore_comments"
  "ORe Notes": "ore_notes"
  "ORe Species": "ore_species"
  "UT Check": "ut_check"
  "UT Comments": "ut_comments"
  "UT Notes": "ut_notes"
  "UT Species 1": "ut_species_1"
  "UT Species 2": "ut_species_2"
  "WA Check": "wa_check"
  "WA Comments": "wa_comments"
  "WA Notes": "wa_notes"
  "WA Species": "wa_species"
  "WY Check": "wy_check"
  "WY Comments": "wy_comments"
  "WY Notes": "wy_notes"
  "WY Species": "wy_species"
}

stateNoteFields = [
  "az_notes"
  "ca_notes"
  "co_notes"
  "ia_notes"
  "id_notes"
  "ks_notes"
  "mt_notes"
  "nm_notes"
  "nv_notes"
  "ore_notes"
  "ut_notes"
  "wa_notes"
  "wy_notes"
]

clientMap = {
  "__Client #": "client_id"
  "_Date of Birth": "date_of_birth"
  "_Eyes": "eyes"
  "_Gender": "gender"
  "_Hair": "hair"
  "_Height": "height"
  "_NmFst": "nmfst"
  "_NmLt": "nmlt"
  "_NmMd": "nmmd"
  "_Tl": "tl"
  "_Weight": "weight"
  "Billing1_Address": "billing1_address"
  "Billing1_City": "billing1_city"
  "Billing1_State": "billing1_state"
  "Billing1_Zip": "billing1_zip"
  "Billing2_Address": "billing2_address"
  "Billing2_City": "billing2_city"
  "Billing2_State": "billing2_state"
  "Billing2_Zip": "billing2_zip"
  "CA ID#": "ca_id"
  "CO Conservation #": "co_conservation"
  "Contact_EMail": "contact_email"
  "Credit Card1_#": "credit_card1"
  "Credit Card1_Code": "credit_card1_code"
  "Credit Card1_Month": "credit_card1_month"
  "Credit Card1_Name": "credit_card1_name"
  "Credit Card1_Year": "credit_card1_year"
  "Credit Card2_#": "credit_card2"
  "Credit Card2_Code": "credit_card2_code"
  "Credit Card2_Month": "credit_card2_month"
  "Credit Card2_Name": "credit_card2_name"
  "Credit Card2_Year": "credit_card2_year"
  "Driver License": "driver_license"
  "Driver License State": "driver_license_state"
  "Hunter Ed #": "hunter_ed"
  "Hunter Ed State": "hunter_ed_state"
  "Hunting_Comments": "hunting_comments"
  "IA Conservation #": "ia_conservation"
  "KS Number": "ks_number"
  "Mail_Address": "mail_address"
  "Mail_City": "mail_city"
  "Mail_Country": "mail_country"
  "Mail_County": "mail_county"
  "Mail_State": "mail_state"
  "Mail_Zip": "mail_zip"
  "Member ID": "member_id"
  "MTALS#": "mtals"
  "NM CIN": "nm_cin"
  "ORe Hunter #": "ore_hunter"
  "Phone_Cell": "phone_cell"
  "Phone_Day": "phone_day"
  "Phone_Evening": "phone_evening"
  "Social Security #": "social_security"
  "TX ID#": "tx_id"
  "Weapons mstr": "weapons_mstr"
  "WILD #": "wild"
  "WY ID#": "wy_id"
  "Duals::last": "duals_last"
  "Duals::name": "duals_name"
  "Duals::number": "duals_number"
}

userMap = {
  "client_id": "clientId"
  "mail_address": "mail_address"
  "mail_city": "mail_city"
  # "": "createdAt"
  "mail_country": "mail_country"
  "date_of_birth": "dob"
  "driver_license": "drivers_license"
  "driver_license_state": "dl_state"
  "contact_email": "email"
  "eyes": "eyes"
  "nmfst": "first_name"

  "field1": "field1"
  "field2": "field2"
  "field3": "field3"

  "field4": "field4"
  "field5": "field5"
  "field6": "field6"
  "field7": "field7"
  "field8": "field8"

  "field9": "field9"
  "field10": "field10"
  "field11": "field11"
  "field12": "field12"
  "field13": "field13"

  "gender": "gender"
  "hair": "hair"
  "height": {
    key: "heightFeet"
    transform: (value, objFrom, objTo) =>
      return value unless value

      [feet, inches] = value.split("'")
      heightFeet = feet?.replace(/[^\d]/g, '')
      heightInches = inches?.replace(/[^\d]/g, '')
      ObjectMapper.setKeyValue(objTo, 'heightInches', heightInches)
      return heightFeet
  }
  # "": "hunter_number"
  "hunter_ed": "hunter_safety_number"
  "hunter_ed_state": "hunter_safety_state"
  # "weapons_mstr": "hunter_safety_type"
  # "": "isAdmin"
  "nmlt": "last_name"
  # "": "locale"
  "nmmd": "middle_name"
  # "": "name"
  # "": "password"
  "phone_day": {
    key: "phone_day"
    transform: (value, objFrom, objTo) ->
      return value.replace /[^\d]/g, ''
  }
  "phone_cell": {
    key: "phone_cell"
    transform: (value, objFrom, objTo) ->
      return value.replace /[^\d]/g, ''
  }
  "phone_evening": {
    key: "phone_home"
    transform: (value, objFrom, objTo) ->
      value = value.replace /[^\d]/g, '' if value
      return value
  }
  "mail_zip": "mail_postal"
  # "": "res_months"
  # "": "res_years"
  "social_security": {
    key: "ssn"
    transform: (value, objFrom, objTo) ->
      return value.replace /[^\d]/g, ''
  }
  "mail_state": "mail_state"
  "tl": "suffix"
  # "": "tenantId"
  # "": "timestamp"
  # "": "type"
  "modified": "modified"
  # "": "username"
  "weight": "weight"
}

translateColor = (color) ->
  switch color.toLowerCase()
    when "bald" then "Bald"
    when "black" then "Black"
    when "blonde" then "Blonde"
    when "blue" then "Blue"
    when "brown" then "Brown"
    when "green" then "Green"
    when "gray" then "Gray"
    when "hazel" then "Hazel"
    when "red" then "Red"
    when "sandy" then "Sandy"
    when "white" then "White"
    else ""

config.resolve (
  HuntinFoolClient
  HuntinFoolGroup
  HuntinFoolState
  HuntinFoolTenantId
  NavTools
  Secure
  User
) ->

  groups = []

  async.waterfall [
    (next) ->
      console.log "Check input"
      filePath = argv._?[0]
      return next "Path to the filemaker file to upload must be specified" unless filePath
      next null, filePath

    (filePath, next) ->
      console.log "Check file path"
      filePath = path.join __dirname, filePath

      fs.exists filePath, (exists) ->
        return next "File does not exist" unless exists
        next null, filePath

    (filePath, next) ->
      console.log "Load excel file"

      obj = xlsx.parse filePath

#      excel filePath, (err, data) ->
      obj[0].data[1]
      return next "Now sheets found" unless obj.length
      sheet = obj[0].data
      return next "Now rows found" unless sheet.length
      console.log "Rows found:", sheet.length

      console.log "objectifying the data"
      keys = sheet.shift()

      sheet = sheet.filter (row) ->
        return if row[0] then ('' + row[0]).length else false

      for row, i in sheet
        sheet[i] = _.object keys, row

      next null, sheet

    (data, next) ->
      console.log "Determine data type"

      # Determine data type client or state
      type = 'state'
      type = 'client' if data?[0]?['_NmFst']
      next null, type, data

    (type, data, next) ->
#      console.log "Load data:", data.length
#      console.log "Load type:", type
      switch type
        when 'client'
          map = clientMap
          model = HuntinFoolClient

        when 'state'
          map = stateMap
          model = HuntinFoolState

      saveStuff = ((dataModel) ->
        (record, done) ->
          record = ObjectMapper.merge record, {}, map
          record.modified = new Date()

          for key, value of record
            if value
              record[key] = ('' + value).replace /&#10;/g, "\n"
            else
              record[key] = ''

          groups.push _.pick record, 'client_id', 'duals_number' if record.duals_number?.length

          return done() unless record.client_id?.length
          console.log "save client_id:", record.client_id

          if type is 'client'

            ssn = (record.social_security.replace(/[^\d]/g, '') + '000000000').substr(0, 9)

            if record.date_of_birth?.length
              if ~record.date_of_birth.search '/'
                dob = moment(record.date_of_birth, 'MM/DD/YYYY').format('YYYY-MM-DD')
              else
                dob = parseInt(record.date_of_birth, 10)
                if dob > 7300
                  dob = moment('12/30/1899', 'MM/DD/YYYY').add(dob, 'days').format('YYYY-MM-DD')
                else
                  dob = '0000-00-00'

            else
              dob = '0000-00-00'

            record.date_of_birth = dob

            #  field1: String # ssn/dob part1
            #  field2: String # ssn/dob part2
            #  field3: String # ssn last4
#            [record.field1, record.field2] = Secure.social ssn, dob
#            record.field3 = ssn.substr -4


            #  credit_card1: String
            #  credit_card1_code: String
            #  credit_card1_month: String
            #  credit_card1_name: String
            #  credit_card1_year: String

            #  field4: String # cc1 name
            #  field5: String # cc1 code
            #  field6: String # cc1/exp part1
            #  field7: String # cc1/exp part2
            #  field8: String # cc1 last4
            if record.credit_card1.length >= 12
              cc = record.credit_card1.replace /[^\d]/g, ''
              record.field4 = Secure.encrypt record.credit_card1_name
              record.field5 = Secure.encrypt record.credit_card1_code

              exp = ('00' + record.credit_card1_month).substr(-2) + '20' + record.credit_card1_year.substr(-2)
              [record.field6, record.field7] = Secure.credit cc, exp

              record.field8 = cc.substr -4


            #  credit_card2: String
            #  credit_card2_code: String
            #  credit_card2_month: String
            #  credit_card2_name: String
            #  credit_card2_year: String
            #  date_of_birth: String

            #  field9: String # cc2 name
            #  field10: String # cc2 code
            #  field11: String # cc2/exp part1
            #  field12: String # cc2/exp part2
            #  field13: String # cc2 last4
            if record.credit_card2?.length >= 12
              cc = record.credit_card2.replace /[^\d]/g, ''
              record.field9 = Secure.encrypt record.credit_card2_name
              record.field10 = Secure.encrypt record.credit_card2_code

              exp = ('00' + record.credit_card2_month).substr(-2) + '20' + record.credit_card2_year.substr(-2)
              [record.field11, record.field12] = Secure.credit cc, exp

              record.field13 = cc.substr -4

            userRecord = new ObjectMapper.merge(record, {}, userMap)

            userRecord.name = userRecord.first_name + ' ' + userRecord.last_name
            # userRecord._id = dbRecord.get 'userId' if dbRecord
            userRecord.hunter_safety_type = 'Firearm'
            userRecord.hair = translateColor(record.hair)
            userRecord.eyes = translateColor(record.eyes)
            userRecord.mail_state = NavTools.stateFromAbbreviation(userRecord.mail_state)
            userRecord.dl_state = NavTools.stateFromAbbreviation(userRecord.dl_state)
            userRecord.hunter_safety_state = NavTools.stateFromAbbreviation(userRecord.hunter_safety_state)
            # userRecord.ssn = record.field3
            userRecord.res_months = 0
            userRecord.res_years = 1
            userRecord.active = true
            userRecord.modified = new Date()
            userRecord.tenantId = HuntinFoolTenantId

            if userRecord.clientId
              query = {clientId: userRecord.clientId}
            else
              query = {_id: {$exists: false}}

            User.upsert userRecord, {upsert: true, query}, (err, user) ->
              return done err if err

              throw new Error "No user id found" unless user?._id
              record.userId = user._id
              dataModel.upsert record, done

              return

          else
            residence = null
            for field in stateNoteFields
              if ~record[field]?.search /resident/ig
                residence = NavTools.stateFromAbbreviation(field.substr(0, 2))
                break


            if residence
              if record.client_id
                query = {clientId: record.client_id}
              else
                x = y
                query = {_id: {$exists: false}}

              options = {
                query
                upsert: false
              }
              User.upsert {residence}, options, (err, uUser) ->
                return done err if err
                return done() unless uUser
                dataModel.upsert record, done
            else
              dataModel.upsert record, done

      )(model)

      async.mapSeries data, saveStuff, (err) ->
        return next err if err
        next null, type

    (type, next) ->
      return next() if type is 'state'

      console.log "Loading groups"

      # Delete existing group sets
      HuntinFoolGroup.remove({}, false)


      grouped = {}
      consolidated = {}

      for group in groups
        if group.client_id?.length
          currentLeader = group.client_id

          if not grouped[group.client_id] and not grouped[group.duals_number]
            consolidated[group.client_id] ?= []
            consolidated[group.client_id].push group.client_id unless ~consolidated[group.client_id].indexOf(group.client_id)
            consolidated[group.client_id].push group.duals_number unless ~consolidated[group.client_id].indexOf(group.duals_number)

            grouped[group.client_id] = group.client_id
            grouped[group.duals_number] = group.client_id

          else if not grouped[group.client_id]
            consolidated[grouped[group.duals_number]] ?= []
            consolidated[grouped[group.duals_number]].push group.client_id unless ~consolidated[grouped[group.duals_number]].indexOf(group.client_id)
            grouped[group.client_id] = grouped[group.duals_number]

          else if not grouped[group.duals_number]
            consolidated[grouped[group.client_id]] ?= []
            consolidated[grouped[group.client_id]].push group.duals_number unless ~consolidated[grouped[group.client_id]].indexOf(group.duals_number)
            grouped[group.duals_number] = grouped[group.client_id]

        else if not grouped[group.duals_number]
          consolidated[currentLeader] ?= []
          consolidated[currentLeader].push group.duals_number unless ~consolidated[currentLeader].indexOf(group.duals_number)
          grouped[group.duals_number] = currentLeader

        console.log "consolidated length:", Object.keys(consolidated).length

      # console.log "consolidated:", consolidated
      console.log "Build group list"
      groups = []
      for key, value of consolidated
        groups.push {
          leader: key
          members: value
        }

      saveGroup = (info, done) ->
        HuntinFoolGroup.byLeader info.leader, (err, group) ->
          return done err if err

          if not group
            group = new HuntinFoolGroup info

          else
            for key, value of info
              continue if key in ['_id', '__v']
              group.set key, value

          group.save done
          return

      console.log "Save groups"
      async.mapSeries groups, saveGroup, (err) ->
        next err

    (next) ->

      User.find({tenantId: HuntinFoolTenantId}).exec (err, users) ->
        return next err if err

        userTotal = 0
        userIndex = 0

        updateUserResidency = (user, done) ->
          return done null, user if user.get('residence')?.length

          userIndex++
          console.log "Updating residency for #{userIndex} of #{userTotal}"

          residence = user.get('residence')
          state = user.get('mail_state')

          if residence
            user.set 'residence', NavTools.stateFromAbbreviation(residence)
          else if state
            user.set 'residence', NavTools.stateFromAbbreviation(state)

          user.save done
          return

        userTotal = users.length
        async.mapSeries users, updateUserResidency, next

      # User.update {residence: null, tenantId: HuntinFoolTenantId}, {$set: {residence: ''}}, next

  ], (err) ->
    console.error "Ended with an error", err if err
    console.log "Done"
    process.exit(0)
