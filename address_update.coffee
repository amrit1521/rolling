_ = require 'underscore'
argv = require('minimist')(process.argv.slice(2))
async = require "async"
config = require './config'
excel = require 'excel'
fs = require 'fs'
moment = require 'moment'
ObjectMapper = require 'object-mapper'
path = require 'path'
xlsxj = require 'xlsx-to-json'

clientMap = {
  "Client ID": "client_id"
  "Physical Address": "physical_address"
  "Physical City": "physical_city"
  "Physical State": "physical_state"
  "Physical Zip": "physical_zip"
  "Physical Country": "physical_country"
}

userMap = {
  "client_id": {
    key: "clientId"
    transform: (value, objFrom, objTo) ->
      value = ('00000' + value).substr -5
      value = '' if value is '00000'
      return value
  }
  "physical_address": "physical_address"
  "physical_city": "physical_city"
  "physical_state": "physical_state"
  "physical_zip": "physical_postal"
  "physical_country": "physical_country"
}

config.resolve (
  HuntinFoolClient
  HuntinFoolTenantId
  NavTools
  Secure
  User
) ->

  userUpsert = (data, cb = ->) ->
    data.tenantId = HuntinFoolTenantId

    console.log "Upsert user:", data.clientId

    if data._id
      User.findOne(_id: data._id).exec()
        .then (user) ->
          throw new Error('User not found') unless user
          for key, value of data
            continue if key in ['_id', '__v']
            user.set key, value
          user.save()
        .then (user) ->
          cb null, user.id
        .catch (err) ->
          cb err

    else
      User.findOne({clientId: data.clientId}).exec()
        .then (user) ->
          if not user
            throw new Error('User not found')
          for key, value of data
            continue if key in ['_id', '__v']
            user.set key, value
          user.set('physical_country', user.get('mail_country'))
          user.save()
        .then (user) ->
          cb null, user.id
        .catch (err) ->
          cb err

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
        for row, i in data
          data[i] = _.object keys, row

        next null, 'client', data

    (type, data, next) ->
      console.log "Load data:", data.length
      console.log "Load type:", type
      map = clientMap
      model = HuntinFoolClient

      saveStuff = ((dataModel) ->
        (record, done) ->
          record = ObjectMapper.merge record, {}, map

          return done() unless record.client_id?.length
          record.client_id = ('00000' + record.client_id).substr -5
          console.log "save client_id:", record.client_id

          dataModel.findOne(client_id: record.client_id).exec()
            .then (dbRecord) ->
              if dbRecord and record.physical_address?.length
                record.modified = new Date()
                userRecord = ObjectMapper.merge(record, {}, userMap)
                userRecord.physical_state = NavTools.stateFromAbbreviation(userRecord.physical_state)
                userRecord.physical_country = NavTools.countryFromAbbreviation(userRecord.physical_country)

                for key, value of record
                  dbRecord.set key, value

                dbRecord.save()
                  .then ->
                    if userRecord
                      userUpsert userRecord
                    else
                      Promise.resolve()
                  .catch (err) ->
                    Promise.reject(err)
              else
                Promise.resolve()
            .catch (err) ->
              Promise.reject(err)

      )(model)

      async.mapSeries data, saveStuff, (err, results) ->
        next err if err
        next null, type

  ], (err) ->
    console.error "Ended with an error", err if err
    console.log "Done"
    process.exit(0)
