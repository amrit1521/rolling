_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/reminder-cron.coffee false false false all 1/15/2019 5684a2fc68e9aa863e7bf182
#./node_modules/coffeescript/bin/coffee scripts/custom/rbo/reminder-cron.coffee false false false all today 5684a2fc68e9aa863e7bf182 2>&1 | tee /Users/scottwallace/repos/GMT/gotmytag/tmp/reminder-cron.log
#coffee /var/www/gotmytag/scripts/custom/rbo/reminder-cron.coffee false false false all today 5684a2fc68e9aa863e7bf182 2>&1 | tee /home/ubuntu/tmp/reminder-cron.log


TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO
#TENANT_ID = "5bd75eec2ee0370c43bc3ec7" #TEST
REMINDER_TENANT_ID = "5684a2fc68e9aa863e7bf182" #RBO

log_message_string = ""
log = (msg, capture) ->
  console.log msg
  return unless capture
  log_message_string = "#{log_message_string}\n#{msg}"

#ARG 1
SEND = false
SEND = true if process.argv?.length > 1 and process.argv[2] is "true"
log "SEND: #{SEND}", true

#ARG 2
FLAG_AS_SENT = false
FLAG_AS_SENT = true if process.argv?.length > 2 and process.argv[3] is "true"
log "FLAG_AS_SENT: #{FLAG_AS_SENT}", true

#ARG 3
FORCE_RESEND = false
FORCE_RESEND = true if process.argv?.length > 3 and process.argv[4] is "true"
log "FORCE_RESEND: #{FORCE_RESEND}", true

#ARG 4
TYPE_TO_SEND = "all"
TYPE_TO_SEND = process.argv[5] if process.argv?.length > 4
log "TYPE_TO_SEND: #{TYPE_TO_SEND}", true

#ARG 5
RUN_DATE = moment()
RUN_DATE = new Date(process.argv[6]) if process.argv?.length > 5 and process.argv[6] isnt 'today'
startDate = moment(RUN_DATE)
endDate = moment(RUN_DATE).add(2, 'days')
log "RUN_DATE: #{RUN_DATE}", true

#ARG 6
#REMINDER_TENANT_ID = process.argv[7] if process.argv?.length > 6
log "REMINDER_TENANT_ID: #{REMINDER_TENANT_ID}", true


