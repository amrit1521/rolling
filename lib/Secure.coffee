_ = require 'underscore'
crypto = require 'crypto'
moment = require 'moment'

module.exports = (secure_algorithm, secure_key, secure_secret,
  CIPHER_ALGORITHM, CIPHER_KEY, RADS_SHARED_TOKEN, RADS_APP_SHARED_TOKEN, RADS_STAMP_DATEFORMAT,
  RADS_STAMP_DEL, RADS_STAMP_SKIP, RADS_STAMP_TIMEALLOWED, APITOKEN_VDTEST) ->

  Secure = {

    encrypt: (value) ->
      value ?= ''
      value += secure_secret
      cipher = crypto.createCipher secure_algorithm, secure_key
      cipher.update(value, 'utf8', 'hex') + cipher.final('hex')

    decrypt: (value) ->
      return value unless value
      decipher = crypto.createDecipher secure_algorithm, secure_key
      decrypted = decipher.update(value, 'hex', 'utf8') + decipher.final('utf8')
      decrypted.substr 0, (decrypted.length - secure_secret.length)

    social: (data, dob) ->

      data = '' if not data or data is 'undefined'
      dob = '' if not dob or dob is 'undefined'

      dob = if dob then moment(dob, 'YYYY-MM-DD').format 'MMDDYYYY' else '00000000'
      data = ('000000000' + data).substr -9
      dob = ('00000000' + dob).substr -8

      combined = [
        data.substr 0, 4
        dob.substr 0, 4
        data.substr 4, 1
        dob.substr 4
        data.substr 5
      ].join('')

      parts = [combined.substr(0, 9), combined.substr(9)]
      for part, i in parts
        parts[i] = @encrypt part
      parts

    desocial: (parts) ->
      return {} unless parts.length is 2

      for part, i in parts
        return {} unless parts[i]
        parts[i] = @decrypt part

      data = parts.join ''

      dob = [
        data.substr 4, 4
        data.substr 9, 4
      ].join ''

      social = [
        data.substr 0, 4
        data.substr 8, 1
        data.substr 13
      ].join ''

      social = '' if social is '000000000'
      dob = '' if not dob or dob is '00000000'
      dob = moment(dob, 'MMDDYYYY').format 'YYYY-MM-DD' if dob.length

      {social, dob}

    credit: (data, exp) ->
      combined = [
        data.substr 0, 4
        exp.substr 0, 2
        data.substr 4, 4
        exp.substr 2, 2
        data.substr 8, 4
        exp.substr 4, 2
        data.substr 12
      ].join('')
      parts = [combined.substr(0, 12), combined.substr(12)]
      for part, i in parts
        parts[i] = @encrypt part
      parts

    decredit: (parts) ->
      for part, i in parts
        parts[i] = @decrypt part

      data = parts.join ''

      exp = [
        data.substr 4, 2
        data.substr 10, 2
        data.substr 16, 2
      ].join ''

      credit = [
        data.substr 0, 4
        data.substr 6, 4
        data.substr 12, 4
        data.substr 18
      ].join ''

      {credit, exp}
















    #****************AUTHENTICATION METHODS IMPLEMENTED FOR INTEGRATION WITH RRADS**************

    #Return true or false
    validate_rads_stamp: (encryptedStamp) ->
      response = {
        isValid: true
        params: {}
      }
      decrypted = @decrypt_rads_stamp encryptedStamp
      if !decrypted
        console.log "Invalid Stamp: decrypted failed."
        response.isValid = false
        return response

      dArray = decrypted.split(RADS_STAMP_DEL)

      if dArray?.length < 2
        response.isValid = false
        console.log "Invalid Stamp: invalid length."
        return response

      timestampnum = parseInt(dArray[0])
      sharedtoken = dArray[1]
      if dArray.length > 2
        params = dArray[2]
        params = JSON.parse('{"' + decodeURI(params).replace(/"/g, '\\"').replace(/&/g, '","').replace(/=/g,'":"') + '"}')


      timestamp = new Date(timestampnum)
      now = new Date()
      timeDiff = now.getTime() - timestamp.getTime()

      #DEBUG: TEMPORARY JUST FOR GETTING APP TESTING STARTED:
      if params?.timestamp is '1560447205822'
        timeDiff = 0

      if sharedtoken is RADS_SHARED_TOKEN and timeDiff < RADS_STAMP_TIMEALLOWED
        response.isValid = true
        response.params = params if params
      else if sharedtoken is RADS_APP_SHARED_TOKEN and timeDiff < RADS_STAMP_TIMEALLOWED
        response.isValid = true
        response.params = params if params
      else if sharedtoken is APITOKEN_VDTEST and timeDiff < RADS_STAMP_TIMEALLOWED
        response.isValid = true
        response.params = params if params
      else
        response.isValid = false
        console.log "Invalid Stamp: shared token mismatch or timestamp is expired. TOKEN MATCH: #{sharedtoken is RADS_SHARED_TOKEN or sharedtoken is RADS_APP_SHARED_TOKEN}, TIMEDIFF: #{timeDiff < RADS_STAMP_TIMEALLOWED}, timediff: #{timeDiff}, allowed: #{RADS_STAMP_TIMEALLOWED}"
        console.log "Stamp: ", sharedtoken
        console.log "Params: ", params
        console.log "RADS_SHARED_TOKEN: ", RADS_SHARED_TOKEN

      if RADS_STAMP_SKIP
        response.isValid = true

      return response


    decrypt_rads_stamp: (encryptedStamp) ->
      encryptedStamp = @verify encryptedStamp, CIPHER_KEY
      return null if encryptedStamp instanceof @InvalidSignatureError
      decrypted = @decipher_rrads encryptedStamp, CIPHER_KEY
      return decrypted

    encrypt_rads_stamp: (params, cb) ->
      now = new Date().getTime()
      queryStr = null
      if params and Object.keys(params).length
        queryStr = ""
        count = 0
        for key, value of params
          queryStr += "&" unless count is 0
          queryStr += "#{key}=#{value}"
          count++

      stamp = "#{now}#{RADS_STAMP_DEL}#{RADS_SHARED_TOKEN}"
      stamp += "#{RADS_STAMP_DEL}#{queryStr}" if queryStr?.length

      @encipher_rrads stamp, CIPHER_KEY, (err, eStamp) =>
        if err
          console.log "Error enciphering stamp: ", err
          return cb err
        else
          eStamp = @sign eStamp, CIPHER_KEY
          return cb null, eStamp


    InvalidSignatureError : () ->
      Error.captureStackTrace this, @constructor
      return

    encipher_rrads: (message, password, callback) ->
      crypto.randomBytes 16, (err, iv) ->
        if err
          return callback(err)
        cipher = crypto.createCipheriv('aes-256-cbc', password, iv)
        enciphered = ''
        enciphered += cipher.update(message, 'utf-8', 'binary')
        enciphered += cipher.final('binary')
        enciphered = new Buffer(enciphered, 'binary')
        encipheredMessage = [
          enciphered.toString('base64')
          iv.toString('base64')
        ].join('--')
        callback null, encipheredMessage
        return
      return

    decipher_rrads: (encipheredMessage, password) ->
      parts = encipheredMessage.split('--', 2)
      enciphered = new Buffer(parts[0], 'base64')
      iv = new Buffer(parts[1], 'base64')
      decipher = crypto.createDecipheriv('aes-256-cbc', password, iv)
      deciphered = ""
      deciphered += decipher.update(enciphered)
      deciphered += decipher.final()
      return deciphered

    sign: (message, password) ->
      signer = crypto.createHmac('sha256', password)
      signer.update message
      signature = signer.digest('binary')
      message = new Buffer(message, 'utf-8')
      signature = new Buffer(signature, 'binary')
      signedMessage = [
        message.toString('base64')
        signature.toString('base64')
      ].join('--')
      return signedMessage

    verify: (signedMessage, password) ->
      return new @InvalidSignatureError unless signedMessage and password
      parts = signedMessage.split('--', 2)
      encodedMessage = new Buffer(parts[0], 'base64')
      signature = new Buffer(parts[0], 'base64')
      message = encodedMessage.toString('utf-8')
      signedMessageForVerification = @sign message, password
      if signedMessage != signedMessageForVerification
        return new @InvalidSignatureError
      return message



















  }

  _.bindAll.apply _, [Secure].concat(_.functions(Secure))
  Secure
