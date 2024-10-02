_ = require 'underscore'
async = require "async"
config = require '../config'
ejs = require "ejs"

config.resolve (
  DrawResult
  logger
  User
  mandrill_client
) ->

  EMAIL_FROM = "support@gotmytag.com"
  EMAIL_FROM_NAME = "PointHunter"

  TESTMODE = true #if true, won't actually send notifications, just logs.  If false, notifications will be sent.

  #tenantId = "52c5fa9d1a80b40fd43f2fdd" #HuntinFool
  tenantId = "53a28a303f1e0cc459000127" #GotMyTag

  #hardCodedDrawResult = ["56be187a4cc41c270343a845"] #Byron Id
  drawresultsCounter = 0
  drawresultsTotal = 0
  emailsTotal = 0
  textsTotal = 0
  inAppTotal = 0


  states = [
#    {
#       name: "Arizona"
#       id: "52aaa4cae4e055bf33db6499"
#    }
#    {
#      name: "California"
#      id: "52aaa4cbe4e055bf33db64a2"
#    }
#    {
#      name: "Colorado"
#      id: "52aaa4cae4e055bf33db649a"
#    }
#    {
#      name: "Idaho"
#      id: "52aaa4cbe4e055bf33db649b"
#    }
#    {
#      name: "Iowa"
#      id: "536d28a03e9cb9f28859f2ee"
#    }
#    {
#      name: "Kansas"
#      id: "536d28a83e9cb9f28859f2ef"
#    }
#    {
#      name: "Montana"
#      id: "52aaa4cbe4e055bf33db649c"
#    }
#    {
#      name: "Nevada"
#      id: "52aaa4cbe4e055bf33db649d"
#    }
#    {
#      name: "New Mexico"
#      id: "52aaa4cbe4e055bf33db649e"
#    }
#    {
#      name: "Oregon"
#      id: "52aaa4cbe4e055bf33db64a1"
#    }
#
#    {
#      name: "Texas"
#      id: "536d28ab3e9cb9f28859f2f0"
#    }
#    {
#      name: "Utah"
#      id: "52aaa4cbe4e055bf33db649f"
#    }
#    {
#      name: "Washington"
#      id: "52aaa4d2e4e055bf33db64a3"
#    }
    {
      name: "Wyoming"
      id: "52aaa4cbe4e055bf33db64a0"
    }
  ]

  sendEmail = (email, user, cb) ->
    to =
      email: user.email
      type: "to"
    to.name = user.name if user.name
    _sendEmail to, email, cb

  _sendEmail = (to, email, cb) ->
    to = [to] unless to instanceof Array

    message =
      text: email.text
      from_email: EMAIL_FROM
      from_name: EMAIL_FROM_NAME
      to: to
      track_opens: true
      inline_css: true
      url_strip_qs: true
      preserve_recipients: false
      view_content_link: true
      tags: ['draw_results']

    if email.html
      message.html = email.html
      message.track_clicks = false

    if email.subject
      message.subject = email.subject

    mandrill_client.messages.send
      message: message
      async: true
    , ((result) ->
      console.log result
      cb()
      return

    ), (e) ->
      cb()
      # Mandrill returns the error as an object with name and message keys
      console.log "A mandrill error occurred: " + e.name + " - " + e.message
      return

  sendText = (email, user, cb) ->
    #  Verizon
    #  AT&T
    #  United States Cellular Corp
    #  ##Union Telephone
    #  Sprint
    #  T-Mobile
    #  Virgin Mobile
    #  ##CellCom
    #  verizon
    #  tmobile
    #  invalid
    #  Boost-CDMA
    #  ##Bandwidth.com
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
      "at&t": '@txt.att.net' # AT&T
      "bellmobility": '@txt.bellmobility.ca'
      "virgin_mobile": '@vmobl.com' # Virgin Mobile
      "verizon": '@vtext.com' # Verizon
    }

    return cb() unless user.phone_cell

    to = []
    if user.phone_cell_carrier?.length && providers[user.phone_cell_carrier]
      ignoreCarriers = ['landline', 'invalid']
      return cb() if ~ignoreCarriers.indexOf(user.phone_cell_carrier)

      to.push {
        email: user.phone_cell + providers[user.phone_cell_carrier]
        type: "to"
      }
    else
      for provider, email of providers
        to.push {
          email: user.phone_cell + email
          type: "to"
        }

    email.html = null
    email.subject = null
    _sendEmail to, email, cb


  notifyDrawResult = (drawresult, cb) ->
    drawresultsCounter++
    console.log ""
    console.log "Processing draw result #{drawresult._id} - #{drawresultsCounter} of #{drawresultsTotal}"
    console.log drawresult

    if drawresult.notified
      console.log "Skipping, Notifications already sent for this draw result."
      return cb null

    console.log "Sending Notifcations for this one..."
    async.waterfall [

      # Get user
      (next) ->
        User.findById drawresult.userId, {internal: true}, (err, user) ->
          return next err if err
          console.log "User: #{user.email}, Email:#{user.reminders.email}, InApp:#{user.reminders.inApp}, Text:#{user.reminders.text}, TenantId:#{user.tenantId}" if user.reminders
          if user?.tenantId?.toString() != tenantId.toString()
            console.log "Skipping, not sending notifications for this tenant."
            return next null, null
          next err, user

      # Send Email Notification
      (user, next) ->
        return next null, user unless user?.reminders?.email
        console.log "Sending email..."
        emailTemplate = {}
        emailTemplate.html = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"><html xmlns=\"http://www.w3.org/1999/xhtml\"><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" /><title>WY Elk Tag Draw Result</title></head><body>Congratulations you drew your Wyoming elk tag.  Unit: #{drawresult.unit}.  <br/><br/>If you want to know if your friends drew then add them to your app and you will get notified if they drew in the future as well.  <br/>Here is the link to the youtube video that shows you how to add others to your app.  <br/><a href=\"https://www.youtube.com/watch?v=5uV-vEeweHc\">https://www.youtube.com/watch?v=5uV-vEeweHc</a>  <br/><br/>If you need a guide call us and we can help.  <br/></body></html>"
        emailTemplate.text = "Congratulations you drew your Wyoming elk tag.  Unit: #{drawresult.unit}.  If you want to know if your friends drew then add them to your app and you will get notified if they drew in the future as well.  Here is the link to the youtube video that shows you how to add others to your app.  https://www.youtube.com/watch?v=5uV-vEeweHc   If you need a guide call us and we can help."
        emailTemplate.subject = "WY Elk Tag Draw Result"
        emailsTotal++
        return next null, user if TESTMODE
        sendEmail emailTemplate, user, (err) ->
          console.log "send email error:", err if err
          return next null, user #don't want to stop processing, just log the error and keep going

      # Send In App
      (user, next) ->
        return next null, user unless user?.reminders?.inApp
        console.log "Sending In-App message..."
        inAppTotal++
        next null, user

      # Send Text
      (user, next) ->
        return next null, user unless user?.reminders?.text
        console.log "Sending text..."
        textsTotal++
        next null

      ], (err) ->
        if err
          console.log "Found an error", err
          cb null
        else
          console.log "Finished"
          cb null

  stateDrawResults = (state, cb) ->
    console.log 'Getting Draw Results for state:', state.name
    DrawResult.bySuccessfulState state.id, (err, drawresults) ->
      return cb err if err
      drawresultsTotal = drawresults.length
      console.log "Found #{drawresultsTotal} to process."

      async.mapSeries drawresults, notifyDrawResult, (err) ->
        cb err


  async.mapSeries states, stateDrawResults, (err) ->
    console.log "Finished"
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      console.log "Total Emails Sent: "+emailsTotal
      console.log "Total Text Sent: "+textsTotal
      console.log "Total InApp Sent: "+inAppTotal
      process.exit(0)

