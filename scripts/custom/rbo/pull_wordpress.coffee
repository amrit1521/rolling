_ = require 'underscore'
async = require "async"
moment    = require 'moment'
config = require '../../../config'
mysql = require 'mysql'

parseTools = require '../../../lib/ParseTools'
parseTools = parseTools()



config.resolve (
  User
  rboDB
  RollingBonesTenantId
  ServiceRequest
) ->

  rboDB.connect()

  GET_USERS = false
  GET_LEADS = true
  LIMIT_RESULTS = -1
  NEW_REQUEST_ONLY = true
  #RollingBonesTenantId = "54a8389952bf6b5852000007" #hard coded debug to dev

  limitClause = ""
  limitClause = " LIMIT #{LIMIT_RESULTS}" if LIMIT_RESULTS > 0

  sql_queryAllUsers = "SELECT ID FROM rbo_users order by date_created desc #{limitClause} "
  sql_queryAllLeads = "SELECT ID FROM rbo_rg_lead order by date_created desc #{limitClause}"
  sql_queryById = "SELECT * FROM ?? WHERE id = ?"
  sql_queryByUserId = "SELECT * FROM ?? WHERE user_id = ?"
  sql_queryByLeadId = "SELECT * FROM ?? WHERE lead_id = ?"
  sql_queryByFormId = "SELECT * FROM ?? WHERE form_id = ?"

  convert_sql_json = (mySqlObj) ->
    return JSON.parse(JSON.stringify(mySqlObj))[0] #converts from mysql RowDataObject to json object

  getWordpressLead = (leadId, done) ->
    leadId = leadId.ID if typeof leadId is "object"

    async.waterfall [
      # First from rbo_rg_lead table
      (next) ->
        sql = mysql.format(sql_queryById, ['rbo_rg_lead', leadId])
        console.log(sql)
        rboDB.query sql, (err, lead, fields) ->
          return next err if err
          lead = convert_sql_json(lead)
          return next null, lead

      # Get extended fields from rbo_rg_lead_detail
      (lead, next) ->
        sql = mysql.format(sql_queryByLeadId, ['rbo_rg_lead_detail', leadId])
        console.log(sql)
        rboDB.query sql, (err, leadDetails, fields) ->
          return next err if err
          for leadDetail in leadDetails
            fieldNum = "FieldNum:#{leadDetail.field_number}"
            #console.log "leadDetail.field_number, leadDetail.value", leadDetail.field_number, leadDetail.value
            lead[fieldNum] = leadDetail.value
          return next null, lead

      #Get form data
      (lead, next) ->
        sql = mysql.format(sql_queryById, ['rbo_rg_form', lead.form_id])
        console.log(sql)
        rboDB.query sql, (err, form, fields) ->
          return next err if err
          form = convert_sql_json(form)
          lead.form_title = form.title
          return next null, lead

      #Get form meta data fields
      (lead, next) ->
        sql = mysql.format(sql_queryByFormId, ['rbo_rg_form_meta', lead.form_id])
        console.log(sql)
        rboDB.query sql, (err, form, fields) ->
          return next err if err
          form = convert_sql_json(form)
          display_meta = form.display_meta
          fields = JSON.parse(display_meta).fields
          lead.form_fields = fields
          return next null, lead

      #Convert lead fields to form meta real names
      (lead, next) ->
        formMap = []
        #Get form fields ids and real labels
        for field in lead.form_fields
          if field.inputs
            for input in field.inputs
              formMap[input.id] = input.label
          else
            formMap[field.id] = field.label

        #Now swap out the indexes with real labels and clean out the lead fields
        for key, value of lead
          keyParts = key.split(":")
          if keyParts.length is 2
            keyNum = keyParts[1]
            realLabel = formMap[keyNum]
            if realLabel
              lead[realLabel] = value
              delete lead[key]
            else
              console.log "Error: Could not find real label for:"
              console.log "keyNum", keyNum
              console.log "label", realLabel
              console.log "map", formMap

        delete lead.form_fields
        return next null, lead

    ], (err, lead) ->
      return done err, lead

  getWordpressLeads = (done) ->
    leads = []
    rboDB.query sql_queryAllLeads, (err, leadsTmp, fields) ->
      return done err if err
      async.mapSeries leadsTmp, getWordpressLead, (err, leads) ->
        return done err, leads


  getWordpressUser = (userId, done) ->
    userId = userId.ID if typeof userId is "object"
    #first from rbo_users table
    sql = mysql.format(sql_queryById, ['rbo_users', userId])
    console.log(sql)
    rboDB.query sql, (err, user, fields) ->
      return done err if err
      user = convert_sql_json(user)

      #then extended fields from rbo_usermeta
      sql = mysql.format(sql_queryByUserId, ['rbo_usermeta', userId])
      console.log(sql)
      rboDB.query sql, (err, userDetails, fields) ->
        return done err if err
        for userDetail in userDetails
          user[userDetail.meta_key] = userDetail.meta_value

        return done null, user

  getWordpressUsers = (done) ->
    users = []
    rboDB.query sql_queryAllUsers, (err, usersTmp, fields) ->
      return done err if err
      async.mapSeries usersTmp, getWordpressUser, (err, users) ->
        return done err, users

  RADSImportRequests = (WordpressRequests, cb) ->

    importServiceRequest = (wpRequest, done) ->
      console.log "Importing wordpress request:", wpRequest.id
      ServiceRequest.byExternalId wpRequest.id, RollingBonesTenantId, (err, request) ->
        return done err if err

        if NEW_REQUEST_ONLY
          console.log "request already imported, skipping." if request
          return done null, request if request
        else
            if request
              console.log "updating a previously imported service request:", wpRequest
            else
              console.log "creating new service request:", wpRequest

        requestData = {
          tenantId: RollingBonesTenantId
        }
        requestData.external_id = wpRequest.ID             if wpRequest.ID
        requestData.memberId = wpRequest['Member ID']      if wpRequest['Member ID']
        requestData.type = wpRequest.form_title            if wpRequest.form_title
        requestData.first_name = wpRequest.First           if wpRequest.First
        requestData.last_name = wpRequest.Last             if wpRequest.Last
        requestData.address = wpRequest['Street Address']  if wpRequest['Street Address']
        requestData.city = wpRequest.City                  if wpRequest.City
        requestData.country = wpRequest.Country            if wpRequest.Country
        requestData.postal = wpRequest['ZIP / Postal Code'] if wpRequest['ZIP / Postal Code']
        requestData.state = wpRequest['State / Province']  if wpRequest['State / Province']
        requestData.email = wpRequest.Email.toLowerCase()  if wpRequest.Email
        requestData.phone = wpRequest.Phone                if wpRequest.Phone
        requestData.species = wpRequest.Species            if wpRequest.Species
        requestData.location = wpRequest.Location          if wpRequest.Location
        requestData.weapon = wpRequest.Weapon              if wpRequest.Weapon
        requestData.budget = wpRequest.Budget              if wpRequest.Budget
        requestData.referral_source = wpRequest['Where did you hear about us?'] if wpRequest['Where did you hear about us?']
        requestData.referral_ip = wpRequest.ip             if wpRequest.ip
        requestData.referral_url = wpRequest.source_url    if wpRequest.source_url
        requestData.message = wpRequest.Message            if wpRequest.Message
        requestData.newsletter = if wpRequest['I would also like to subscribe to the Rolling Bones Insights email newsletter.'] is 'I would also like to subscribe to the Rolling Bones Insights email newsletter.' then true else false
        requestData.specialOffers = if wpRequest['I would also like to receive information about special offers and hunt opportunities.'] is 'I would also like to receive information about special offers and hunt opportunities.' then true else false
        requestData.external_date_created = wpRequest.date_created if wpRequest.date_created

        requestData.state = parseTools.states[requestData.state.toUpperCase()] if requestData.state?.length and parseTools.states[requestData.state.toUpperCase()]
        requestData.address = requestData.address + "    " +  wpRequest['Address Line 2'] if wpRequest['Address Line 2'] and wpRequest['Address Line 2']?.toLowerCase().indexOf('none') is -1

        #These are additional fields mapping to the same value but different on different forms
        requestData.memberId = wpRequest['Membership ID (if applicable):'] if !requestData.memberId and wpRequest['Membership ID (if applicable):']
        requestData.external_id = wpRequest.id if !requestData.externalId and wpRequest.id
        requestData.referral_source = wpRequest['How did you hear about us?'] if !requestData.referral_source and wpRequest['How did you hear about us?']
        requestData.email = wpRequest['Primary Contact Email'].toLowerCase() if !requestData.email and wpRequest['Primary Contact Email']
        requestData.phone = wpRequest['Primary Contact Phone'] if !requestData.phone and wpRequest['Primary Contact Phone']

        #Check if user exists and import the service request
        async.waterfall [
          # Check by MemberId
          (next) ->
            return next null, null unless requestData.memberId
            User.byMemberId requestData.memberId, RollingBonesTenantId, (err, user) ->
              console.log "Wordpress contained member id not found in RADs.  Member Id: #{requestData.memberId}" unless user
              return next err, user

          # By Name and email
          (user, next) ->
            return next null, user if user
            userData = {
              first_name :requestData.first_name
              last_name :requestData.last_name
              email: requestData.email
            }
            User.matchUser ['first_name', 'last_name', 'email'], userData, RollingBonesTenantId, (err, users) ->
              console.log "user not found for first_name: #{requestData.first_name} and last_name: #{requestData.last_name}" unless users?.length
              return next null, null unless users?.length
              for user in users
                return next null, user if user.clientId
              return next null, users[0]

        ], (err, user) ->
          console.log "Error:", err if err
          return done err if err


          checkContactDiffs = (requestData, user) ->
            contactDiffs = ""
            if requestData.first_name?.length and user.first_name?.length
              contactDiffs = "#{contactDiffs}Request First Name: #{requestData.first_name}, RADS User First Name: #{user.first_name}\n" if requestData.first_name.toLowerCase() isnt user.first_name.toLowerCase()
            if requestData.last_name?.length and user.last_name?.length
              contactDiffs = "#{contactDiffs}Request Last Name: #{requestData.last_name}, RADS User Last Name: #{user.last_name}\n" if requestData.last_name.toLowerCase() isnt user.last_name.toLowerCase()
            if requestData.email?.length and user.email?.length
              contactDiffs = "#{contactDiffs}Request Email: #{requestData.email}, RADS User Email: #{user.email}\n" if requestData.email.toLowerCase() isnt user.email.toLowerCase()
            if requestData.phone?.length
              contactDiffs = "#{contactDiffs}Request Phone: #{requestData.phone}, RADS User Phones: #{user.phone_cell}, #{user.phone_home}, #{user.phone_day}\n" if requestData.phone isnt user.phone_cell and requestData.phone isnt user.phone_day and requestData.phone isnt user.phone_home
            if requestData.address?.length and user.address?.length
              contactDiffs = "#{contactDiffs}Request Address: #{requestData.address}, RADS Physical Address: #{user.physical_address}\n" if requestData.address isnt user.physical_address
            if requestData.city?.length and user.physical_city?.length
              contactDiffs = "#{contactDiffs}Request City: #{requestData.city}, RADS Physical City: #{user.physical_city}\n" if requestData.city.toLowerCase() isnt user.physical_city.toLowerCase()
            if requestData.state?.length and user.physical_state?.length
              contactDiffs = "#{contactDiffs}Request State: #{requestData.state}, RADS Physical State: #{user.physical_state}\n" if requestData.state.toLowerCase() isnt user.physical_state.toLowerCase()
            if requestData.postal?.length and user.physical_postal?.length
              contactDiffs = "#{contactDiffs}Request Zip: #{requestData.postal}, RADS Physical Zip: #{user.physical_postal}\n" if requestData.postal isnt user.physical_postal
            if requestData.country?.length and user.physical_country?.length
              contactDiffs = "#{contactDiffs}Request Country: #{requestData.country}, RADS Physical Country: #{user.physical_country}\n" if requestData.country.toLowerCase() isnt user.physical_country.toLowerCase()
            return contactDiffs if contactDiffs?.length > 0
            return null


          upsertServiceRequest = (requestData, done) ->
            #Import the service request
            ServiceRequest.upsert requestData, (err, serviceRequest) ->
              return done err if err
              console.log "successfully imported serviceRequest: ", serviceRequest
              console.log ""
              console.log ""
              return done null, serviceRequest


          if user
            console.log "Found existing user, attaching service request"
            requestData.userId = user._id
            requestData.clientId = user.clientId
            diffs = checkContactDiffs(requestData, user)
            requestData.contactDiffs = diffs if diffs
            upsertServiceRequest(requestData, done)

          else
            console.log "User not found for this service request"
            userData = _.pick requestData, ['memberId', 'first_name', 'last_name', 'email']
            userData.tenantId = RollingBonesTenantId
            userData.source = "Dashboard"
            userData.imported = "RBO_WordpressRequest"
            userData.type = "local"
            userData.physical_address = requestData.address if requestData.address
            userData.physical_city = requestData.city if requestData.city
            userData.physical_state = requestData.state if requestData.state
            userData.physical_postal = requestData.postal if requestData.postal
            userData.physical_country = requestData.country if requestData.country
            userData.phone_cell = requestData.phone if requestData.phone
            userData.phone_home = requestData.phone if requestData.phone
            userData.needsWelcomeEmail = true
            userData.parentId = "5988a183c189c88ea6113ea8"  #Default RBO Acct


            if userData.first_name and userData.last_name and userData.email
              console.log "Creating new user", userData
              #Insert the new user
              User.upsert userData, {internal: false, upsert: true}, (err, user) ->
                return done err if err
                console.log "Failed to create a new user for this service request" unless user
                if user
                  requestData.userId = user._id
                  requestData.clientId = user.clientId if user.clientId
                  diffs = checkContactDiffs(requestData, user)
                  requestData.contactDiffs = diffs if diffs
                upsertServiceRequest(requestData, done)
            else
              console.log "NOT ENOUGH INFORMATION TO CREATE A NEW USER", userData
              console.log "Inserting Service Request without tieing it to a user"
              upsertServiceRequest(requestData, done)


    console.log "Found #{WordpressRequests.length} wordpress requests to import."
    async.mapSeries WordpressRequests, importServiceRequest, (err, requests) ->
      return cb err, requests



  async.waterfall [
    # Get users
    (next) ->
      return next null, null #TODO: only do this to test hardcoded single id
      return next null, null unless GET_USERS
      console.log 'get all rbo wordpress users'
      getWordpressUsers (err, users) ->
        return next err if err
        return next null, users

    # Test one users
    (users, next) ->
      return next null, users if users
      return next null, null unless GET_USERS
      console.log 'just getting one user'
      getWordpressUser "222", (err, user) ->
        return next err if err
        return next null, [user]

    # For each user, do stuff
    (users, next) ->
      return next null, null unless GET_USERS
      console.log "found #{users.length} users"
      for user in users
        console.log "FOUND MISSING USER", user.first_name, user.last_name unless user.rads_id
      return next null, users

    # Get Leads
    (users, next) ->
      #return next null, null #TODO: only do this to test hardcoded single id
      return next null, null unless GET_LEADS
      console.log 'get all rbo wordpress leads'
      getWordpressLeads (err, leads) ->
        return next err if err
        return next null, leads

    # Test one lead
    (leads, next) ->
      return next null, leads if leads
      return next null, null unless GET_LEADS
      console.log 'just getting one lead'
      getWordpressLead "601", (err, request) ->
        return next err if err
        return next null, [request]

    # For each request, do stuff
    (requests, next) ->
      #console.log "REQUESTS:", requests
      return next null, null unless GET_LEADS
      RADSImportRequests requests, (err, requests) ->
        return next err

  ], (err) ->
    console.log "Finished"
    rboDB.end()
    if err
      console.log "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
