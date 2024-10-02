crypto     = require "crypto"
e          = require "std-error"
Intimidate = require "intimidate"
multiparty = require "multiparty"

module.exports = (UPLOAD_S3_KEY, UPLOAD_S3_SECRET, UPLOAD_BUCKET, UPLOAD_URL_PREFIX, logger) ->
  bodyparser: (req, res, next) ->
    return next() if req.method isnt 'POST'
    return next() if not req.headers['content-type'] or req.headers['content-type'].search('multipart/form-data') is -1

    formClosed = false
    fileUploaded = false

    req.body = {}
    req._body = true

    form = new multiparty.Form()
    form.parse req

    form.on 'error', (err) ->
      logger.info "form parsing failed:", err
      next()

    form.on 'close', () ->
      formClosed = true

      next() if fileUploaded

    form.on 'part', (part) ->
      partBuffers = {}

      if !part.filename
        part.setEncoding('utf8')

      part.on "readable", () ->
        partBuffers[part.name] = part.read(part.byteCount)

      part.on "end", () ->

        if !part.filename
          return req.body[part.name] = partBuffers[part.name]

        extension = part.filename.split('.').pop()

        client = new Intimidate({
          key: UPLOAD_S3_KEY
          secret: UPLOAD_S3_SECRET
          bucket: UPLOAD_BUCKET
          maxRetries: 5
        })

        contentType = part.headers['content-type']

        headers = {
          'Content-Type': part.headers['content-type']
          'Content-Length': part.byteCount
          'x-amz-acl': 'public-read'
        }

        filename = crypto.randomBytes(20).toString('hex') + "." + extension

        return next() if part.byteCount is 0

        client.uploadBuffer partBuffers[part.name], headers, filename, (err, result) ->
          return res.json({error: true, message: err}) if err

          req.body[part.name] = {contentType, extension, url: UPLOAD_URL_PREFIX + filename, size: part.byteCount, filename: part.filename}
          fileUploaded = true

          return next() if formClosed


    uploadPDF: (opts, fileLocation, user, cb) ->
      year = moment().format('YYYY')
      random = Math.random().toString(36).substr(7)
      fileName = "#{year}-#{user._id}-#{opts.transactionId}-#{random}.pdf"
      fileURL = UPLOAD_URL_PREFIX + fileName
      logger.info "Utah::uploadPDF::fileURL", fileURL

      dropboxStream = new passThrough
      awsStream = new passThrough

      return cb "Error, the file location doesn't exist: #{fileLocation}" unless fs.existsSync(fileLocation)
      pdfStream = fs.createReadStream(fileLocation)
      #writableStream = fs.createWriteStream("#{NM_TMP_LOC}tmp.pdf")
      #pdfStream.pipe(writableStream)
      pdfStream.pipe(awsStream)

      async.parallel [
        # Send to Huntinfool DropBox
        (done) ->
          logger.info "user.tenantId: #{user.tenantId.toString()}, HuntinFoolTenantId:#{HuntinFoolTenantId}"
          return done() unless user.tenantId.toString() == HuntinFoolTenantId
          stateAbreviation = "AZ"
          if opts?.admin?.first_name
            username = opts.admin.first_name
          else
            username = "shandi"
          filePathName = "#{user.clientId}_#{username}_#{stateAbreviation}_#{year}_#{opts.transactionId}_#{user.first_name}-#{user.last_name}.pdf"
          pdfStream.pipe(dropboxStream)
          logger.info "Uploading dropbox file: ", filePathName
          NavTools.uploadToDropbox(dropboxStream, filePathName, done)

        # Upload to amazon s3
        (done) ->
          console.log "starting upload to amazon s3"
          streamToBuffer awsStream, (err, buffer) ->
            return done err if err
            # Releases the reference to the stream to make it availab for GC
            awsStream = null
            headers = {
              'Content-Type': 'application/pdf'
              'x-amz-acl': 'public-read'
            }

            receiptBucket.putBuffer buffer, "/" + fileName, headers, (err, res) ->
              # Release the reference to the buffer to make it availab for GC
              buffer = null
              done err

      ], (err) ->
        pdfStream = null
        console.log err if err
        cb err, fileURL
