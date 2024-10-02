async      = require 'async'
browserify = require 'gulp-browserify'
coffee     = require 'gulp-coffee'
concat     = require 'gulp-concat'
del        = require 'del'
fs         = require 'fs'
gulp       = require 'gulp'
gulpif     = require 'gulp-if'
gutil      = require 'gulp-util'
# imagemin   = require 'imagemin'
jade       = require 'gulp-jade'
moment     = require 'moment'
nodemon    = require 'gulp-nodemon'
path       = require 'path'
rename     = require 'gulp-rename'
replace    = require 'gulp-replace'
request    = require 'request'
templates  = require 'gulp-angular-templatecache'
uglify     = require 'gulp-uglify'
xml2js     = require 'xml2js'

AppOptions = {
  # host: "https://test.gotmytag.com" # production - using test until we can get an ssl cert for api.gotmytag.com
#  host: "https://gotmytag.dev:5001" # local only
    host: "http://gtmatix.local:5003" # local only
}

runSequential = (tasks) ->
  return if !tasks or tasks.length <= 0

  task = tasks[0]
  gulp.start task, ->
    console.log "#{task} finished"
    runSequential tasks.slice(1)

fileDate = moment().format('YYYYMMDDHHmmss')
console.log "fileDate:", fileDate

coffeeSrc = [
  'assets/application/**/*.coffee'
  'assets/services/**/*.coffee'
  'assets/directives/**/*.coffee'
  'assets/filters/**/*.coffee'
  'assets/controllers/**/*.coffee'
  'assets/models/**/*.coffee'
]

bowerSrc = [
  'bower_components/jquery/dist/jquery.js'
  'bower_components/angular/angular.js'
  'bower_components/angular-touch/angular-touch.js'
  'bower_components/socketcluster-client/socketcluster.js'
]

vendorSrc = ["assets/mixins/*.js"]

gulp.task 'clean', (cb) ->
  del [
    "app/www/css/*.css"
    "app/www/img/*"
    "app/www/js/*.js"
    "app/www/index.html"
    "app/www/robots.txt"
  ], cb
  return

gulp.task "coffee", ->
  gulp.src(coffeeSrc)
    .pipe(coffee({bare: true}).on("error", gutil.log))
    .pipe(concat("application#{fileDate}.js"))
    # .pipe(uglify())
    .pipe gulp.dest("app/www/js")

gulp.task "browserifyCoffee", ->
  gulp.src("assets/browserify.coffee", { read: false })
    .pipe(browserify({
      transform: ['coffeeify']
      extensions: ['.coffee']
    }))
    .pipe(rename("browserified#{fileDate}.js"))
    # .pipe(uglify())
    .pipe gulp.dest("app/www/js")

gulp.task "css", ->
  gulp.src("assets/styles/*.css")
    .pipe(concat("app#{fileDate}.css"))
    # .pipe(uglify())
    .pipe gulp.dest("app/www/css")

gulp.task "images", ->
  gulp.src("public/img/**")
#    .pipe(imagemin({reduce: true})())
    .pipe gulp.dest("app/www/img")

gulp.task "sounds", ->
  gulp.src("public/sounds/android/**")
    .pipe gulp.dest("app/www/sounds/android")
  gulp.src("public/sounds/ios/**")
    .pipe gulp.dest("app/www/sounds/ios")

gulp.task "fonts", ->
  gulp.src(["!public/fonts/kendo/", "public/fonts/**"])
    .pipe gulp.dest("app/www/fonts")
  gulp.src("public/fonts/kendo/**")
    .pipe gulp.dest("app/www/css/")



gulp.task "robots", ->
  gulp.src("public/robots.txt")
    .pipe gulp.dest("app/www")


# Jade Files
jadeOptions =
  client: false
  basePath: 'views'
  pretty: true
  data:
    tenant:
      name: "{{tenant.name}}"
      logo: "{{tenant.logo}}"
    tenantString: "{{tenant}}"
    isPhonegap: false
    apiUrl: 'http://localhost:5003/'
    fileDate: fileDate
    PUBNUB_SUBSCRIBE_KEY: "sub-c-4d504c4e-800c-11e4-bfb6-02ee2ddab7fe"
    senderID: "964326151372" # Google sender id


