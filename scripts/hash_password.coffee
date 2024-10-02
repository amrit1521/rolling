crypto = require "crypto"
config  = require "../config"

if process.argv.length < 3
  console.log "Usage: coffee hash_password.coffee password"
  process.exit 1

config.resolve (salt) ->


  password = process.argv[2]

  hashPassword = (password) ->
    shasum = crypto.createHash('sha1')
    shasum.update(password)
    shasum.update(salt)
    shasum.digest('hex')

  password = hashPassword password

  console.log 'Hashed Password:', password
  process.exit 0
