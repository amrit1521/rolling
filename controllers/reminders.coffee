_ = require "underscore"
async = require "async"
crypto = require "crypto"
moment = require "moment"
amqp        = require "amqp"
request = require "request"



module.exports = (logger, Reminder, QueueConnectionOptions, VerdadTestTenantId, RollingBonesTenantId,
  rbo_mandrill_client, RBO_EMAIL_FROM, RBO_EMAIL_FROM_NAME, User) ->

  Reminders = {

    adminDelete: (req, res) ->
      Reminder.findByIdAndRemove req.param('id'), (err) ->
        if err
          code = 500
          code = err.code if err.code
          return res.json err, code if err

        res.json {success: true}

    adminIndex: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      if req.param('all') and req.param('all') is "true"
        activeOnly = false
        Reminder.byTenant req.tenant._id, activeOnly, (err, reminders) ->
          return res.json err, 500 if err
          res.json {reminders}
      else
        activeOnly = true
        Reminder.byTenant req.tenant._id, activeOnly, (err, reminders) ->
          return res.json err, 500 if err
          res.json {reminders}

    adminSave: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      req.body.tenantId = req.tenant._id
      Reminder.upsert req.body, (err, result) ->
        if err
          code = 500
          code = err.code if err.code
          return res.json err, code if err
        res.json result

    adminTest: (req, res) ->
      return res.json {error: 'testUserId is required.'}, 400 unless req?.body?.testUserId
      return res.json {error: 'Reminder _id is required.'}, 400 unless req?.body?._id

      #SEND DIRECT TO MANDRILL
      async.waterfall [

        #Get the test user
        (next) ->
          User.byId req.body.testUserId, (err, user) ->
            return next "Failed to find user for user id: #{req.body.testUserId}" unless user
            return next err, user

        #Use the reminder from the request, or retrieve the reminder to test
        (user, next) ->
          if req.body?._id
            reminder = req.body
            return next null, user, reminder
          else
            Reminder.byId req.body._id, (err, reminder) ->
              return next "Failed to find reminder for reminder id: #{req.body._id}" unless reminder
              return next err, user, reminder

        #Send reminder email start notification test
        (user, reminder, next) =>
          type = "emailStart"
          @sendFromScript reminder, user, type, (err, results) ->
            return next err, user, reminder


        #Send reminder email end notification test
        (user, reminder, next) =>
          type = "emailEnd"
          @sendFromScript reminder, user, type, (err, results) ->
            return next err, user, reminder

        #Send reminder text start notification test
        (user, reminder, next) =>
          type = "txtStart"
          @sendFromScript reminder, user, type, (err, results) ->
            return next err, user, reminder

        #Send reminder text end notification test
        (user, reminder, next) =>
          type = "txtEnd"
          @sendFromScript reminder, user, type, (err, results) ->
            return next err, user, reminder, results

      ], (err, user, reminder, results) =>
        return res.json {error_msg: 'Test failed to send.', error: err}, 400 if err
        return res.json {results: results, status: "sent"}


    sendFromScript: (reminder, user, type, cb) ->
      template_name = null
      reminder_txt = ""
      subject = "State Application Reminder"

      async.waterfall [
        #Determine if email or text
        (next) ->
          if type is "txtStart"
            reminder_txt = reminder.txtStart
          else if type is "txtEnd"
            reminder_txt = reminder.txtEnd
          if type is "txtStart" or type is "txtEnd"
            template_name = "State Application Deadline Text Msg"
            subject = ""
            return next "Error sending reminder text.  User phone_cell is missing for user: #{user._id}." unless user.phone_cell
            providers = {
              "uscc": '@email.uscc.net' # US Cellular
              "fido": '@fido.ca'
              "alltel": '@message.alltel.com' # Alltel
              "nextel": '@messaging.nextel.com' # Nextel
              "sprint": '@messaging.sprintpcs.com' # Sprint PCS
              "cricket": '@mms.myCricket.com'
              "tracfone": '@mmst5.tracfone.com'
              "telus": '@msg.telus.com'
              "boost_cdma": '@myboostmobile.com' # Boost
              "wind": '@text.windmobile.ca'
              "t_mobile": '@tmomail.net' # T-Mobile
              "t-mobile": '@tmomail.net' # T-Mobile
              "at&t": '@txt.att.net' # AT&T
              "bellmobility": '@txt.bellmobility.ca'
              "virgin_mobile": '@vmobl.com' # Virgin Mobile
              "verizon": '@vtext.com' # Verizon
            }
            if user.phone_cell_carrier?.length
              emailToUse = user.phone_cell + providers[user.phone_cell_carrier]
              if providers[user.phone_cell_carrier]
                return next null, emailToUse
              else
                return next "Error sending reminder text.  Unsupported Cell Phone Carrier: #{user.phone_cell_carrier}."
            else
              # Otherwise Lookup the current carrier for the cell phone.
              # TODO: handle bounces and remove or re-lookup the carrier again as it can change
              url = 'http://www.carrierlookup.com/index.php/api/lookup?key=b883b155c35a95bd1e042fca5bbdd6357f0eb361&number=' + user.phone_cell
              console.log "Missing phone_cell_carrier, using api to try a carrier lookup..."
              request.get {url, json:true}, (err, res, body) ->
                console.log "Carrier api lookup response: ", err, body
                return next err if err
                if body?.Response?.error
                  return next body.Response.error

                if body?.Response?.carrier and body?.Response?.carrier_type is "mobile"
                  user.phone_cell_carrier = body.Response.carrier.toLowerCase()
                else
                  user.phone_cell_carrier = 'error or not mobile'

                if user.phone_cell_carrier?.length and providers[user.phone_cell_carrier]
                  emailToUse = user.phone_cell + providers[user.phone_cell_carrier]
                  userData = {_id: user._id, phone_cell_carrier: user.phone_cell_carrier}
                  User.upsert userData, {upsert: false}, (err, user) ->
                    console.log "Error: ", err if err
                    console.log "Successfully updated phone_cell_carrier for user: ", user._id, user.phone_cell_carrier
                    return next null, emailToUse
                else
                  return next "Error sending reminder text. Unsupported Cell Phone Carrier: #{user.phone_cell_carrier}."


          else if type is "emailStart"
            template_name = "State reminders open"
            return next null, user.email
          else if type is "emailEnd"
            template_name = "State reminders end"
            return next null, user.email
          else
            return next "Error: invalid type: #{type}."

      ], (err, emailToUse) =>
        if err
          console.log "Error sending reminder notification: ", err
          return cb err
        user.email_override = emailToUse
        send_async = false
        to_user = user
        template_content = [{
          "name": "test",
          "content": "test content"
        }];
        global_merge_vars = [
          { name: "LIST_COMPANY", content: "Rolling Bones Outfitters"}
          { name: "COMPANY", content: "Rolling Bones Outfitters"}
        ]
        merge_vars = [
          { name: "LIST_COMPANY", content: "Rolling Bones Outfitters"}
          { name: "LIST_DESCRIPTION", content: "You are receiving this email because you opted in to receive Rolling Bones Outfitters emails at our website www.rollingbonesoutfitters.com"}
          { name: "reminder_state", content: reminder.state}
          { name: "reminder_title", content: reminder.title}
          { name: "reminder_start", content: moment(reminder.start).format("L")}
          { name: "reminder_end", content: moment(reminder.end).format("L")}
          { name: "reminder_txt", content: reminder_txt}
        ]
        #{ name: "mc_unique_email_id", content: reminder.state}  #unique_email_id: '8c2133a7b1' from mailchimp list user API, could be used to update profile link.
        #https://rollnbones.us8.list-manage.com/profile?u=90ac7f5920e312f78efe71f4e&id=c44a86272a&e=8c2133a7b1&orig-lang=1
        #Get the right link from the mailchimp list "sign-up forms" see email update profile form, and hyper link.

        @sendDirectEmail to_user, subject, rbo_mandrill_client, template_name, template_content, global_merge_vars, merge_vars, send_async, (err, results) ->
          return cb err, results


    sendDirectEmail: (to_user, subject, mandrill_client, template_name, template_content, global_merge_vars, merge_vars, send_async, cb) ->
      #SKIP SENDING TO OLD RABBIT MQ QUEUE, GO STRAIGHT TO RBO MANDRILL INSTEAD
      to = []
      toItem = {
        email: to_user.email
        type: "to"
      }
      toItem.email = to_user.email_override if to_user.email_override
      toItem.name = to_user.name if to_user.name
      to.push toItem

      message = {}
      message.track_clicks = true
      message.track_opens = true
      message.inline_css = true
      message.url_strip_qs = true
      message.preserve_recipients = false
      message.view_content_link = true
      message.from_email = RBO_EMAIL_FROM
      message.from_name = RBO_EMAIL_FROM_NAME
      message.to = to
      message.subject = subject
      message.global_merge_vars = global_merge_vars
      message.merge_vars = [{"rcpt": toItem.email, "vars": merge_vars}]

      mandrillSuccess = (result) ->
        console.log ""
        console.log "***** mandrill response:"
        console.log result
        console.log ""
        return cb null, result
      mandrillError = (error) ->
        # Mandrill returns the error as an object with name and message keys
        console.log "A mandrill error occurred: " + error.name + " - " + error.message
        return cb error

      mandrill_client.messages.sendTemplate
          template_name: template_name
          template_content: template_content
          message: message
          async: send_async
        , mandrillSuccess, mandrillError




    byStates: (req, res) ->
      if req.body.tenantId && req.body.states
        Reminder.byStatesTenant req.body.tenantId, req.body.states, (err, results) ->
          if err
            code = 500
            code = err.code if err.code
            return res.json err, code if err
          res.json results
      else
        #keep for backwards compaibility until new app hits the app store
        Reminder.byStates req.body, (err, results) ->
          if err
            code = 500
            code = err.code if err.code
            return res.json err, code if err
          res.json results

  adminRead: (req, res) ->
    return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
    Reminder.byId req.param('id'), (err, reminder) ->
      return res.json err, 500 if err
      res.json {reminder}


  }

  _.bindAll.apply _, [Reminders].concat(_.functions(Reminders))
  return Reminders
