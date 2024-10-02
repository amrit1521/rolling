fs   = require('fs')
streamToBuffer = require("stream-to-buffer")
uuid = require('uuid')

module.exports = (db, receiptBucket, UPLOAD_URL_PREFIX) ->
  class AWSStorage

    _handleFile: (req, file, cb) ->
      #console.log('AWSStorage::_handleFile file keys:', Object.keys(file))
      #console.log('AWSStorage::_handleFile file encoding:', file.encoding)
      console.log('AWSStorage::_handleFile file originalname:', file.originalname)
      console.log('AWSStorage::_handleFile file mimetype:', file.mimetype)
      console.log('AWSStorage::_handleFile file size:', file.size)
      headers = {
        'Content-Type': file.mimetype,
        'x-amz-acl': 'public-read'
      }

      fileName = uuid.v4() + '.' + file.originalname.split('.').pop()

      console.log('send stream headers:', headers)
      console.log('send stream url:', UPLOAD_URL_PREFIX+fileName)

      streamToBuffer(file.stream, (err, buffer) ->
        fileSize = buffer.length
        console.log('streamToBuffer err:', err) if err
        #console.log('file keys:', Object.keys(file))
        #console.log('file stream keys:', Object.keys(file.stream))
        #console.log('buffer length:', buffer.length)
        return cb(err) if (err)

        receiptBucket.putBuffer(buffer, fileName, headers, (err, res) ->
          console.log('putBuffer err:', err) if err
          buffer = null
          return cb(err) if (err)

          console.log("successfully uploaded file to AWS S3 url:", UPLOAD_URL_PREFIX+fileName)
          console.log('receiptBucket res:', Object.keys(res))

          cb(err, {
            path: UPLOAD_URL_PREFIX + fileName,
            size: fileSize
          })
        )

      )

    _removeFile: (req, file, cb) ->
      console.log('AWSStorage::_removeFile')
      # find file based on originalname
      # delete file record
      # receiptBucket.del('/test/Readme.md').on('response', (res) ->
      #   console.log(res.statusCode)
      #   console.log(res.headers)
      #   cb(null, res)
      # ).end()
      cb()



  return AWSStorage
