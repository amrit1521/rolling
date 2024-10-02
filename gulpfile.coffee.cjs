(function() {
  var AppOptions, async, bowerSrc, browserify, coffee, coffeeSrc, concat, del, fileDate, fs, gulp, gulpif, gutil, jade, jadeOptions, moment, nodemon, path, rename, replace, request, runSequential, templates, uglify, vendorSrc, xml2js;

  async = require('async');

  browserify = require('gulp-browserify');

  coffee = require('gulp-coffee');

  concat = require('gulp-concat');

  fs = require('fs');

  gulp = require('gulp');

  gulpif = require('gulp-if');

  gutil = require('gulp-util');

  jade = require('gulp-jade');

  moment = require('moment');

  nodemon = require('gulp-nodemon');

  path = require('path');

  rename = require('gulp-rename');

  replace = require('gulp-replace');

  request = require('request');

  templates = require('gulp-angular-templatecache');

  uglify = require('gulp-uglify');

  xml2js = require('xml2js');

  AppOptions = {
    host: "https://test.gotmytag.com"
  };

  runSequential = function(tasks) {
    if (!tasks || tasks.length <= 0) {
      return;
    }
    return gulp.series(...tasks)(function(err) {
      if (err) {
        console.log('Error occurred:', err);
      } else {
        console.log('All tasks finished successfully');
      }
    });
  };
  
  fileDate = moment().format('YYYYMMDDHHmmss');

  console.log("fileDate:", fileDate);

  coffeeSrc = ['assets/application/**/*.coffee', 'assets/services/**/*.coffee', 'assets/directives/**/*.coffee', 'assets/filters/**/*.coffee', 'assets/controllers/**/*.coffee', 'assets/models/**/*.coffee'];

  bowerSrc = ['bower_components/jquery/dist/jquery.js', 'bower_components/angular/angular.js', 'bower_components/angular-touch/angular-touch.js', 'bower_components/socketcluster-client/socketcluster.js'];

  vendorSrc = ["assets/mixins/*.js"];

  gulp.task('clean', function(done) {
    (async () => {
      try {
        await import('del').then(["app/www/css/*.css", "app/www/img/*", "app/www/js/*.js", "app/www/index.html", "app/www/robots.txt"]);
        console.log('Success');
        done();
      } catch (err) {
        console.log('Error occurred.', err);
        done(err);
      }
    })();
  });

  gulp.task("coffee", function() {
    return gulp.src(coffeeSrc).pipe(coffee({
      bare: true
    }).on("error", gutil.log)).pipe(concat("application" + fileDate + ".js")).pipe(gulp.dest("app/www/js"));
  });

  gulp.task("browserifyCoffee", function() {
    return gulp.src("assets/browserify.coffee", {
      read: false
    }).pipe(browserify({
      transform: ['coffeeify'],
      extensions: ['.coffee']
    })).pipe(rename("browserified" + fileDate + ".js")).pipe(gulp.dest("app/www/js"));
  });

  gulp.task("css", function() {
    return gulp.src("assets/styles/*.css").pipe(concat("app" + fileDate + ".css")).pipe(gulp.dest("app/www/css"));
  });

  gulp.task("images", function() {
    return gulp.src("public/img/**").pipe(gulp.dest("app/www/img"));
  });

  gulp.task("sounds", function() {
    gulp.src("public/sounds/android/**").pipe(gulp.dest("app/www/sounds/android"));
    return gulp.src("public/sounds/ios/**").pipe(gulp.dest("app/www/sounds/ios"));
  });

  gulp.task("fonts", function() {
    gulp.src(["!public/fonts/kendo/", "public/fonts/**"]).pipe(gulp.dest("app/www/fonts"));
    return gulp.src("public/fonts/kendo/**").pipe(gulp.dest("app/www/css/"));
  });

  gulp.task("robots", function() {
    return gulp.src("public/robots.txt").pipe(gulp.dest("app/www"));
  });

  jadeOptions = {
    client: false,
    basePath: 'views',
    pretty: true,
    data: {
      tenant: {
        name: "{{tenant.name}}",
        logo: "{{tenant.logo}}"
      },
      tenantString: "{{tenant}}",
      isPhonegap: false,
      apiUrl: '',
      fileDate: fileDate,
      PUBNUB_SUBSCRIBE_KEY: "sub-c-4d504c4e-800c-11e4-bfb6-02ee2ddab7fe",
      senderID: "964326151372"
    }
  };

  gulp.task("populateTenant", function() {
    jadeOptions.data.tenant = {
      _id: "53a28a303f1e0cc459000127",
      domain: "www.gotmytag.com",
      logo: "img/logo.png",
      name: "GotMyTag",
      url: "http://www.gotmytag.com"
    };
    jadeOptions.data.tenantString = JSON.stringify(jadeOptions.data.tenant);
    return console.log("jadeOptions.data.tenantString:", jadeOptions.data.tenantString);
  });

  gulp.task("index", function() {
    return gulp.src("views/main.jade").pipe(jade(jadeOptions)).pipe(rename('index.html')).pipe(gulp.dest("app/www"));
  });

  gulp.task("appIndex", function() {
    jadeOptions.data.isPhonegap = true;
    jadeOptions.data.apiUrl = AppOptions.host;
    gulp.src("views/index.jade").pipe(jade(jadeOptions)).pipe(gulp.dest("app/www"));
    gulp.src("views/main.jade").pipe(jade(jadeOptions)).pipe(gulp.dest("app/www"));
    return gulp.src("views/config.jade").pipe(jade(jadeOptions)).pipe(rename('config.xml')).pipe(gulp.dest("app/www"));
  });

  gulp.task("javascript", function() {
    return gulp.src([].concat.call(bowerSrc, vendorSrc)).pipe(concat("vendors" + fileDate + ".js")).pipe(gulp.dest("app/www/js"));
  });

  gulp.task("templates", function() {
    return gulp.src("assets/**/*.jade").pipe(jade({
      client: false,
      basePath: 'views',
      pretty: true
    })).pipe(templates("templates" + fileDate + ".js", {
      module: 'APP'
    })).pipe(replace('angular.module("APP", [])', 'APP.Templates')).pipe(gulp.dest("app/www/js"));
  });

  gulp.task("nodemon", function() {
    fileDate = moment().format('YYYYMMDDHHmmss');
    return nodemon({
      script: "app.coffee",
      ext: 'html js css coffee jade ejs',
      ignore: ['app', 'cache', 'node_modules'],
      tasks: ['build-site']
    });
  });

  gulp.task("prerender", function() {
    var domain, sitemapFile;
    sitemapFile = path.join(__dirname, 'views/sitemap.xml');
    domain = jadeOptions.data.tenant.domain;
    return fs.readFile(sitemapFile, function(err, contents) {
      var renderUrl;
      if (err) {
        return console.log("error reading sitemap.xml:", err);
      }
      renderUrl = function(location, done) {
        var url;
        url = location.loc[0].replace(/{{tenant.domain}}/, domain).replace(/#!/, '?_escaped_fragment_=');
        if (!~url.search(/_escaped_fragment_/)) {
          url += '?_escaped_fragment_=/';
        }
        console.log("request url:", url);
        return request.get(url, done);
      };
      return xml2js.parseString(contents, function(err, result) {
        var sitemap;
        if (err) {
          return console.log("error parsing sitemap.xml:", err);
        }
        sitemap = result.urlset.url;
        return async.mapSeries(sitemap, renderUrl, function(err, results) {
          if (err) {
            return console.log("error requesting urls:", err);
          }
        });
      });
    });
  });

  gulp.task('build-site', gulp.series('clean', gulp.parallel('coffee', 'browserifyCoffee', 'css', 'fonts', 'images', 'robots', 'index', 'javascript', 'templates')));

  gulp.task('app', gulp.series('clean', gulp.parallel('coffee', 'browserifyCoffee', 'css', 'fonts', 'images', 'sounds', 'populateTenant', 'appIndex', 'javascript', 'templates')));

  gulp.task('run-prerender', gulp.series('populateTenant', 'prerender'));

  gulp.task('default', (function(_this) {
    return function() {
      return runSequential(['build-site', 'nodemon']);
    };
  })(this));

}).call(this);