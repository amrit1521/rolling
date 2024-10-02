_ = require 'underscore'
argv = require('minimist')(process.argv.slice(2))
async = require "async"
config = require './config'
fs = require 'fs'
moment = require 'moment'
ObjectMapper = require 'object-mapper'
path = require 'path'
request = require "request"

config.resolve (
  HuntinFoolClient
  Secure
  User
) ->
  #console.log(config)
  #console.log('HuntinFoolClient.1:', HuntinFoolClient)

  async.waterfall [
    (next) ->
      clientId = argv._?[0]
      next null, clientId

    (clientId, next) ->
      #clientIds = [ "00066", "00067"]
      clientIds = [ "07702"]
      #clientIds = [ clientId ] if clientId
      #console.log(clientIds)
      #console.log(HuntinFoolClient)

      #HuntinFoolClient.byIds clientIds, (err, clients) ->
      HuntinFoolClient.byNeedEncryptCC true, (err, clients) ->
        return next err if err

        total = 0

        updateClient = (client, done) ->
          client.needEncryptCC = false

          ssn = (client.social_security.replace(/[^\d]/g, '') + '000000000').substr(0, 9)
          [client.field1, client.field2] = Secure.social ssn, client.date_of_birth
          client.field3 = ssn.substr -4

          if client.credit_card1.length >= 12
            cc = client.credit_card1.replace /[^\d]/g, ''
            client.field4 = Secure.encrypt client.credit_card1_name
            client.field5 = Secure.encrypt client.credit_card1_code

            exp = ('00' + client.credit_card1_month).substr(-2) + '20' + client.credit_card1_year.substr(-2)
            [client.field6, client.field7] = Secure.credit cc, exp

            client.field8 = cc.substr -4

          if client.credit_card2?.length >= 12
            cc = client.credit_card2.replace /[^\d]/g, ''
            client.field9 = Secure.encrypt client.credit_card2_name
            client.field10 = Secure.encrypt client.credit_card2_code

            exp = ('00' + client.credit_card2_month).substr(-2) + '20' + client.credit_card2_year.substr(-2)
            [client.field11, client.field12] = Secure.credit cc, exp

            client.field13 = cc.substr -4


          query = {client_id: client.client_id}

          #client.social_security = undefined if client.social_security
          #client.credit_card1 = undefined if client.credit_card1
          #client.credit_card1_name = undefined if client.credit_card1_name
          #client.credit_card1_code = undefined if client.credit_card1_code
          #client.credit_card1_month = undefined if client.credit_card1_month
          #client.credit_card1_year = undefined if client.credit_card1_year
          #client.credit_card2 = undefined if client.credit_card2
          #client.credit_card2_name = undefined if client.credit_card2_name
          #client.credit_card2_code = undefined if client.credit_card2_code
          #client.credit_card2_month = undefined if client.credit_card2_month
          #client.credit_card2_year = undefined if client.credit_card2_year

          #console.log client

          HuntinFoolClient.upsert client, {upsert: false, query}, (err, client) ->
          #HuntinFoolClient.update {_id: client._id},  tRecord, {upsert: false}, (err, client) ->
          #HuntinFoolClient.update {client_id: client.client_id},  tRecord, {upsert: false}, (err, client) ->
            return done err if err
            return done(new Error "No client id found ") unless client?._id

            #console.log client.client_id
            userRecord = {}
            userRecord.ssn = ssn
            userRecord.dob = client.date_of_birth
            userRecord.field3 = client.field3
            userRecord.field4 = client.field4
            userRecord.field5 = client.field5
            userRecord.field6 = client.field6
            userRecord.field7 = client.field7
            userRecord.field8 = client.field8
            userRecord.field9 = client.field9
            userRecord.field10 = client.field10
            userRecord.field11 = client.field11
            userRecord.field12 = client.field12
            userRecord.field13 = client.field13

            query = {clientId: client.client_id}
            User.upsert userRecord, {upsert: false, query}, (err, user) ->
              return done err if err
              return done(new Error "No user id found for clientId"+user.clientId) unless user?._id

              total = total + 1;
              console.log "Processing item "+total+"... Successfully encrypted ssn, dob, and credit card info for clientId: "+user.clientId+" user id: "+user._id
              return done();

        async.map clients, updateClient, next

  ], (err) ->
    console.error "Ended with an error", err if err
    console.log "Done"
    process.exit(0)
