jsdom          = require "jsdom"
_              = require 'underscore'
async          = require "async"
config         = require './config'
moment         = require 'moment'
path           = require "path"
request        = require 'request'
streamToBuffer = require "stream-to-buffer"
uuid           = require "uuid"
winston        = require 'winston'
wkhtmltopdf    = require "wkhtmltopdf"

stateId = "52aaa4cbe4e055bf33db64a0"

config.resolve (
  Application
  logger
  Hunt
  Point
  receiptBucket
  Secure
  State
  UPLOAD_URL_PREFIX
  User
  UserState

  Wyoming
) ->

  userCounter = 0
  userTotal = 0

  logOn = ->
    logger.add(winston.transports.Console, {
      colorize: true
      timestamp: true
    })

  logOff = ->
    logger.remove(winston.transports.Console)

  getUserReceipts = (hunts) ->
    (user, cb) ->
      user.results = {}
      userCounter++
      console.log "Processing user #{user.first_name} #{user.last_name} [#{user.clientId}] - #{userCounter} of #{userTotal}"
      logOff()

      parts = [user.field1, user.field2]

      decrypted = Secure.desocial parts
      user.ssn = decrypted.social if decrypted.social
      user.dob = decrypted.dob if decrypted.dob

      # user.results[state.name] = {}
      # console.log "Starting #{state.name} - #{user.first_name} #{user.last_name}"
      opts = {
        jar: request.jar()
      }

      data = {user, transactionId: uuid.v4(), year: moment().year()}

      async.waterfall [

        # Get CID
        (next) ->
          UserState.byStateAndUser user._id, stateId, (err, userState) ->
            return next err if err
            user.cid = userState.cid if userState?.cid
            next err

        # Get hunts page
        (next) ->

          Wyoming.previousHuntsPage user, opts, (err, response, body) ->
            return next err if err
            # Wyoming.huntsPage(data) opts, null, null, (err, response, body) ->
            # console.log "State #{state.name} points callback err:", err if err
            # console.log "State #{state.name} points callback results:", results
            # console.log "Point err #{state.name}:", err
            # console.log "Point results #{state.name}:", results unless err
            next err, body

        # Parse page
        (body, next) ->
          cleanupPage body, opts.lastURL, next

        # Create Receipt
        (results, next) ->
          return next 'SKIP' if typeof results is 'function' or not results.species?.length

          uploadPDF results.html, data.transactionId, user, (err, fileUrl) ->
            next err, results, fileUrl

        # Save the receipt to the appropriate hunts
        (result, fileUrl, next) ->

          receiptHunts = []
          huntIds = []

          # console.log "result:", result
          for specie in result.species
            for hunt in hunts
              if ~specie.search hunt.match
                receiptHunts.push hunt
                huntIds.push hunt._id
                break

          huntIds = _.uniq huntIds
          # console.log "hunts:", hunts
#          console.log "result.species:", result.species
#          console.log "huntIds:", huntIds

          application = new Application {
            huntIds: huntIds
            receipt: fileUrl
            resultBody: result.html
            stateId
            transactionId: data.transactionId
            userId: data.user._id
            year: data.year
          }

          # console.log "application:", application
          application.save (err) -> next err

      ], (err) ->
        err = null if err is 'SKIP'

        if err?.code is '0120'
          err = null
          console.log "Customer: #{user.first_name} #{user.last_name} not found"

        logOn()

        logger.error "Wyoming err:", err if err
        # x + y if err

        console.log "Done #{user.first_name} #{user.last_name}"
        cb()

  cleanupPage = (body, basepath, cb) ->
    species = undefined

    jqScript = path.join(__dirname, 'assets/mixins/1_jquery-2.0.3.js')

    jsdom.env body, [jqScript], (err, window) ->
      $body = $ = window.jQuery
      #$body('#').prepend "<base href=\"#{basepath}\" />"

      speciesTable = $body('#dgPurchased')
      userSpan = $body('#lblName')

      species = []
      speciesTable.find('tr').each (index, row) ->
        return if index is 0

        $row = $(row)

        species.push $row.find('td').eq(1).text().split('Quantity')[0].trim()
        $row.find('[value="Modify"]').parent().remove()
        return

      $html = $("<html><head><link rel=\"stylesheet\" href=\"http://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css\"></head><body><label>#{userSpan.text().trim()}</label><table class=\"table table-striped\" style=\"max-width: 800px;\">#{speciesTable.html()}</table></body></html>")

      species = _.uniq species

      result = {species, html: "<html>#{$html.html()}</html>"}
      window.close
      window = null
      return cb null, result

  uploadPDF = (body, transactionId, user, cb) ->
    year = moment().format('YYYY')
    fileName = "#{year}-#{user._id}-#{transactionId}.pdf"
    fileURL = UPLOAD_URL_PREFIX + fileName
    logger.info "Wyoming::uploadPDF::fileURL", fileURL

    pdfStream = wkhtmltopdf(body)
    streamToBuffer pdfStream, (err, buffer) ->
      return cb err if err

      headers = {
        'Content-Type': 'application/pdf'
        'x-amz-acl': 'public-read'
      }

      receiptBucket.putBuffer buffer, "/" + fileName, headers, (err, res) ->
        return cb err if err
        cb null, fileURL


  async.waterfall [

    # Get users with receipts
    (next) ->
      Application.find({stateId}).lean().exec (err, applications) ->
        return next err if err
        userIds = _.pluck applications, 'userId'
        userIds = _.uniq userIds
        next null, userIds

    # Get users
    (doneUsers, next) ->
      console.log 'get users'
      User.find({_id: {$nin: doneUsers}}).lean().exec (err, users) ->
        next err, users

    # Add user wyoming sportsmans IDs
    (users, next) ->
      return next {error: "No users found"} if not users or users.length is 0
      userIds = _.pluck users, '_id'
      UserState.byStateUsers stateId, userIds, (err, userStates) ->
        return next err if err
        for userState in userStates
          for user in users
            if userState.userId.toString() is user._id.toString()
              user.cid = userState.cid
              break

        next null, users

    (users, next) ->
      Hunt.byStateId stateId, (err, hunts) ->
        next err, users, hunts

    # Get user's receipts
    (users, hunts, next) ->
      console.log "found #{users.length} users"
      userTotal = users.length
      async.mapSeries users, getUserReceipts(hunts), (err) ->
        next err

  ], (err) ->
    console.log "Finished"
    if err
      logger.error "Found an error:", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
