_ = require 'underscore'
argv = require('minimist')(process.argv.slice(2))
async = require "async"
config = require './config'
excel = require 'excel'
fs = require 'fs'
moment = require 'moment'
ObjectMapper = require 'object-mapper'
path = require 'path'


clientMap = {
  "__Client #": "client_id"
  "_Date of Birth": "date_of_birth"
  "Social Security #": "social_security"
}

userMap = {
  "client_id": "clientId"
  "date_of_birth": "dob"
  "field1": "field1"
  "field2": "field2"
  "field3": "field3"
  "social_security": "ssn"
}

config.resolve (
  HuntinFoolClient
  Secure
  User
) ->

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

      excel filePath, (err, data) ->
        return next err if err
        return next "Now rows found" if data.length <= 1
        console.log "Rows found:", data.length

        console.log "objectifying the data"
        keys = data.shift()

        data = data.filter (row) ->
          return row[0]?.length

        for row, i in data
          data[i] = _.object keys, row

        next null, data

    (data, next) ->
      type = 'client'
      next null, type, data

    (type, data, next) ->
      map = clientMap
      model = HuntinFoolClient

      saveStuff = ((dataModel) ->
        (record, done) ->
          record = ObjectMapper.merge record, {}, map
          record.modified = new Date()

          return done() unless record.client_id?.length
          console.log "save client_id:", record.client_id

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
#          console.log "ssn:", ssn
#          console.log "dob:", dob
#          [record.field1, record.field2] = Secure.social ssn, dob
#          record.field3 = ssn.substr -4
          record.social_security = ssn


          userRecord = new ObjectMapper.merge(record, {}, userMap)
          userRecord.modified = new Date()
          query = {$and: [{clientId: userRecord.clientId}, {clientId: {$ne: null}}]}
          User.upsert userRecord, {upsert: false, query}, (err, user) ->
            return done err if err

            throw new Error "No user id found" unless user?._id
            record.userId = user._id
            dataModel.upsert record, done

            return

      )(model)

      async.mapSeries data, saveStuff, (err) ->
        return next err if err
        next null, type


  ], (err) ->
    console.error "Ended with an error", err if err
    console.log "Done"
    process.exit(0)
