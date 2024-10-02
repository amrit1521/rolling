fs = require "fs"
csv = require "csv"
config = require './config'

config.resolve (
  Zipcode
) ->

  arrayToZip = (parts) ->
    # ZIPCode,State,City,County,Latitude,Longitude
    return {
      code: parts[0]
      state: parts[1]
      city: parts[2]
      county: parts[3]
      lat: parts[4]
      lon: parts[5]
    }

  # when writing to a file, use the 'close' event
  # the 'end' event may fire before the file has been written
  csv().from.path(__dirname + "/zips.csv",
    delimiter: ","
  ).on("record", (row, index) ->
    return unless index > 0 # skip label row

    console.log "#" + index + " " + JSON.stringify(row)

    zipcode = new Zipcode(arrayToZip(row))
    zipcode.save()

  ).on("end", (count) ->
    console.log "Imported " + count + ' zipcodes'
  ).on "error", (error) ->
    console.log error.message



