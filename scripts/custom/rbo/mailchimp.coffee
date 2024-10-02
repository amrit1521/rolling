_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/mailchimp.coffee

UPDATE_USER = false

config.resolve (
  mailchimpapi,
  MailChimpMasterListId,
  User
) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  TENANT_ID = "5bd75eec2ee0370c43bc3ec7"
  START = -1
  END = -1

  MAILCHIMP_TEST_LIST = {}
  MAILCHIMP_MASTER_LIST = {}
  MAILCHIMP_HUNTSPECIALS_LIST = {}
  MAILCHIMP_NEWSLETTER_LIST = {}

  async.waterfall [
    #
    (next) ->
      arg = process.argv[2]
      return next null

    # Get MailChimp Lists
    (next) ->
      #return next null, null
      mailchimpapi.getLists (err, lists) ->
        return next err, lists

    # Get MailChimp Users
    (lists, next) ->
      #return next null, null
      processList = (list, done) ->
        listId = list.id
        #listId = list.web_id
        listName = list.name
        console.log "DEBUG: Found List: ", listId, listName
        mailchimpapi.getUsers list.id, (err, users) ->
          return done err if err
          list.users = users
          return done err, list
      async.mapSeries lists, processList, (err, lists) ->
        for list in lists
          console.log "DEBUG: Processed List returned: ", list.name, list.users.length
        return next null, lists

    # Get MailChimp Master List
    (results, next) ->
      #return next null, null
      mailchimpapi.getLists (err, lists) ->
        for list in lists
          if list.id.toString() is MailChimpMasterListId.toString()
            console.log "Master List is: ", list
        return next null, lists

    # Get MailChimp Master List Users
    (results, next) ->
      #return next null, null
      LIST_NAME = "MASTER"
      LIST_NAME = "Rolling Bones Outfitters TEST"
      mailchimpapi.getUsers LIST_NAME, (err, users) ->
        console.log "DEBUG: #{LIST_NAME} USERS: ", err, users
        return next err, users

    # Get MailChimp Master List Groups
    (results, next) ->
      mailchimpapi.getGroups "MASTER", (err, groups) ->
        console.log "DEBUG: MASTER LIST GROUPS: ", err, groups
        return next err, groups

  ], (err, results) ->
    console.log "Finished"
    if err
      console.log "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
