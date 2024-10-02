_ = require 'underscore'
async = require "async"
config = require '../../../config'
winston     = require 'winston'
moment    = require 'moment'
csv = require "csv"
fs = require "fs"


#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/magazine_mailing_list.coffee

CSV_FILE_LOCATION = './tmp/'
UPDATE_USER = false

close = (err) ->
  console.log "Finished"
  if err
    logger.error "Found an error", err
    process.exit(1)
  else
    console.log "Done"
    process.exit(0)

#QUICK example of csv.  Also see node_modules/csv/doc/index.md
###
options = {
    columns: ['a','b','c']
}
data = ['"1","2","3","4","5"',['a','b','c','d','e']]
data = ['x',['a1','b','c','d','e'], 'y',['a11','b','c','d','e']]
data = [['a','b','c','d','e'], ['a2','b','c','d','e'], ['a3','b','c','d','e']]
data = [{a:'1', b:'2'}, {c:'3', d:'4'}]
csv()
  .from.array(data, options)
  .to.path(CSV_FILE_LOCATION+'mailing_addresses.csv')
  .transform (row) ->
    return row
  .on "record", (row, index) ->
    console.log "DEBUG: Index: #{index}, ROW: ", row
  #.to (data) ->
  #  console.log "to data: ", data
  .on "finish", (count) ->
    console.log "Exported " + count + ' csv records'
    close()
  .on "error", (error) ->
    console.log error.message
    close()
###


config.resolve (
  User
) ->

  userTotal = 0
  userCount = 0
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  mailing_list = {}
  missing_addresses = []

  skipList = ""

  processUser = (user, done) ->
    userCount++

    if false
      return done null unless userCount < 30

    User.byId user._id, {internal: true}, (err, user) ->
      console.log "****************************************Processing #{userCount} of #{userTotal}, #{user.first_name} #{user.last_name}, clientId: #{user.clientId}, userId: #{user._id}"
      if skipList.indexOf(user._id) > -1
        console.log "SKIPPING USER from skip list!"
        return done null

      name = user.name
      if !name and user.first_name and user.last_name
        name = "#{user.first_name} #{user.last_name}"
      else if !name and user.first_name
        name = user.first_name
      else if !name and user.last_name
        name = user.last_name

      address = user.mail_address if user.mail_address
      city = user.mail_city if user.mail_city
      state = user.mail_state if user.mail_state
      country = user.mail_country if user.mail_country
      zip = user.mail_postal if user.mail_postal

      address = user.physical_address if !address and user.physical_address
      city = user.physical_city if !city and user.physical_city
      state = user.physical_state if !state and user.physical_state
      country = user.physical_country if !country and user.physical_country
      zip = user.physical_postal if !zip and user.physical_postal

      address = user.shipping_address if !address and user.shipping_address
      city = user.shipping_city if !city and user.shipping_city
      state = user.shipping_state if !state and user.shipping_state
      country = user.shipping_country if !country and user.shipping_country
      zip = user.shipping_postal if !zip and user.shipping_postal

      country = "United States" if !country
      country = "United States" if country.toLowerCase().indexOf('select') > -1

      key = "#{address} #{city} #{state}"
      row = {
        name: name
        clientId:  user.clientId
        email: user.email
        phone: user.phone_cell
        address: address
        city: city
        state: state
        country: country
        zip: zip
        last_name: user.last_name
      }

      if address and city and state and country and zip
        if mailing_list[key]
          tRow = mailing_list[key]
          if tRow.name
            tRow.name = "#{tRow.name}, #{row.name}"
          else
            tRow.name = row.name

          if tRow.last_name
            tRow.last_name = "#{tRow.last_name}, #{row.last_name}"
          else
            tRow.last_name = row.last_name

          if tRow.clientId
            tRow.clientId = "#{tRow.clientId}, #{row.clientId}"
          else
            tRow.clientId = row.clientId

          if tRow.email
            tRow.email = "#{tRow.email}, #{row.email}"
          else
            tRow.email = row.email
            
          if tRow.phone
            tRow.phone = "#{tRow.phone}, #{row.phone}"
          else
            tRow.phone = row.phone

          tRow.address = row.address unless tRow.address
          tRow.city = row.city unless tRow.city
          tRow.state = row.state unless tRow.state
          tRow.country = row.country unless tRow.country
          tRow.zip = row.zip unless tRow.zip
          mailing_list[key] = tRow
          console.log "DEBUG: duplicate address found. key: ", key
        else
          mailing_list[key] = row
      else if address or city or state or zip
        missing_addresses.push row

      return done null, row


  getUsers = (cb) ->
    conditions = {
      tenantId: "5684a2fc68e9aa863e7bf182"
    }
    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    User.find(conditions).lean().exec (err, results) ->
      cb err, results

  async.waterfall [

    # Get users
    (next) ->
      userId = process.argv[2]
      if userId
        User.findById userId, {internal: true}, next
      else
        getUsers(next)

    # For each user, do stuff
    (users, next) ->
      users = [users] unless typeIsArray users
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, processUser, (err, results) ->
        return next err, results

  ], (err, results) ->
    console.log "Mailing List: ", mailing_list
    console.log "Missing Addresses: ", missing_addresses
    console.log "Mailing List Count: ", Object.keys(mailing_list).length
    console.log "Missing Addresses Count: ", missing_addresses.length

    close = () ->
      console.log "Finished"
      if err
        logger.error "Found an error", err
        process.exit(1)
      else
        console.log "Done"
        process.exit(0)

    options = {
      header: true
      columns: ['name','address','city','state','zip','country','clientId','email','phone','last_name']
    }

    mailing_addresses_data = []
    for key, value of mailing_list
      mailing_addresses_data.push value

    missing_addresses_data = []
    for key, value of missing_addresses
      missing_addresses_data.push value

    csv()
      .from.array(mailing_addresses_data, options)
      .to.path(CSV_FILE_LOCATION+'mailing_addresses.csv')
      .on "finish", (count) ->
        console.log "Exported " + count + ' csv records to mailing_addresses.csv'
        csv()
          .from.array(missing_addresses_data, options)
          .to.path(CSV_FILE_LOCATION+'mailing_partial_addresses.csv')
          .on "finish", (count) ->
            console.log "Exported " + count + ' csv records to mailing_addresses.csv'
            close()
          .on "error", (error) ->
            console.log "Error: mailing_partial_addresses.csv: " + error.message
            close()
      .on "error", (error) ->
        console.log "Error: mailing_addresses.csv: " + error.message
        close()


