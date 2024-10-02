_ = require "underscore"
async = require "async"
moment = require "moment"
crypto = require 'crypto'


module.exports = (MailChimp, MailChimpMasterListId, RBO_EMAIL_FROM, RBO_EMAIL_FROM_NAME, rbo_mandrill_client) ->

  mailchimpapi = {

    upsertUser: (mc_listId, user, cb) ->
      return cb "User '#{user.clientId}' is missing an email address. Updating MC subscriptions failed." unless user?.email
      mc_listId = MailChimpMasterListId if mc_listId is "MASTER" or !mc_listId
      emailhash = crypto.createHash('md5').update(user.email.toLowerCase()).digest("hex")
      #Found using Mailchimp Playground API
      group_huntspecials_id = "11134d3a3b"
      group_statereminders_id = "b66afdefe9"
      group_products_id = "99096a057f"
      group_rifles_id = "c96022ad6d"
      group_newsletters_id = "90795561f5"

      #looks like some booleans are coming in as strings.
      user.subscriptions.statereminders_email = false if user.subscriptions.statereminders_email is 'false'
      user.subscriptions.hunts = false if user.subscriptions.hunts is 'false'
      user.subscriptions.products = false if user.subscriptions.products is 'false'
      user.subscriptions.rifles = false if user.subscriptions.rifles is 'false'
      user.subscriptions.newsletters = false if user.subscriptions.newsletters is 'false'

      user.subscriptions.statereminders_email = true if user.subscriptions.statereminders_email is 'true'
      user.subscriptions.hunts = true if user.subscriptions.hunts is 'true'
      user.subscriptions.products = true if user.subscriptions.products is 'true'
      user.subscriptions.rifles = true if user.subscriptions.rifles is 'true'
      user.subscriptions.newsletters = true if user.subscriptions.newsletters is 'true'

      if user.subscriptions.statereminders_email or user.subscriptions.hunts or user.subscriptions.products or user.subscriptions.rifles or user.subscriptions.newsletters
        status = "subscribed"
      else
        status = "unsubscribed"
      #TODO: THESE ARE MC API OBJECTS....HOPEFULLY WE CAN USE THESE
      merge_fields = {
        "FNAME": user.first_name
        "LNAME": user.last_name
      }
      interests = {}
      interests[group_huntspecials_id] = false
      interests[group_statereminders_id] = false
      interests[group_products_id] = false
      interests[group_rifles_id] = false
      interests[group_newsletters_id] = false

      interests[group_huntspecials_id] = true if user.subscriptions.hunts is true
      interests[group_statereminders_id] = true if user.subscriptions.statereminders_email is true
      interests[group_products_id] = true if user.subscriptions.products is true
      interests[group_rifles_id] = true if user.subscriptions.rifles is true
      interests[group_newsletters_id] = true if user.subscriptions.newsletters is true

      fieldsToUpdate = Object.keys(user.subscriptions)
      delete interests[group_huntspecials_id] unless fieldsToUpdate.indexOf("hunts") > -1
      delete interests[group_statereminders_id] unless fieldsToUpdate.indexOf("statereminders_email") > -1
      delete interests[group_products_id] unless fieldsToUpdate.indexOf("products") > -1
      delete interests[group_rifles_id] unless fieldsToUpdate.indexOf("rifles") > -1
      delete interests[group_newsletters_id] unless fieldsToUpdate.indexOf("newsletters") > -1

      body = {
        email_address: user.email.toLowerCase()
        status_if_new: status
        status: status
        email_type: "html"
        merge_fields: merge_fields
        interests: interests
      }
      console.log "Mailchimp: sending member update profile request. Body: ", body

      MailChimp.put "/lists/#{mc_listId}/members/#{emailhash}", body, (err, results) ->
        #console.log "Mailchimp: upsert member results: ", err, results
        return cb err, results

    #Return the mailing lists that exist in mail chimp. We really only want one master list.  Use groups and tags to organize it.
    getLists: (cb) ->
      MailChimp.get '/lists', null, (err, results) ->
        return cb err if err
        return cb "No lists found" unless results?.lists?.length
        return cb null, results.lists

    #Given an Mail Chimp list's id, retrieve all members (sub, unsubscribed, invalid(cleaned) all included)
    getUsers: (mc_listId, cb) ->
      mc_listId = MailChimpMasterListId if mc_listId is "MASTER" or !mc_listId
      MailChimp.get "/lists/#{mc_listId}/members", null, (err, results) ->
        return cb err if err
        return cb null, [] unless results?.members?.length
        return cb null, results.members

    #Given a Mail Chimp user based on email
    getUser: (email, mc_listId, cb) ->
      emailhash = crypto.createHash('md5').update(email.toLowerCase()).digest("hex")
      mc_listId = MailChimpMasterListId if mc_listId is "MASTER" or !mc_listId
      MailChimp.get "/lists/#{mc_listId}/members/#{emailhash}", null, (err, results) ->
        return cb err if err
        return cb null, results

    #Return Groups for a given list
    getGroups: (mc_listId, cb) ->
      interestId = "6c8676b823" #Found using Mailchimp Playground API
      mc_listId = MailChimpMasterListId if mc_listId is "MASTER" or !mc_listId
      MailChimp.get "/lists/#{mc_listId}/interest-categories/#{interestId}", null, (err, results) ->
        return cb err if err
        return cb null, [] unless results
        return cb null, results

    getTenantEmailPreferences: (tenant) ->
      tenantData = {
        TEMPLATE_PREFIX: ""
        EMAIL_FROM: RBO_EMAIL_FROM
        EMAIL_FROM_NAME: RBO_EMAIL_FROM_NAME
      }
      tenantData.TEMPLATE_PREFIX = tenant.email_template_prefix.trim() if tenant?.email_template_prefix
      tenantData.TEMPLATE_PREFIX = tenant.tmp_email_template_prefix.trim() if tenant?.tmp_email_template_prefix
      tenantData.EMAIL_FROM = tenant.email_from.trim() if tenant?.email_from
      tenantData.EMAIL_FROM_NAME = tenant.email_from_name.trim() if tenant?.email_from_name
      tenantData.EMAIL_FROM_NAME = tenant.tmp_email_from_name.trim() if tenant?.tmp_email_from_name
      return tenantData

    #Send Mandrill Email
    sendEmail: (tenant, template_name, subject, to, payload, company, description, send_async, preserve_recipients, cb) ->
      tenantData = @getTenantEmailPreferences(tenant)
      template_name = "#{tenantData.TEMPLATE_PREFIX} #{template_name}"

      to = [to] unless to instanceof Array

      useTestValues = true
      hardCodedEmailTest = "scott@rollingbonesoutfitters.com"
      hardCodedEmailName = "Scott Wallace"
      if useTestValues
        for item in to
          item.email = hardCodedEmailTest
          item.name = hardCodedEmailName

      if send_async? and send_async is false
        send_async = false
      else
        send_async = true
      preserve_recipients = false unless preserve_recipients is true
      template_content = [{
        "name": "test name",
        "content": "test content"
      }]
      global_merge_vars = [
        { name: "ARCHIVE", content: "test"}
      ]
      if tenant?.name
        company = tenant.name unless company and tenant?.name
        description = "You are receiving this email as a service from #{tenant.name} #{tenant.url}" unless description
      else
        company = "Rolling Bones"
        description = "You are receiving this email as a service from Rolling Bones https://www.rollingbonesoutfitters.com/" unless description
      merge_vars = [
        { name: "LIST_COMPANY", content: company}
        { name: "LIST_DESCRIPTION", content: description}
      ]
      for key in Object.keys(payload)
        merge_vars.push {name: key, content: payload[key]}

      #{ name: "reminder_start", content: moment(reminder.start).format("L")}  format date
      message = {}
      message.track_clicks = true
      message.track_opens = true
      message.inline_css = true
      message.url_strip_qs = true
      message.preserve_recipients = preserve_recipients
      message.view_content_link = true
      message.from_email = tenantData.EMAIL_FROM
      message.from_name = tenantData.EMAIL_FROM_NAME
      message.to = to
      message.subject = subject
      message.global_merge_vars = global_merge_vars
      message.merge_vars = []
      for item in to
        message.merge_vars.push {"rcpt": item.email, "vars": merge_vars}
      mandrillSuccess = (result) ->
        console.log("\n")
        console.log "***** mandrill response:"
        console.log result
        console.log("\n")
        cb(null, result) if cb
        return
      mandrillError = (error) ->
        # Mandrill returns the error as an object with name and message keys
        console.log "A mandrill error occurred: " + error.name + " - " + error.message
        cb(error) if cb
        return
      #console.log "Sending Mandrill email: ", template_name, template_content, message, send_async
      rbo_mandrill_client.messages.sendTemplate
        template_name: template_name
        template_content: template_content
        message: message
        async: send_async
      , mandrillSuccess, mandrillError

  }

  _.bindAll.apply _, [mailchimpapi].concat(_.functions(mailchimpapi))
  return mailchimpapi
