_ = require "underscore"
crypto = require "crypto"
fs = require "fs"
jsdom = require "jsdom"
path = require "path"
request = require "request"
util = require "util"

module.exports = (logger) ->
  cacheDir = path.join(__dirname, '../cache')
  fs.mkdirSync(cacheDir) unless fs.existsSync(cacheDir)

  Bots = {

    render: (req, res) ->

      url = req.protocol + '://' + req.headers.host + '/#!' + req.param('_escaped_fragment_')
      console.log "\n\n\n\n\n\n\n\n\n\n"
      console.log "REQUEST url:", url
      console.log "\n\n\n\n\n\n\n\n\n\n"

      md5 = crypto.createHash 'md5'
      md5.update url
      filepath = path.join(cacheDir, md5.digest('hex'))
      console.log "filepath:", filepath

      fs.exists filepath, (exists) ->
        if exists
          fs.readFile filepath, {encoding: "utf8"}, (err, contents) -> res.end contents
        else
          jsdom.env
            url: url

            features:
              FetchExternalResources: ["script"]
              ProcessExternalResources: ["script"]

            done: (err, window) ->
              if err
                res.json "An error occurred", 500
                logger.error "Bots::render err:" + util.inspect(err, {depth: 5})
                return

              window.addEventListener "load", ->

                e = window.document.getElementById 'mainctl'
                if window.angular?
                  scope = window.angular.element(e).scope()
                  scope.$apply ->
                    scope.setLocation req.params('_escaped_fragment_')
                    return undefined
                  setTimeout ->

                    result = window.document.innerHTML
                    # write to filesystem
                    fs.writeFile filepath, result, (err) ->
                      if err
                        res.json "An error occurred", 500
                        logger.error "Bots::render err:" + util.inspect(err, {depth: 5})
                        return

                      res.end result
                      return

                  , 50
                else
                  res.json "Angular not found", 500

  }

  _.bindAll.apply _, [Bots].concat(_.functions(Bots))
  return Bots
