_ = require 'underscore'
async = require "async"
#config = require '../config'
moment    = require 'moment'
stripJs = require 'strip-js'
fs = require 'fs'

#example:  ./node_modules/coffeescript/bin/coffee scripts/stripjs.coffee ../../GMT/tmp/CO home.html

#config.resolve (
#  logger
#  Secure
#  User
#) ->

run = () ->
  err = null
  try
    filepath = process.argv[2]
    filename = process.argv[3]
    html = fs.readFileSync("#{filepath}/#{filename}").toString()
    safeHtml = stripJs(html)
    console.log safeHtml
    fs.writeFileSync("#{filepath}/nojs/#{filename}", safeHtml);
  catch err
    err = err

  if err
    console.error "Found an error", err
    process.exit(1)
  else
    console.log "Done"
    process.exit(0)

run()