$              = require "cheerio"
config         = require '../config'
request        = require 'request'
streamToBuffer = require "stream-to-buffer"
wkhtmltopdf    = require "wkhtmltopdf"

STATE_ID = '52aaa4cbe4e055bf33db649f'
BASEPATH = 'https://www.utah-hunt.com/UTBigGame/'
YEAR     = '2016'

uploadPDF = (receiptBucket, body, fileURL, cb) ->
  $body = $.load body
  fileName = fileURL.split('/').pop()
  console.log "Utah::uploadPDF::fileURL", fileURL
  $body('head').prepend "<base href=\"#{BASEPATH}\" />"

  pdfStream = wkhtmltopdf($body.html(), {printMediaType: true, "page-width": "216mm", "page-height": "375mm"})
  streamToBuffer pdfStream, (err, buffer) ->
    return cb err if err

    headers = {
      'Content-Type': 'application/pdf'
      'x-amz-acl': 'public-read'
    }

    receiptBucket.putBuffer buffer, "/" + fileName, headers, (err, res) ->
      return cb err if err
      cb null, fileURL


config.resolve (
  Application
  receiptBucket
) ->

  stream = Application.find({stateId: STATE_ID, year: YEAR, receipt: {$ne: null}}).stream()
  stream.on 'data', (application) ->
    _this = this

    @pause()

    # Just for testing
    # application.receipt = application.receipt.split('.').slice(0, -1).join('.') + '_1.pdf'

    request.get(application.receipt).on 'response', (res) ->
      console.log 'status:', res.statusCode
      # Fix the receipt if res.statusCode is 403

      if res.statusCode is 403

        uploadPDF receiptBucket, application.resultBody, application.receipt, (err, fileURL) ->
          if err
            console.log 'err:', err
            process.exit()
            return

          console.log 'uploaded:', fileURL
          _this.resume()
      else
        _this.resume()

  stream.on 'close', ->
    # all done
    console.log 'stream closed'
    process.exit()
