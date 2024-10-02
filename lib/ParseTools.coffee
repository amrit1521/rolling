_ = require "underscore"
$ = require "cheerio"
request = require "request"
URL = require "url"

module.exports = (logger) ->

  ParseTools = {

    eye2Color: {
      'Black': 'BK'
      'Blue': 'BL'
      'Brown': 'BR'
      'Green': 'GR'
      'Gray': 'GY'
      'Hazel': 'HZ'
      'Violet': 'VO'
    }

    eye3Color: {
      'Black': 'BLK'
      'Blue': 'BLU'
      'Brown': 'BRN'
      'Green': 'GRN'
      'Gray': 'GRY'
      'Hazel': 'HZL'
      'Violet': 'VOL'
    }

    hair2Color: {
      'Bald': 'BD'
      'Black': 'BK'
      'Blonde': 'BL'
      'Brown': 'BR'
      'Gray': 'GY'
      'Red': 'RD'
      'Sandy': 'SD'
      'White': 'WH'
    }

    hair3Color: {
      'Bald': 'BLD'
      'Black': 'BLK'
      'Blonde': 'BLN'
      'Brown': 'BRN'
      'Gray': 'GRY'
      'Red': 'RED'
      'Sandy': 'SDY'
      'White': 'WHT'
    }

    gender1: {
      'Male': 'M'
      'Female': 'F'
    }

    gender2: {
      'Male': 'ML'
      'Female': 'FM'
    }

    country3Index: {
      "AFGHANISTAN": "AFG"
      "ALBANIA": "ALB"
      "ALGERIA": "DZA"
      "AMERICAN SAMOA": "ASM"
      "ANDORRA": "AND"
      "ANGOLA": "AGO"
      "ANGUILLA": "AIA"
      "ANTARCTICA": "ATA"
      "ANTIGUA AND BARBUDA": "ATG"
      "ARGENTINA": "ARG"
      "ARMENIA": "ARM"
      "ARUBA": "ABW"
      "Australia": "AUS"
      "Austria": "AUT"
      "AZERBAIJAN": "AZE"
      "BAHAMAS": "BHS"
      "BAHRAIN": "BHR"
      "BANGLADESH": "BGD"
      "BARBADOS": "BRB"
      "BELARUS": "BLR"
      "BELGIUM": "BEL"
      "BELIZE": "BLZ"
      "BENIN": "BEN"
      "BERMUDA": "BMU"
      "BHUTAN": "BTN"
      "BOLIVIA": "BOL"
      "BOSNIA AND HERZEGOVINA": "BIH"
      "BOTSWANA": "BWA"
      "BOUVET ISLAND": "BVT"
      "BRAZIL": "BRA"
      "BRITISH INDIAN OCEAN TERRITORY": "IOT"
      "BRUNEI DARUSSALAM": "BRN"
      "BULGARIA": "BGR"
      "BURKINA FASO": "BFA"
      "BURUNDI": "BDI"
      "CAMBODIA": "KHM"
      "CAMEROON": "CMR"
      "Canada": "CAN"
      "CAPE VERDE": "CPV"
      "CAYMAN ISLANDS": "CYM"
      "CENTRAL AFRICAN REPUBLIC": "CAF"
      "CHAD": "TCD"
      "CHILE": "CHL"
      "CHINA (PRC)": "CHN"
      "CHRISTMAS ISLAND": "CXR"
      "COCOS (KEELING) ISLANDS": "CCK"
      "COLUMBIA": "COL"
      "COMOROS": "COM"
      "CONGO": "COG"
      "COOK ISLANDS": "COK"
      "COSTA RICA": "CRI"
      "COTE D'IVOIRE": "CIV"
      "CROATIA": "HRV"
      "CUBA": "CUB"
      "CYPRUS": "CYP"
      "CZECH REPUBLIC": "CZE"
      "Denmark": "DNK"
      "DJIBOUTI": "DJI"
      "DOMINICA": "DMA"
      "DOMINICAN REPUBLIC": "DOM"
      "EAST TIMOR": "TMP"
      "ECUADOR": "ECU"
      "EGYPT": "EGY"
      "EL SALVADOR": "SLV"
      "EQUATORIAL GUINEA": "GNQ"
      "ERITREA": "ERI"
      "ESTONIA": "EST"
      "ETHIOPIA": "ETH"
      "FALKLAND ISLANDS (MALVINAS)": "FLK"
      "FAROE ISLANDS": "FRO"
      "FIJI": "FJI"
      "FINLAND": "FIN"
      "FRANCE": "FRA"
      "FRANCE, METROPOLITAN": "FXX"
      "FRENCH GUIANA": "GUF"
      "FRENCH POLYNESIA": "PYF"
      "FRENCH SOUTHERN TERRITORIES": "ATF"
      "GABON": "GAB"
      "GAMBIA": "GMB"
      "GEORGIA": "GEO"
      "GERMANY": "DEU"
      "GHANA": "GHA"
      "GIBRALTAR": "GIB"
      "GRANADA": "GRD"
      "GREECE": "GRC"
      "GREENLAND": "GRL"
      "GUADELOUPE": "GLP"
      "GUAM": "GUM"
      "GUATEMALA": "GTM"
      "GUINEA": "GIN"
      "GUINEA-BISSAU": "GNB"
      "GUYANA": "GUY"
      "HAITI": "HTI"
      "HEARD AND MCDONALD ISLANDS": "HMD"
      "HONDURAS": "HND"
      "HONG KONG": "HKG"
      "HUNGARY": "HUN"
      "ICELAND": "ISL"
      "INDIA": "IND"
      "INDONESIA": "IDN"
      "IRAN (ISLAMIC REPUBLIC OF)": "IRN"
      "IRAQ": "IRQ"
      "IRELAND": "IRL"
      "ISRAEL": "ISR"
      "Italy": "ITA"
      "JAMAICA": "JAM"
      "JAPAN": "JPN"
      "JORDAN": "JOR"
      "KAZAKHSTAN": "KAZ"
      "KENYA": "KEN"
      "KIRIBATI": "KIR"
      "KOREA, DEMOCRATIC PPL'S REPUB": "PRK"
      "KOREA, REPUBLIC OF": "KOR"
      "KUWAIT": "KWT"
      "KYRGYZSTAN": "KGZ"
      "LAO PPL'S DEMOCRATIC REPUB": "LAO"
      "LATVIA": "LVA"
      "LEBANON": "LBN"
      "LESOTHO": "LSO"
      "LIBERIA": "LBR"
      "LIBYAN ARAB JAMAHIRIYA": "LBY"
      "LIECHTENSTEIN": "LIE"
      "LITHUANIA": "LTU"
      "LUXEMBOURG": "LUX"
      "MACAU": "MAC"
      "MADAGASCAR": "MDG"
      "MALAWI": "MWI"
      "MALAYSIA": "MYS"
      "MALDIVES": "MDV"
      "MALI": "MLI"
      "MALTA": "MLT"
      "MARSHALL ISLANDS": "MHL"
      "MARTINIQUE": "MTQ"
      "MAURITANIA": "MRT"
      "MAURITIUS": "MUS"
      "MAYOTTE": "MYT"
      "Mexico": "MEX"
      "MICRONESIA": "FSM"
      "MOLDOVA, REPUBLIC OF": "MDA"
      "MONACO": "MCO"
      "MONGOLIA": "MNG"
      "MONTSERRAT": "MSR"
      "MOROCCO": "MAR"
      "MOZAMBIQUE": "MOZ"
      "MYANMAR": "MMR"
      "NAMIBIA": "NAM"
      "NAURU": "NRU"
      "NEPAL": "NPL"
      "NETHERLANDS ANTILLES": "ANT"
      "NETHERLANDS": "NLD"
      "NEW CALEDONIA": "NCL"
      "New Zealand": "NZL"
      "NICARAGUA": "NIC"
      "NIGER": "NER"
      "NIGERIA": "NGA"
      "NIUE": "NIU"
      "NORFOLK ISLAND": "NFK"
      "NORTHERN MARIANA ISLANDS": "MNP"
      "NORWAY": "NOR"
      "OMAN": "OMN"
      "PAKISTAN": "PAK"
      "PALAU": "PLW"
      "PANAMA": "PAN"
      "PAPUA NEW GUINEA": "PNG"
      "PARAGUAY": "PRY"
      "PERU": "PER"
      "PHILIPPINES": "PHL"
      "PITCAIRN": "PCN"
      "POLAND": "POL"
      "PORTUGAL": "PRT"
      "PUERTO RICO": "PRI"
      "QATAR": "QAT"
      "REUNION": "REU"
      "ROMANIA": "ROM"
      "RUSSIAN FEDERATION": "RUS"
      "RWANDA": "RWA"
      "S. GEORGIA &amp; S. SANDWICH ISL": "SGS"
      "SAINT KITTS AND NEVIA": "KNA"
      "SAINT LUCIA": "LCA"
      "SAMOA": "WSM"
      "SAN MARINO": "SMR"
      "SAO TOME AND PRINCIPE": "STP"
      "SAUDI ARABIA": "SAU"
      "SENEGAL": "SEN"
      "SEYCHELLES": "SYC"
      "SIERRA LEONE": "SLE"
      "SINGAPORE": "SGP"
      "SLOVAKIA": "SVK"
      "SLOVENIA": "SVN"
      "SOLOMON ISLANDS": "SLB"
      "SOMALIA": "SOM"
      "SOUTH AFRICA": "ZAF"
      "SPAIN": "ESP"
      "SRI LANKA": "LKA"
      "ST. HELENA": "SHN"
      "ST. PIERRE AND MIQUELON": "SPM"
      "ST. VINCENT AND THE GRENADINES": "VCT"
      "SUDAN": "SDN"
      "SURINAME": "SUR"
      "SVALBARD AND JAN MAYEN ISLANDS": "SJM"
      "SWAZILAND": "SWZ"
      "SWEDEN": "SWE"
      "SWITZERLAND": "CHE"
      "SYRIAN ARAB REPUBLIC": "SYR"
      "TAIWAN, PROVINCE OF CHINA": "TWN"
      "TAJIKISTAN": "TJK"
      "TANZANIA, UNITED REPUBLIC OF": "TZA"
      "THAILAND": "THA"
      "TOGO": "TGO"
      "TOKELAU": "TKL"
      "TONGA": "TON"
      "TRINIDAD AND TOBAGO": "TTO"
      "TUNISIA": "TUN"
      "TURKEY": "TUR"
      "TURKMENISTAN": "TKM"
      "TURKS AND CAICOS ISLANDS": "TCA"
      "TUVALU": "TUV"
      "UGANDA": "UGA"
      "UKRAINE": "UKR"
      "UNITED ARAB EMIRATES": "ARE"
      "UNITED KINGDOM": "GBR"
      "United States": "USA"
      "URUGUAY": "URY"
      "US MINOR OUTLYING ISLANDS": "UMI"
      "UZBEKISTAN": "UZB"
      "VANUATU": "VUT"
      "VATICAN CITY STATE": "VAT"
      "VENEZUELA": "VEN"
      "VIET NAM": "VNM"
      "VIRGIN ISLANDS (BRITISH)": "VGB"
      "VIRGIN ISLANDS (US)": "VIR"
      "WALLIS AND FUTUNA ISLANDS": "WLF"
      "WESTERN SAHARA": "ESH"
      "YEMEN": "YEM"
      "YUGOSLAVIA": "YUG"
      "ZAIRE": "ZAR"
      "ZAMBIA": "ZMB"
      "ZIMBABWE": "ZWE"
    }

    country2Index: {
      "Afghanistan": "AF"
      "Albania": "AL"
      "Algeria": "DZ"
      "American Samoa": "AS"
      "Andorra": "AD"
      "Angola": "AO"
      "Anguilla": "AI"
      "Antarctica": "AQ"
      "Antigua and Barbuda": "AG"
      "Argentina": "AR"
      "Armenia": "AM"
      "Aruba": "AW"
      "Australia": "AU"
      "Austria": "AT"
      "Azerbaijan": "AZ"
      "Bahamas": "BS"
      "Bahrain": "BH"
      "Bangladesh": "BD"
      "Barbados": "BB"
      "Belarus": "BY"
      "Belgium": "BE"
      "Belize": "BZ"
      "Benin": "BJ"
      "Bermuda": "BM"
      "Bhutan": "BT"
      "Bolivia": "BO"
      "Bosnia and Herzegovina": "BA"
      "Botswana": "BW"
      "Bouvet Island": "BV"
      "Brazil": "BR"
      "British Indian Ocean Territory": "IO"
      "Brunei Darussalam": "BN"
      "Bulgaria": "BG"
      "Burkina Faso": "BF"
      "Burundi": "BI"
      "Cambodia": "KH"
      "Cameroon": "CM"
      "Canada": "CA"
      "Cape Verde": "CV"
      "Cayman Islands": "KY"
      "Central African Republic": "CF"
      "Chad": "TD"
      "Chile": "CL"
      "China": "CN"
      "Christmas Island": "CX"
      "Cocos (Keeling) Islands": "CC"
      "Colombia": "CO"
      "Comoros": "KM"
      "Congo": "CG"
      "Congo, The Democratic Republic Of": "CD"
      "Cook Islands": "CK"
      "Costa Rica": "CR"
      "Cote d'Ivoire": "CI"
      "Croatia": "HR"
      "Cuba": "CU"
      "Cyprus": "CY"
      "Czech Republic": "CZ"
      "Denmark": "DK"
      "Djibouti": "DJ"
      "Dominica": "DM"
      "Dominican Republic": "DO"
      "East Timor": "TP"
      "Ecuador": "EC"
      "Egypt": "EG"
      "El Salvador": "SV"
      "Equatorial Guinea": "GQ"
      "Eritrea": "ER"
      "Estonia": "EE"
      "Ethiopia": "ET"
      "Falkland Islands (Malvinas)": "FK"
      "Faroe Islands": "FO"
      "Fiji": "FJ"
      "Finland": "FI"
      "France": "FR"
      "French Guiana": "GF"
      "French Polynesia": "PF"
      "French Southern Territories": "TF"
      "Gabon": "GA"
      "Gambia": "GM"
      "Georgia": "GE"
      "Germany": "DE"
      "Ghana": "GH"
      "Gibraltar": "GI"
      "Greece": "GR"
      "Greenland": "GL"
      "Grenada": "GD"
      "Guadeloupe": "GP"
      "Guam": "GU"
      "Guatemala": "GT"
      "Guinea": "GN"
      "Guinea-Bissau": "GW"
      "Guyana": "GY"
      "Haiti": "HT"
      "Heard Island And McDonald Islands": "HM"
      "Holy See (Vatican City State)": "VA"
      "Honduras": "HN"
      "Hong Kong": "HK"
      "Hungary": "HU"
      "Iceland": "IS"
      "India": "IN"
      "Indonesia": "ID"
      "Iran, Islamic Republic Of": "IR"
      "Iraq": "IQ"
      "Ireland": "IE"
      "Israel": "IL"
      "Italy": "IT"
      "Jamaica": "JM"
      "Japan": "JP"
      "Jordan": "JO"
      "Kazakstan": "KZ"
      "Kenya": "KE"
      "Kiribati": "KI"
      "Korea, Democratic People's Republic Of": "KP"
      "Korea, Republic Of": "KR"
      "Kuwait": "KW"
      "Kyrgyzstan": "KG"
      "Lao People's Democratic Republic": "LA"
      "Latvia": "LV"
      "Lebanon": "LB"
      "Lesotho": "LS"
      "Liberia": "LR"
      "Libyan Arab Jamahiriya": "LY"
      "Liechtenstein": "LI"
      "Lithuania": "LT"
      "Luxembourg": "LU"
      "Macau": "MO"
      "Macedonia, The Former Yugoslav Republic of": "MK"
      "Madagascar": "MG"
      "Malawi": "MW"
      "Malaysia": "MY"
      "Maldives": "MV"
      "Mali": "ML"
      "Malta": "MT"
      "Marshall Islands": "MH"
      "Martinique": "MQ"
      "Mauritania": "MR"
      "Mauritius": "MU"
      "Mayotte": "YT"
      "Mexico": "MX"
      "Micronesia, Federated States of": "FM"
      "Moldova, Republic of": "MD"
      "Monaco": "MC"
      "Mongolia": "MN"
      "Montserrat": "MS"
      "Morocco": "MA"
      "Mozambique": "MZ"
      "Myanmar": "MM"
      "Namibia": "NA"
      "Nauru": "NR"
      "Nepal": "NP"
      "Netherlands": "NL"
      "Netherlands Antilles": "AN"
      "New Caledonia": "NC"
      "New Zealand": "NZ"
      "Nicaragua": "NI"
      "Niger": "NE"
      "Nigeria": "NG"
      "Niue": "NU"
      "Norfolk Island": "NF"
      "Northern Mariana Islands": "MP"
      "Norway": "NO"
      "Oman": "OM"
      "Pakistan": "PK"
      "Palau": "PW"
      "Palestinian Territory, Occupied": "PS"
      "Panama": "PA"
      "Papua New Guinea": "PG"
      "Paraguay": "PY"
      "Peru": "PE"
      "Philippines": "PH"
      "Pitcairn": "PN"
      "Poland": "PL"
      "Portugal": "PT"
      "Puerto Rico": "PR"
      "Qatar": "QA"
      "Reunion": "RE"
      "Romania": "RO"
      "Russian Federation": "RU"
      "Rwanda": "RW"
      "Saint Helena": "SH"
      "Saint Kitts and Nevis": "KN"
      "Saint Lucia": "LC"
      "Saint Pierre and Miquelon": "PM"
      "Saint Vincent and The Grenadines": "VC"
      "Samoa": "WS"
      "San Marino": "SM"
      "Sao Tome and Principe": "ST"
      "Saudi Arabia": "SA"
      "Senegal": "SN"
      "Seychelles": "SC"
      "Sierra Leone": "SL"
      "Singapore": "SG"
      "Slovakia": "SK"
      "Slovenia": "SI"
      "Solomon Islands": "SB"
      "Somalia": "SO"
      "South Africa": "ZA"
      "South Georgia and The South Sandwich Islands": "GS"
      "Spain": "ES"
      "Sri Lanka": "LK"
      "Sudan": "SD"
      "Suriname": "SR"
      "Svalbard And Jan Mayen": "SJ"
      "Swaziland": "SZ"
      "Sweden": "SE"
      "Switzerland": "CH"
      "Syrian Arab Republic": "SY"
      "Taiwan, Province of China": "TW"
      "Tajikistan": "TJ"
      "Tanzania, United Republic Of": "TZ"
      "Thailand": "TH"
      "Togo": "TG"
      "Tokelau": "TK"
      "Tonga": "TO"
      "Trinidad and Tobago": "TT"
      "Tunisia": "TN"
      "Turkey": "TR"
      "Turkmenistan": "TM"
      "Turks and Caicos Islands": "TC"
      "Tuvalu": "TV"
      "Uganda": "UG"
      "Ukraine": "UA"
      "United Arab Emirates": "AE"
      "United Kingdom": "GB"
      "United States": "US"
      "United States Minor Outlying Islands": "UM"
      "Uruguay": "UY"
      "Uzbekistan": "UZ"
      "Vanuatu": "VU"
      "Venezuela": "VE"
      "Vietnam": "VN"
      "Virgin Islands, British": "VG"
      "Virgin Islands, U.S.": "VI"
      "Wallis and Futuna": "WF"
      "Western Sahara": "EH"
      "Yemen": "YE"
      "Yugoslavia": "YU"
      "Zambia": "ZM"
      "Zimbabwe": "ZW"
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
      "PE": "Prince Edward Island"
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
      state = "New Mexico" if state is "NewMexico"
      states = _.invert @states
      return states[state] if state and states[state]
      return state

    parseCallbacks: {
      errorHandler: {
        warning: -> null
        error: -> null
        fatalError: -> null
      }
    }

    ###
    opts = {
      url
      data
      fields
      selector
      jar
    }
    ###
    postForm: (opts, cb) ->
      opts.jar ?= request.jar()

      logger.info 'postForm::url.1:', opts.url
      request {method: 'GET', url: opts.url, jar: opts.jar}, (err, response, body) =>
        return cb err if err

        logger.info 'postForm::body.1:', body

        return cb {error: "unable to find the selector: " + opts.selector} if opts.selector and not $(body).find(opts.selector).length

        data = @inputs opts.selector, body
        data = _.extend({}, data, opts.data)
        if opts?.fields instanceof Array
          fields = opts.fields
          fields.unshift data
          data = _.pick.apply _, fields

        data = @getFields(body, opts.selector, opts?.fields, opts.data)

        logger.info "ParseTools::postForm opts:", opts

        if opts.selector
          url = URL.resolve opts.url, $(body).find(opts.selector).attr 'action'
        else
          url = URL.resolve opts.url, $(body).find('form').first().attr 'action'

        url ?= opts.url

        logger.info 'postForm::url.2:', url
        logger.info 'postForm::data.2:', data
        request {method: 'POST', url, jar: opts.jar, form: data}, (err, response, body) ->
          return cb err if err

          logger.info 'postForm::body.2', body
          logger.info 'postForm::headers:', response.headers

          return cb null, response, body

    getFields: (body, selector, fields, setData = {}) ->
      data = @inputs selector, body
      data = _.extend({}, data, setData)
      if fields instanceof Array
        fields.unshift data
        data = _.pick.apply _, fields
      data

    getPage: (opts, cb) ->
      request {method: 'GET', jar: opts.jar, url: opts.url}, (err, response, body) ->
        return cb err if err
        cb null, response, body

    inputs: (selector, body) ->
      startForm = $(body)
      inputs = []

      if selector
        inputs = startForm.find(selector).find('input')
      else
        inputs = startForm.find('input')

      data = {}
      inputs.each ->
        data[$(this).attr('name')] = $(this).val()

      return data

    updateField: (object, field, value, override) ->
      if value and value.length and (!object[field] or !object[field].length or override)
        object.__changed = [] unless object.__changed
        console.log 'updating [' + field + ']:', value
        object.__changed.push field
        object[field] = value

    updateUserFieldValue: (user, field, value, matches, done) ->
      if !done and typeof matches == 'function'
        done = matches
        matches = null
      #console.log 'Utils - Update User Field Value:', field
      if matches and matches[value]
        value = matches[value]
      @updateField user, field, value
      done() if done

    overrideUpdateUserFieldValue: (user, field, value, matches, done) ->
      if !done and typeof matches == 'function'
        done = matches
        matches = null
      #console.log 'Utils - Update User Field Value:', field
      if matches and matches[value]
        value = matches[value]
      @updateField user, field, value, true
      done() if done

    stateAbbreviation: (state) ->
      states = _.invert @states
      return states[state]

    stateFromAbbreviation: (abbreviation) ->

    keysrt: (key) ->
      (a, b) ->
        if a[key] > b[key]
          return 1
        if a[key] < b[key]
          return -1
        0

    appLog: (opts, message) ->
      return unless opts and message and opts.channel
      console.log message
      messageContainer = {
        type: opts.type
        data: {appUserId: opts.appUserId, message: message}
        error: null
      }
      opts.pubnub.publish {
        channel: opts.channel
        message: messageContainer
        callback: (e) ->
          console.log "Message published.", e
          return
        error: (e) ->
          console.log "PUBNUB failed message publish!", e
          return
      }
      #console.log "Done sending appLog message to channel: #{opts.channel}"


    getEmail: (user, adminUser) ->
      #Note: It looks like somewhere upstream the user.email is being already replaced with adminUser.email for certain tenants.
      if user.tenantId?.toString() is "52c5fa9d1a80b40fd43f2fdd"
        return "shandi@huntinfool.com" if user.email is "scott@gotmytag.com" or user.email is "byron@gotmytag.com" or user.email is "ryan@gotmytag.com"
      return "support@gotmytag.com" if user.email is "scott@gotmytag.com" or user.email is "byron@gotmytag.com" or user.email is "ryan@gotmytag.com"
      return user.email

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
        console.log "could not parse name!:", name

      names
  }

  _.bindAll.apply _, [ParseTools].concat(_.functions(ParseTools))
  ParseTools
