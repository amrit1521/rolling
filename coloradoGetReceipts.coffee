jsdom          = require "jsdom"
_              = require 'underscore'
async          = require "async"
config         = require './config'
config         = require './config'
moment         = require 'moment'
path           = require "path"
request        = require 'request'
streamToBuffer = require "stream-to-buffer"
uuid           = require "uuid"
winston        = require 'winston'
wkhtmltopdf    = require "wkhtmltopdf"

stateId = "52aaa4cae4e055bf33db649a"

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

          # Colorado.huntsPage(data) opts, null, null, (err, response, body) ->
            # console.log "State #{state.name} points callback err:", err if err
            # console.log "State #{state.name} points callback results:", results
            # console.log "Point err #{state.name}:", err
            # console.log "Point results #{state.name}:", results unless err
          next err, null

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
              if hunt.match is specie
                receiptHunts.push hunt
                huntIds.push hunt._id
                break

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

        logger.error "Colorado err:", err if err

        console.log "Done #{user.first_name} #{user.last_name}"
        cb()

  cleanupPage = (body, basepath, cb) ->
    parentTable = undefined
    species = undefined
    parentTable = null

    jqScript = path.join(__dirname, 'assets/mixins/1_jquery-2.0.3.js')

    jsdom.env body, [jqScript], (err, window) ->
      $body = $ = window.jQuery
      $body('head').prepend "<base href=\"#{basepath}\" />"

      species = []
      $body("[id^=\"ID\"]").each (index, element) ->
        $(element).css "display", "table-row"
        return

      newTable = $('<table></table>')
      rows = []

      $body(".brownshade2").each (index, element) ->
        $element = $ element
        if $element.hasClass 'main'
          parent = $(element).parents("[id^=\"ID\"]")

          previousRow = parent.prev()
          previousRow.find('a.grid4').remove()
          previousRow.find('a.grid3').remove()
          species.push previousRow.find('u').first().text().trim()
          rows.push parent.prev()
          rows.push parent
        return

      for row in rows
        newTable.append row

      $html = $("<html><head><base href=\"#{basepath}\"></base></head><body><table>#{newTable.html()}</table></body></html>")

      result = {species, html: "<html>#{$html.html()}</html>"}
      window.close
      window = null
      return cb null, result

  uploadPDF = (body, transactionId, user, cb) ->
    year = moment().format('YYYY')
    fileName = "#{year}-#{user._id}-#{transactionId}.pdf"
    fileURL = UPLOAD_URL_PREFIX + fileName
    logger.info "Colorado::uploadPDF::fileURL", fileURL

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

    # Get users
    (next) ->
      console.log 'get users'
      User.find({last_name: {$gt: "Shortt"}}).sort({last_name: 1, first_name: 1}).lean().exec
        .then (result) ->
          next null, result
        .catch (err) ->
          next(err)

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