config.resolve (
  reminders
  User
  Reminder
  Message
  Tenant
  mailchimpapi
) ->

  reminders_ctrl = reminders
  remindersCount = 0
  userCount = 0
  userTotal = 0
  totalNotifications = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  skipList = "xxx,yyy"
  skipList = ""

  tenant = null

  sendEmail = (success, log_message_string, cb) ->
    if success
      log_message_string = "State Applications Sent Successfully: #{log_message_string}"
    else
      log_message_string = "State Applications FAILED WITH ERROR: #{log_message_string}"
    template_name = "Server Message"
    subject = "State Application Reminders Sent"
    mandrilEmails = []
    to = {
      email: "scott@rollingbonesoutfitters.com"
      type: "to"
    }
    mandrilEmails.push to if to
    payload = {
      source: "reminder-cron.coffee"
      message: log_message_string
    }
    mailchimpapi.sendEmail tenant, template_name, subject, mandrilEmails, payload, null, null, null, false, cb

  log "#{moment().format('MM/DD/YYYY, h:mm:ss a')}", true
  log "Starting state application reminders send", true
  log "Retrieving Reminders that start send on: #{startDate.format('MM/DD/YYYY')}, and end send on: #{endDate.format('MM/DD/YYYY')}", true
  #The following are variables to be set because can't seem to be able to set and pass them through mapSeries?
  reminders_start = []
  reminders_end = []
  users = []
  reminder = null
  type = null  #emailStart, emailEnd, txtStart, txtEnd, appStart, appEnd
  source = "Reminder" #Reminder, DrawResult
  year = new Date().getFullYear().toString()

  checkSendMessage = (reminder, user, key, cb) ->
    return cb null, false, "SEND set to false." unless SEND
    return cb null, true, "FORCE_RESEND set to true." unless !FORCE_RESEND

    if type is "emailStart" or type is "emailEnd"
      return cb null, false, "Missing email for userId #{user._id}" unless user.email
    else if type is "txtStart" or type is "txtEnd"
      return cb null, false, "Missing cell phone number for userId #{user._id}" unless user.phone_cell
    Message.byUnique key, type, year, source, reminder._id, TENANT_ID, (err, message) ->
      return cb err if err
      reason = ""
      if not message? or message.length is 0
        sendIt = true
        reason = "User has not received this notification yet."
      else
        sendIt = false
        reason = "Notification already sent to this user on: #{message.sent}, messageId: #{message._id}"
      return cb null, sendIt, reason


  flagUserReminderAsSent = (reminder, user, key, cb) ->
    messageData = {
      key: key, type: type, year: year, source: source, sourceId: reminder._id, tenantId: TENANT_ID, state: reminder.state, reminderId: reminder._id, userId: user._id
    }
    if FLAG_AS_SENT
      #log "Marking user reminder as sent. key: #{messageData.key}, reminderId: #{reminder._id}", true
      Message.upsert messageData, (err, message) ->
        return cb err, message
    else
      #log "NOT marking user reminder as sent.  Message update would have been: #{messageData}", true
      return cb null, messageData

  processUser = (user, done) ->
    userCount++
    totalNotifications++
    log ""
    log "***Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}, email: #{user.email}, cell: #{user.phone_cell}"
    if skipList.indexOf(user._id.toString()) > -1
      log "Skipping user from skip list."
      return done null, user
    if type is "emailStart" or type is "emailEnd"
      key = user.email
    else if type is "txtStart" or type is "txtEnd"
      key = user.phone_cell
    else
      return done "invalid type: #{type} encountered."
    checkSendMessage reminder, user, key, (err, sendIt, reason) ->
      return done err if err
      if sendIt
        reminders_ctrl.sendFromScript reminder, user, type, (err, result) ->
          if err
            log "ERROR!!!: Email failed to send for userId: #{user._id}, reminderId: #{reminder._id}, error: #{err}"
            return done null, result #DON"T RETURN AN ERROR, IT WILL STOP ALL OTHER USERS FROM BEING PROCESSED
          else
            log "Email Successfully sent for userId: #{user._id}, reminderId: #{reminder._id}, result: #{result}"
            flagUserReminderAsSent reminder, user, key, (err, message) ->
              return done err, message
      else
        log "SKIPPING Email or Text message for userId: #{user._id}, reminderId: #{reminder._id}, reason: #{reason}"
        return done err, {user_name: user.name, user_id: user._id, reminder_title: reminder.title, reminder_id: reminder._id, reminder_type: type}


  processReminder = (tReminder, done) ->
    reminder = tReminder
    remindersCount++
    log ""
    log "****************************************Processing #{reminder.title}, #{reminder._id}, Type: #{type},  #{moment(new Date(reminder.start)).format("L")} - #{moment(new Date(reminder.end)).format("L")}", true
    users = []
    state = [reminder.state]
    if type is 'emailStart' or type is 'emailEnd'
      reminderType = 'email'
    else if type is 'txtStart' or type is 'txtEnd'
      reminderType = 'text'
    else
      return done "Invalid type: #{type} encountered."
    User.idsByReminderStates reminderType, state, TENANT_ID, {internal: false}, (err, users_rsp) ->
      users = users_rsp
      log "Found #{users.length} users wanting reminders for state: #{state}", true
      userTotal = users.length
      userCount = 0
      async.mapSeries users, processUser, (err, results) ->
        return done err



  #SEND START REMINDERS
  async.waterfall [

    # Get tenant
    (next) ->
      Tenant.findById REMINDER_TENANT_ID, (err, t_tenant) ->
        return next err if err
        return next "Unable to find tenant for tenantId: #{REMINDER_TENANT_ID}" unless t_tenant
        tenant = t_tenant
        return next null

    # Get reminders by start
    (next) ->
      Reminder.startsOn startDate, REMINDER_TENANT_ID, (err, reminders_start_rsp) ->
        reminders_start = reminders_start_rsp if reminders_start_rsp
        log "Found #{reminders_start.length} to send open on #{startDate.format('MM/DD/YYYY')} #{_.pluck(reminders_start, 'title')}", true
        return next err

    # Get reminders by end
    (next) ->
      Reminder.endsOn endDate, REMINDER_TENANT_ID, (err, reminders_end_rsp) ->
        reminders_end = reminders_end_rsp if reminders_end_rsp
        log "Found #{reminders_end.length} to send end on #{endDate.format('MM/DD/YYYY')} #{_.pluck(reminders_end, 'title')}", true
        return next err

    # Send Start Reminders emails
    (next) ->
      type = "emailStart"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      async.mapSeries reminders_start, processReminder, (err, sent_start_reminders) ->
        return next err

    # Send Start Reminders texts
    (next) ->
      type = "txtStart"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      async.mapSeries reminders_start, processReminder, (err, sent_start_reminders) ->
        return next err


    # Send End Reminders emails
    (next) ->
      type = "emailEnd"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      async.mapSeries reminders_end, processReminder, (err, sent_end_reminders) ->
        return next err

    # Send End Reminders texts
    (next) ->
      type = "txtEnd"
      return next null unless TYPE_TO_SEND is "all" or TYPE_TO_SEND is type
      async.mapSeries reminders_end, processReminder, (err, sent_end_reminders) ->
        return next err

  ], (err) ->
    success = true
    log ""
    log ""
    log "Finished running reminder-cron script.", true
    log "#{moment().format('MM/DD/YYYY, h:mm:ss a')}", true
    if err
      console.error "Found an error, existing.", err
      log "Found an error, existing. #{err}", true
      success = false

    if success
      for reminder in reminders_start
        log "Successfully sent Start Reminder Title: #{reminder.title}, ReminderId: #{reminder._id}", true
      for reminder in reminders_end
        log "Successfully sent End Reminder Title: #{reminder.title}, ReminderId: #{reminder._id}", true
      log "Total notifications: #{totalNotifications}", true

      sendEmail success, log_message_string, (err, results) ->
        process.exit(0)
    else
      sendEmail success, log_message_string, (err, results) ->
        process.exit(1)
