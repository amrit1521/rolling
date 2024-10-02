_ = require "underscore"
$ = require "cheerio"
async = require "async"
request = require "request"
URL = require "url"

module.exports = (HF_DROPBOX_ROOTPATH, HF_DROPBOX_ACCESS_TOKEN, logger) ->

  GMTUSERAGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.98 Safari/537.36"

  NavTools = {

    form: (point, opts, oRes, oBody, cb) ->
      _.extend opts, _.pick(point, 'data', 'fields', 'selector', 'url')

      async.waterfall [
        (next) =>
          throw new Error 'body not found' if point.useBody and not oBody
          if point.useBody
            return next null, oRes, oBody
          else
            @link point, opts, next

        (response2, body2, next) =>

          if not body2
            logger.info "############## ERROR NO BODY ################:", body2
            return next {error: "NO BODY FOUND"}, response2, body2

          $body = $.load body2

          if opts.selector and not $body(opts.selector).length
            logger.error "opts.selector:", opts.selector
            logger.info "\n\n\n\n\n\n\n\n\n\n\n\n\n\n############## ERROR BODY ################:", body2
            logger.info "\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
            return next {error: "unable to find the selector: " + opts.selector}, response2, body2

          return next {error: "no fields specified"} unless opts.fields

          data = @getFields body2, opts.selector, opts.fields
          _.extend data, point.data if data

          if not point.url
            if opts.selector
              url = URL.resolve opts.url, $body(opts.selector).attr 'action'
            else if $body('form').first().length
              url = URL.resolve opts.url, $body('form').first().attr 'action'
            else
              url = opts.url
          else
            url = point.url

          connectAttempts = 3

          (
            (lPoint, lUrl, lOpts, lData, allDone) ->
              sendRequest = (done) ->
                followAllRedirects = if lPoint.followAllRedirects is false then lPoint.followAllRedirects else true
                options = {method: 'POST', url: lUrl, jar: lOpts.jar, form: lData, followAllRedirects}

                options.headers = lPoint.headers if lPoint.headers
                if lPoint.beforeData?.headers
                  if options.headers
                    _.extend options.headers, lPoint.beforeData.headers
                  else
                    options.headers = lPoint.beforeData.headers

                if lPoint.headerReferer
                  options.headers ?= {}
                  options.headers["referer"] = lOpts.lastURL

                options.headers ?= {}
                options.headers["User-Agent"] = GMTUSERAGENT
                #options.rejectUnauthorized = false

                console.log "Form url:", options.url if options.url
                console.log "Form data:", options.form if options.form
                console.log "Form headers:", options.headers if options.headers
                request options, (err, response3, body3) ->
                  console.log 'NavTools::form error:', err if err
                  connectAttempts--
                  if err?.code is 'ETIMEDOUT' and connectAttempts > 0
                    logger.info "handle timeout error"
                    delay = if lPoint.retryDelay then (lPoint.retryDelay * 1000) else 10000
                    return setTimeout ->
                      sendRequest done
                    , delay

                  else if err?.code is 'ETIMEDOUT'
                    return done {error: "Could not connect", code: 504}, response3, body3

                  return done err, response3, body3 if err
                  return done {error: "Bad Response", code: response3.statusCode}, response3, body3 unless response3.statusCode is 200

                  # I'm not sure if we need these two lines still -ryan
                  lOpts.fields = null
                  lOpts.data = null
                  lOpts.selector = null

                  lOpts.lastURL = lOpts.url

                  if response3.request?.href
                    lOpts.url = URL.resolve lOpts.url, response3.request.href
                  else
                    lOpts.url = URL.resolve lOpts.url, response3.req.path

                  done null, response3, body3

              sendRequest allDone
          )(point, url, opts, data, next)

      ], cb

    getFields: (body, selector, fields) ->
      $body = $.load body

      data = {}
      if selector
        $form = $body selector
      else
        $form = $body('form').first()

      if not $form.length
        $form = $body('body')

      for field in fields
        $input = $form.find '[name="' + field + '"]'
        if $input.length
          try
            data[field] = $input.val()
          catch error
            data[field] = ''
        else
          data[field] = ''

      data

    handleAfter: (err, point, response, body, cb) ->
      if point.after
        point.after err, response, body, cb
      else
        cb err, response, body

    handleBefore: (point, response, body, cb) ->
      if point.before
        point.before response, body, cb
      else
        cb null, {}

    link: (point, opts, cb) ->
      opts.url = point.url if point.url

      options = {method: 'GET', jar: opts.jar, url: opts.url}
      options.headers = point.headers if point.headers
      if point.beforeData?.headers
        if options.headers
          _.extend options.headers, point.beforeData.headers
        else
          options.headers = point.beforeData.headers

      if point.headerReferer
        options.headers ?= {}
        options.headers["referer"] = opts.lastURL

      options.headers ?= {}
      options.headers["User-Agent"] = GMTUSERAGENT

      console.log "Link url:", options.url if options.url
      request options, (err, response, body) ->
        console.log 'NavTools::link error:', err if err
        return cb {error: "Could not connect", code: 504}, response, body if err?.code is 'ETIMEDOUT'
        return cb err, response, body if err
        return cb {error: "Bad Response", code: response.statusCode}, response, body unless response.statusCode is 200

        opts.lastURL = opts.url
        if response.res?.request?.href
          opts.url = URL.resolve opts.url, response.res.request.href
        else
          opts.url = URL.resolve opts.url, response.req.path

        cb null, response, body

    loop: (point, opts, response, body, cb) ->

      prepItem = (item, done) ->
        if point.beforeEach
          point.beforeEach item, response, body, point.beforeData, done
        else
          done null, _.pick(point, 'data', 'fields', 'selector', 'url' )

      async.map point.items, prepItem, (err, parts) =>
        @run opts, parts, response, body, cb

    prepPoint: (point, opts, response, body) ->

      (response2, body2, done) =>

        if not done and typeof response2 is 'function'
          done = response2
          response2 = response
          body2 = body

        async.waterfall [
          (next) =>
            @handleBefore point, response2, body2, next
          (beforeData, next) ->
            if not next
              next = beforeData
              beforeData = null

            return next null, point unless beforeData

            _.extend point, _.pick(beforeData, 'data', 'fields', 'url')
            point.beforeData = beforeData

            next null, point

          (point, next) =>
            label = if point.label then point.label else ''

            switch point.action

              when 'link'
                logger.info "Link: #{label}"
                return @link point, opts, next
              when 'loop'
                logger.info "Loop: #{label}"
                return @loop point, opts, response2, body2, next
              when 'form'
                logger.info "Form: #{label}"
                return @form point, opts, response2, body2, next

              else
                if typeof point.action is 'function'
                  logger.info "Function: #{label}"
                  return point.action(opts, response2, body2, next)

                return next { error: "Point missing action type unknown: " + point.action }

        ], (err3, response3, body3) =>

          async.waterfall [

            (next) ->
              return next() if not point.review or err3

              $body = $.load body3
              $body('head').prepend "<base href=\"#{opts.lastURL}\" />"
              $body('script').each (index, script) ->
                $script = $(script)
                $script.remove() if ~$script.html().search /top\.location\.href/
              src = $body.html()
              logger.info "Paused for review"
              point.review src, (err) ->
                next err

            (next) =>
              @handleAfter err3, point, response3, body3, (err4, response4, body4) ->
                next err4, response4, body4

          ], (err6, response6, body6) ->
            return done err6, response6, body6 if err6

            # Intentional delay between page requests.  States sites seem to be happier if we give them a bit of a break.
            setTimeout =>
              done err6, response6, body6
            , 500 # 0.5 seconds

    required: (fields, user, operator) ->
      missing = []
      operator = 'and' unless operator
      operator = operator.toLowerCase()

      for field, name of fields
        user[field] = '' if user[field] and user[field] is 'undefined'

        if field.toLowerCase() is 'and'
          tmpMissing = @required(name, user, 'and')

          if not tmpMissing.length and operator is 'or'
            missing = []
            break

          continue unless tmpMissing.length

          if operator is 'and'
            missing = missing.concat tmpMissing
          else
            missing.push "(#{tmpMissing.join(', ')})"

        else if field.toLowerCase() is 'or'
          missing = missing.concat @required(name, user, 'or')

        else if user[field] and user[field]?.length and operator is 'or'
          missing = []
          break

        else if not user[field] or not ('' + user[field])?.length
          missing.push name

      missing = [] if operator is 'or' and missing.length isnt Object.keys(fields).length
      missing = ["one of the following (#{missing.join(', ')})"] if operator is 'or' and missing.length
      missing

    run: (opts, plan, response, body, cb) ->

      if not cb
        cb = response
        response = null
        body = null

      arr = []
      for point in plan
        arr.push @prepPoint point, opts, response, body

      async.waterfall arr, cb

    countries: {
      "AF": "Afghanistan"
      "AL": "Albania"
      "DZ": "Algeria"
      "AS": "American Samoa"
      "AD": "Andorra"
      "AO": "Angola"
      "AI": "Anguilla"
      "AQ": "Antarctica"
      "AG": "Antigua and Barbuda"
      "AR": "Argentina"
      "AM": "Armenia"
      "AW": "Aruba"
      "AU": "Australia"
      "AT": "Austria"
      "AZ": "Azerbaijan"
      "BS": "Bahamas"
      "BH": "Bahrain"
      "BD": "Bangladesh"
      "BB": "Barbados"
      "BY": "Belarus"
      "BE": "Belgium"
      "BZ": "Belize"
      "BJ": "Benin"
      "BM": "Bermuda"
      "BT": "Bhutan"
      "BO": "Bolivia"
      "BA": "Bosnia and Herzegovina"
      "BW": "Botswana"
      "BV": "Bouvet Island"
      "BR": "Brazil"
      "IO": "British Indian Ocean Territory"
      "BN": "Brunei Darussalam"
      "BG": "Bulgaria"
      "BF": "Burkina Faso"
      "BI": "Burundi"
      "KH": "Cambodia"
      "CM": "Cameroon"
      "CA": "Canada"
      "CV": "Cape Verde"
      "KY": "Cayman Islands"
      "CF": "Central African Republic"
      "TD": "Chad"
      "CL": "Chile"
      "CN": "China"
      "CX": "Christmas Island"
      "CC": "Cocos (Keeling) Islands"
      "CO": "Colombia"
      "KM": "Comoros"
      "CG": "Congo"
      "CK": "Cook Islands"
      "CR": "Costa Rica"
      "CI": "Cote d'Ivoire"
      "HR": "Croatia"
      "CU": "Cuba"
      "CY": "Cyprus"
      "CZ": "Czech Republic"
      "DK": "Denmark"
      "DJ": "Djibouti"
      "DM": "Dominica"
      "DO": "Dominican Republic"
      "TP": "East Timor"
      "EC": "Ecuador"
      "EG": "Egypt"
      "SV": "El Salvador"
      "GQ": "Equatorial Guinea"
      "ER": "Eritrea"
      "EE": "Estonia"
      "ET": "Ethiopia"
      "FK": "Falkland Islands (Malvinas)"
      "FO": "Faroe Islands"
      "FJ": "Fiji"
      "FI": "Finland"
      "FR": "France"
      "GF": "French Guiana"
      "PF": "French Polynesia"
      "TF": "French Southern Territories"
      "GA": "Gabon"
      "GM": "Gambia"
      "GE": "Georgia"
      "DE": "Germany"
      "GH": "Ghana"
      "GI": "Gibraltar"
      "GR": "Greece"
      "GL": "Greenland"
      "GD": "Grenada"
      "GP": "Guadeloupe"
      "GU": "Guam"
      "GT": "Guatemala"
      "GN": "Guinea"
      "GW": "Guinea-Bissau"
      "GY": "Guyana"
      "HT": "Haiti"
      "HM": "Heard Island And McDonald Islands"
      "VA": "Holy See (Vatican City State)"
      "HN": "Honduras"
      "HK": "Hong Kong"
      "HU": "Hungary"
      "IS": "Iceland"
      "IN": "India"
      "ID": "Indonesia"
      "IR": "Iran, Islamic Republic Of"
      "IQ": "Iraq"
      "IE": "Ireland"
      "IL": "Israel"
      "IT": "Italy"
      "JM": "Jamaica"
      "JP": "Japan"
      "JO": "Jordan"
      "KZ": "Kazakstan"
      "KE": "Kenya"
      "KI": "Kiribati"
      "KP": "Korea, Democratic People's Republic Of"
      "KR": "Korea, Republic Of"
      "KW": "Kuwait"
      "KG": "Kyrgyzstan"
      "LA": "Lao People's Democratic Republic"
      "LV": "Latvia"
      "LB": "Lebanon"
      "LS": "Lesotho"
      "LR": "Liberia"
      "LY": "Libyan Arab Jamahiriya"
      "LI": "Liechtenstein"
      "LT": "Lithuania"
      "LU": "Luxembourg"
      "MO": "Macau"
      "MK": "Macedonia, The Former Yugoslav Republic of"
      "MG": "Madagascar"
      "MW": "Malawi"
      "MY": "Malaysia"
      "MV": "Maldives"
      "ML": "Mali"
      "MT": "Malta"
      "MH": "Marshall Islands"
      "MQ": "Martinique"
      "MR": "Mauritania"
      "MU": "Mauritius"
      "YT": "Mayotte"
      "MX": "Mexico"
      "FM": "Micronesia, Federated States of"
      "MD": "Moldova, Republic of"
      "MC": "Monaco"
      "MN": "Mongolia"
      "MS": "Montserrat"
      "MA": "Morocco"
      "MZ": "Mozambique"
      "MM": "Myanmar"
      "NA": "Namibia"
      "NR": "Nauru"
      "NP": "Nepal"
      "NL": "Netherlands"
      "AN": "Netherlands Antilles"
      "NC": "New Caledonia"
      "NZ": "New Zealand"
      "NI": "Nicaragua"
      "NE": "Niger"
      "NG": "Nigeria"
      "NU": "Niue"
      "NF": "Norfolk Island"
      "MP": "Northern Mariana Islands"
      "NO": "Norway"
      "OM": "Oman"
      "PK": "Pakistan"
      "PW": "Palau"
      "PA": "Panama"
      "PG": "Papua New Guinea"
      "PY": "Paraguay"
      "PE": "Peru"
      "PH": "Philippines"
      "PN": "Pitcairn"
      "PL": "Poland"
      "PT": "Portugal"
      "PR": "Puerto Rico"
      "QA": "Qatar"
      "RE": "Reunion"
      "RO": "Romania"
      "RU": "Russian Federation"
      "RW": "Rwanda"
      "SH": "Saint Helena"
      "KN": "Saint Kitts and Nevis"
      "LC": "Saint Lucia"
      "PM": "Saint Pierre and Miquelon"
      "VC": "Saint Vincent and The Grenadines"
      "WS": "Samoa"
      "SM": "San Marino"
      "ST": "Sao Tome and Principe"
      "SA": "Saudi Arabia"
      "SN": "Senegal"
      "SC": "Seychelles"
      "SL": "Sierra Leone"
      "SG": "Singapore"
      "SK": "Slovakia"
      "SI": "Slovenia"
      "SB": "Solomon Islands"
      "SO": "Somalia"
      "ZA": "South Africa"
      "GS": "South Georgia and The South Sandwich Islands"
      "ES": "Spain"
      "LK": "Sri Lanka"
      "SD": "Sudan"
      "SR": "Suriname"
      "SJ": "Svalbard And Jan Mayen"
      "SZ": "Swaziland"
      "SE": "Sweden"
      "CH": "Switzerland"
      "SY": "Syrian Arab Republic"
      "TW": "Taiwan, Province of China"
      "TJ": "Tajikistan"
      "TZ": "Tanzania, United Republic Of"
      "TH": "Thailand"
      "TG": "Togo"
      "TK": "Tokelau"
      "TO": "Tonga"
      "TT": "Trinidad and Tobago"
      "TN": "Tunisia"
      "TR": "Turkey"
      "TM": "Turkmenistan"
      "TC": "Turks and Caicos Islands"
      "TV": "Tuvalu"
      "UG": "Uganda"
      "UA": "Ukraine"
      "AE": "United Arab Emirates"
      "GB": "United Kingdom"
      "US": "United States"
      "UM": "United States Minor Outlying Islands"
      "UY": "Uruguay"
      "UZ": "Uzbekistan"
      "VU": "Vanuatu"
      "VE": "Venezuela"
      "VN": "Vietnam"
      "VG": "Virgin Islands, British"
      "VI": "Virgin Islands, U.S."
      "WF": "Wallis and Futuna"
      "EH": "Western Sahara"
      "YE": "Yemen"
      "YU": "Yugoslavia"
      "ZM": "Zambia"
      "ZW": "Zimbabwe"
    }

    states: {
      "AL": "Alabama"
      "AK": "Alaska"
      "AB": "Alberta"
      "AE": "APO"
      "AZ": "Arizona"
      "AR": "Arkansas"
      "AA": "Atlantic FPO"
      "BC": "British Columbia"
      "CA": "California"
      "CO": "Colorado"
      "CT": "Connecticut"
      "DE": "Delaware"
      "DC": "District of Columbia"
      "FL": "Florida"
      "GA": "Georgia"
      "GU": "Guam"
      "HI": "Hawaii"
      "ID": "Idaho"
      "IL": "Illinois"
      "IN": "Indiana"
      "I": "International"
      "IA": "Iowa"
      "KS": "Kansas"
      "KY": "Kentucky"
      "LA": "Louisiana"
      "ME": "Maine"
      "MB": "Manitoba"
      "MD": "Maryland"
      "MA": "Massachusetts"
      "MI": "Michigan"
      "MP": "MILITARY POST"
      "MN": "Minnesota"
      "MS": "Mississippi"
      "MO": "Missouri"
      "MT": "Montana"
      "NE": "Nebraska"
      "NV": "Nevada"
      "NB": "New Brunswick"
      "NH": "New Hampshire"
      "NJ": "New Jersey"
      "NM": "New Mexico"
      "NY": "New York"
      "NF": "Newfoundland"
      "NC": "North Carolina"
      "ND": "North Dakota"
      "NW": "NorthWest Territories"
      "NS": "Nova Scotia"
      "OH": "Ohio"
      "OK": "Oklahoma"
      "ON": "Ontario"
      "OR": "Oregon"
      "AP": "Pacific FPO"
      "PA": "Pennsylvania"
      "PR": "Puerto Rico"
      "QU": "Quebec"
      "RI": "Rhode Island"
      "SK": "Saskatchewan"
      "SC": "South Carolina"
      "SD": "South Dakota"
      "TN": "Tennessee"
      "TX": "Texas"
      "UT": "Utah"
      "VT": "Vermont"
      "VI": "Virgin Islands"
      "VA": "Virginia"
      "WA": "Washington"
      "WV": "West Virginia"
      "WI": "Wisconsin"
      "WY": "Wyoming"
      "YT": "Yukon Territory"
    }

    stateAbbreviation: (state) ->
      states = _.invert @states
      return states[state] if state and states[state]
      state

    stateFromAbbreviation: (abbreviation) ->
      return @states[abbreviation.toUpperCase()] if abbreviation and @states[abbreviation.toUpperCase()]
      abbreviation

    countryAbbreviation: (country) ->
      return 'US' unless country?.length
      countries = _.invert @countries
      return countries[country]

    countryFromAbbreviation: (abbreviation) ->
      return 'United States' unless abbreviation?.length
      return @countries[abbreviation.toUpperCase()]

    uploadToDropbox: (dropboxStream, filePathName, cb) ->
      err = null
      url = "#{HF_DROPBOX_ROOTPATH}/#{filePathName}"
      logger.info "HuntinFool::uploadToDropbox::url", url

      options =
        method: 'PUT'
        url: url
        headers:
          'Content-Type': 'application/pdf'
          'Authorization': 'Bearer ' + HF_DROPBOX_ACCESS_TOKEN
        json: true

      apiReq = request(options, (err, rsp, body) ->
        logger.info "Dropbox Err:", err if err
        logger.info "Dropbox Rsp:", body
      )
      dropboxStream.pipe apiReq

      apiReq.on 'error', (dbErr) ->
        err = dbErr
        cb err
      apiReq.on 'end', ->
        dropboxStream = null
        cb err


    parseName: (name) ->

      names =
        prefix: ""
        first_name: ""
        middle_name: ""
        last_name: ""
        suffix: ""

      # NEAL E TOKOWITZ
      if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]

      # ARNOLD CHARLES PITTS
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]

      # CLAIRE PHELAN
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})$/)
        names =
          first_name: matches[1]
          last_name: matches[2]

      # EARL BENEDICT AXALAN MACASAET
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})\s+(\w{4,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2] + ' ' + matches[3]
          last_name: matches[4]

      # JOHN TITO BERTILACCHI JR
      else if matches = name.match(/^(\w{2,})\s+(\w{2,})\s+(\w{2,})\s+(\w{1,3})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]
          suffix: matches[4]

      # JAMES W CRAWFORD III
      else if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w{2,})\s+(\w{1,3})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2]
          last_name: matches[3]
          suffix: matches[4]

      # MR. SCOTT ALLEN FINLEY
      else if matches = name.match(/^([\w\.]{1,3})\s+(\w{2,})\s+(\w{2,})\s+(\w{2,})$/)
        names =
          prefix: matches[1]
          first_name: matches[2]
          middle_name: matches[3]
          last_name: matches[4]

      # BRETT D K VISSER
      else if matches = name.match(/^(\w{2,})\s+(\w)\s+(\w)\s+(\w{4,})$/)
        names =
          first_name: matches[1]
          middle_name: matches[2] + ' ' + matches[3]
          last_name: matches[4]

      else
        console.log "unmatched name:", name

      names



  }

  _.bindAll.apply _, [NavTools].concat(_.functions(NavTools))
  NavTools
