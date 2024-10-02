_       = require 'underscore'
async   = require "async"
config  = require '../config'
winston = require 'winston'

config.resolve (
  HuntinFoolClient
  UserState
) ->

  states = [
    ## I'm not sure what to do with this one, since the cid for Arizona is the social.  Stupid
    # {
    #   name: "Arizona"
    #   id: "52aaa4cae4e055bf33db6499"
    #   cidTitle: "cid"
    # }

    {
      name: "California"
      id: "52aaa4cbe4e055bf33db64a2"
      cidTitle: "ca_id"
    }

    {
      name: "Colorado"
      id: "52aaa4cae4e055bf33db649a"
      cidTitle: "co_conservation"
    }

    # {
    #   name: "Idaho"
    #   id: "52aaa4cbe4e055bf33db649b"
    #   cidTitle: ""
    # }

    {
      name: "Iowa"
      id: "536d28a03e9cb9f28859f2ee"
      cidTitle: "ia_conservation"
    }

    {
      name: "Kansas"
      id: "536d28a83e9cb9f28859f2ef"
      cidTitle: "ks_number"
    }

    {
      name: "Montana"
      id: "52aaa4cbe4e055bf33db649c"
      cidTitle: "mtals"
    }

    # {
    #   name: "Nevada"
    #   id: "52aaa4cbe4e055bf33db649d"
    #   cidTitle: ""
    # }

    {
      name: "New Mexico"
      id: "52aaa4cbe4e055bf33db649e"
      cidTitle: "nm_cin"
    }

    {
      name: "Oregon"
      id: "52aaa4cbe4e055bf33db64a1"
      cidTitle: "ore_hunter"
    }

    {
      name: "Texas"
      id: "536d28ab3e9cb9f28859f2f0"
      cidTitle: "tx_id"
    }

    # {
    #   name: "Utah"
    #   id: "52aaa4cbe4e055bf33db649f"
    #   cidTitle: ""
    # }

    {
      name: "Washington"
      id: "52aaa4d2e4e055bf33db64a3"
      cidTitle: "wild"
    }

    {
      name: "Wyoming"
      id: "52aaa4cbe4e055bf33db64a0"
      cidTitle: "wy_id"
    }
  ]

  clientIndex = 0
  clientTotal = 0
  stateIndex = 0
  stateTotal = states.length

  upsertCIDs = (state) ->
    (client, cb) ->
      clientIndex++

      # console.log "client:", client
      console.log "#{state.name}(#{stateIndex} of #{stateTotal}) - #{client.nmfst} #{client.nmlt}(#{clientIndex} of #{clientTotal})"

      data = {
        userId: client.userId
        stateId: state.id
        cid: client[state.cidTitle]
      }

      # console.log "data:", data
      UserState.upsert data, (err) ->
        cb err

  importCIDByState = (state, cb) ->
    stateIndex++
    clientIndex = 0

    # Get clients
    condition1 = {}
    condition1[state.cidTitle] = {$ne: null}
    condition2 = {}
    condition2[state.cidTitle] = {$ne: ''}
    conditions = {$and: [condition1, condition2]}

    fields = {userId: 1, nmfst: 1, nmlt: 1}
    fields[state.cidTitle] = 1

    # console.log {conditions, fields}

    HuntinFoolClient.find(conditions, fields).sort({nmlt: 1, nmlt: 1}).lean().exec (err, clients) ->
      return cb err if err
      clientTotal = clients.length

      async.mapSeries clients, upsertCIDs(state), (err) ->
        cb err

  async.mapSeries states, importCIDByState, (err) ->
    console.log "Error:", err if err
    process.exit(0)