#### ||| Only For App Development ||| ####
#### VVV                          VVV ####

#jadeOptions.data.tenant =
#  name: "GotMyTag.com",
#  logo: "img/logo.png"
#
#jadeOptions.data.isPhonegap = true

#### AAA                          AAA ####
#### ||| Only For App Development ||| ####


gulp.task "populateTenant", ->
  jadeOptions.data.tenant =
    _id: "53a28a303f1e0cc459000127"
    domain: "www.gotmytag.com"
    logo: "img/logo.png"
    name: "GotMyTag"
    url: "http://www.gotmytag.com"
  jadeOptions.data.tenantString = JSON.stringify(jadeOptions.data.tenant)
  console.log "jadeOptions.data.tenantString:", jadeOptions.data.tenantString

gulp.task "index", ->
  gulp.src("views/main.jade")
    .pipe(jade(jadeOptions))
    .pipe(rename('index.html'))
    .pipe gulp.dest("app/www")

gulp.task "appIndex", ->

  jadeOptions.data.isPhonegap = true
  jadeOptions.data.apiUrl = AppOptions.host

  gulp.src("views/index.jade")
    .pipe(jade(jadeOptions))
    .pipe gulp.dest("app/www")

  gulp.src("views/main.jade")
    .pipe(jade(jadeOptions))
    .pipe gulp.dest("app/www")

  gulp.src("views/config.jade")
    .pipe(jade(jadeOptions))
    .pipe(rename('config.xml'))
    .pipe gulp.dest("app/www")


gulp.task "javascript", ->
  gulp.src([].concat.call(bowerSrc, vendorSrc))
    .pipe(concat("vendors#{fileDate}.js"))
    .pipe(uglify())
    .pipe gulp.dest("app/www/js")

gulp.task "templates", ->
  gulp.src("assets/**/*.jade")
    .pipe(jade(client: false, basePath: 'views', pretty: true))
    .pipe(templates("templates#{fileDate}.js", {module: 'APP'}))
    .pipe(replace('angular.module("APP", [])', 'APP.Templates'))

    # .pipe(uglify())
    .pipe gulp.dest("app/www/js")

gulp.task "nodemon", ->
  fileDate = moment().format('YYYYMMDDHHmmss')
  nodemon(
    script: "app.coffee"
    ext: 'html js css coffee jade ejs'
    ignore: ['app', 'cache', 'node_modules']
    tasks: ['build-site']
  )

gulp.task "prerender", ->
  # Read sitemap
  sitemapFile = path.join __dirname, 'views/sitemap.xml'
  domain = jadeOptions.data.tenant.domain
  fs.readFile sitemapFile, (err, contents) ->
    return console.log "error reading sitemap.xml:", err if err

    renderUrl = (location, done) ->
      url = location.loc[0].replace(/{{tenant.domain}}/, domain).replace /#!/, '?_escaped_fragment_='
      url += '?_escaped_fragment_=/' unless ~url.search /_escaped_fragment_/
      console.log "request url:", url
      request.get url, done

    xml2js.parseString contents, (err, result) ->
      return console.log "error parsing sitemap.xml:", err if err
      sitemap = result.urlset.url
      async.mapSeries sitemap, renderUrl, (err, results) ->
        return console.log "error requesting urls:", err if err

gulp.task 'build-site',    ['clean', 'coffee', 'browserifyCoffee', 'css', 'fonts', 'images', 'robots', 'index', 'javascript', 'templates']
gulp.task 'app',           ['clean', 'coffee', 'browserifyCoffee', 'css', 'fonts', 'images', 'sounds', 'populateTenant', 'appIndex', 'javascript', 'templates']
gulp.task 'run-prerender', ['populateTenant', 'prerender']
gulp.task 'default',       () => runSequential([ 'build-site', 'nodemon' ])
