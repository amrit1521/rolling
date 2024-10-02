APP = window.APP
APP.Models.factory('User', ['$resource', ($resource) ->

  User = $resource(
    APIURL + '/users',
    {},
    {
      cards: { method: 'GET', url: APIURL + '/users/cards/:id' }
      cardUpdate: { method: 'POST', url: APIURL + '/users/cardUpdate' }
      changePassword: { method: 'POST', url: APIURL + '/users/changepassword' }
      changeParent: { method: 'POST', url: APIURL + '/users/changeparent' }
      defaultUser: { method: "POST", url: APIURL + '/users/defaultUser' }
      get: { method: 'GET', url: APIURL + '/users/:id' }
      getMQ: { method: 'GET', url: APIURL + '/users/:id/:topToken', params: {id: '@id', topToken: '@topToken'} }
      update: { method: 'PUT', isArray: false }
      updateClient: { method: 'POST', url: APIURL + '/users/client' }
      index: { method: 'GET' }
      login: { method: 'POST', url: APIURL + '/users/login' }
      loginPassthrough: { method: 'POST', url: APIURL + '/users/loginPassthrough' }
      getStamp: { method: 'POST', url: APIURL + '/stamp/get' }
      register: { method: 'POST', url: APIURL + '/users/register' }
      message: { method: 'POST', url: APIURL + '/users/messages' }
      points: { method: 'GET', isArray: true, url: APIURL + '/users/points/:userId', params: {userId: '@userId'} }
      registerDevice: { method: 'POST', url: APIURL + '/users/device/register' }
      setAdmin: { method: 'PUT', url: APIURL + '/users/admin/:userId/:isAdmin', params: {userId: '@userId', isAdmin: '@isAdmin'} }
      checkReferral: { method: 'POST', url: APIURL + '/users/refer' }
      checkExists: { method: 'POST', url: APIURL + '/users/checkexists' }
      testUsers: { method: 'POST', isArray: true, url: APIURL + '/users/testUsers', params: {tenantId: '@tenantId'} }
      getParentAndRep: {method: 'GET', url: APIURL + '/users/parent/rep/:userId', params: {userId: '@userId'} }
      getUserEmails: {method: 'GET', isArray: true, url: APIURL + '/users/emails/by/clients/:clientIds', params: {clientIds: '@clientIds'} }
      sendWelcomeEmails: {method: 'POST', isArray: true, url: APIURL + '/users/emails/send_welcome/emails'}
      getByClientId: {method: 'GET', url: APIURL + '/users/by/clientId/:clientId', params: {clientId: '@clientId'} }
      user_upsert_rads: { method: 'POST', url: APIURL + '/api/rbo/v1/user/user_upsert_rads' }
      reassign_rep_downline_all: { method: 'POST', url: APIURL + '/api/rbo/v1/user/reassign_rep_downline_all' }
      user_refresh_from_rrads: { method: 'POST', url: APIURL + '/api/rbo/v1/user/user_refresh_from_rrads' }
      user_import: { method: 'POST', isArray: true, url: APIURL + '/users/admin/userimport/userimport' }
    }
  )

  User.hairs = [
    # HAIR:
    'Bald'
    'Black'
    'Blonde'
    'Brown'
    'Gray'
    'Red'
    'White'
  ]

  User.genders = [
    # GENDER:
    'Female'
    'Male'
  ]

  User.eyes = [
    # EYES:
    'Black'
    'Blue'
    'Brown'
    'Green'
    'Gray'
    'Hazel'
  ]


  User.countryList = [
    "United States"
    "Afghanistan"
    "Albania"
    "Algeria"
    "American Samoa"
    "Andorra"
    "Angola"
    "Anguilla"
    "Antarctica"
    "Antigua and Barbuda"
    "Argentina"
    "Armenia"
    "Aruba"
    "Australia"
    "Austria"
    "Azerbaijan"
    "Bahamas"
    "Bahrain"
    "Bangladesh"
    "Barbados"
    "Belarus"
    "Belgium"
    "Belize"
    "Benin"
    "Bermuda"
    "Bhutan"
    "Bolivia"
    "Bosnia and Herzegovina"
    "Botswana"
    "Bouvet Island"
    "Brazil"
    "British Indian Ocean Territory"
    "Brunei Darussalam"
    "Bulgaria"
    "Burkina Faso"
    "Burundi"
    "Cambodia"
    "Cameroon"
    "Canada"
    "Cape Verde"
    "Cayman Islands"
    "Central African Republic"
    "Chad"
    "Chile"
    "China"
    "Christmas Island"
    "Cocos (Keeling) Islands"
    "Colombia"
    "Comoros"
    "Congo"
    "Cook Islands"
    "Costa Rica"
    "Cote d'Ivoire"
    "Croatia"
    "Cuba"
    "Cyprus"
    "Czech Republic"
    "Denmark"
    "Djibouti"
    "Dominica"
    "Dominican Republic"
    "East Timor"
    "Ecuador"
    "Egypt"
    "El Salvador"
    "Equatorial Guinea"
    "Eritrea"
    "Estonia"
    "Ethiopia"
    "Falkland Islands (Malvinas)"
    "Faroe Islands"
    "Fiji"
    "Finland"
    "France"
    "French Guiana"
    "French Polynesia"
    "French Southern Territories"
    "Gabon"
    "Gambia"
    "Georgia"
    "Germany"
    "Ghana"
    "Gibraltar"
    "Greece"
    "Greenland"
    "Grenada"
    "Guadeloupe"
    "Guam"
    "Guatemala"
    "Guinea"
    "Guinea-Bissau"
    "Guyana"
    "Haiti"
    "Heard Island And McDonald Islands"
    "Holy See (Vatican City State)"
    "Honduras"
    "Hong Kong"
    "Hungary"
    "Iceland"
    "India"
    "Indonesia"
    "Iran, Islamic Republic Of"
    "Iraq"
    "Ireland"
    "Israel"
    "Italy"
    "Jamaica"
    "Japan"
    "Jordan"
    "Kazakstan"
    "Kenya"
    "Kiribati"
    "Korea, Democratic People's Republic Of"
    "Korea, Republic Of"
    "Kuwait"
    "Kyrgyzstan"
    "Lao People's Democratic Republic"
    "Latvia"
    "Lebanon"
    "Lesotho"
    "Liberia"
    "Libyan Arab Jamahiriya"
    "Liechtenstein"
    "Lithuania"
    "Luxembourg"
    "Macau"
    "Macedonia, The Former Yugoslav Republic of"
    "Madagascar"
    "Malawi"
    "Malaysia"
    "Maldives"
    "Mali"
    "Malta"
    "Marshall Islands"
    "Martinique"
    "Mauritania"
    "Mauritius"
    "Mayotte"
    "Mexico"
    "Micronesia, Federated States of"
    "Moldova, Republic of"
    "Monaco"
    "Mongolia"
    "Montserrat"
    "Morocco"
    "Mozambique"
    "Myanmar"
    "Namibia"
    "Nauru"
    "Nepal"
    "Netherlands"
    "Netherlands Antilles"
    "New Caledonia"
    "New Zealand"
    "Nicaragua"
    "Niger"
    "Nigeria"
    "Niue"
    "Norfolk Island"
    "Northern Mariana Islands"
    "Norway"
    "Oman"
    "Pakistan"
    "Palau"
    "Panama"
    "Papua New Guinea"
    "Paraguay"
    "Peru"
    "Philippines"
    "Pitcairn"
    "Poland"
    "Portugal"
    "Puerto Rico"
    "Qatar"
    "Reunion"
    "Romania"
    "Russian Federation"
    "Rwanda"
    "Saint Helena"
    "Saint Kitts and Nevis"
    "Saint Lucia"
    "Saint Pierre and Miquelon"
    "Saint Vincent and The Grenadines"
    "Samoa"
    "San Marino"
    "Sao Tome and Principe"
    "Saudi Arabia"
    "Senegal"
    "Seychelles"
    "Sierra Leone"
    "Singapore"
    "Slovakia"
    "Slovenia"
    "Solomon Islands"
    "Somalia"
    "South Africa"
    "South Georgia and The South Sandwich Islands"
    "Spain"
    "Sri Lanka"
    "Sudan"
    "Suriname"
    "Svalbard And Jan Mayen"
    "Swaziland"
    "Sweden"
    "Switzerland"
    "Syrian Arab Republic"
    "Taiwan, Province of China"
    "Tajikistan"
    "Tanzania, United Republic Of"
    "Thailand"
    "Togo"
    "Tokelau"
    "Tonga"
    "Trinidad and Tobago"
    "Tunisia"
    "Turkey"
    "Turkmenistan"
    "Turks and Caicos Islands"
    "Tuvalu"
    "Uganda"
    "Ukraine"
    "United Arab Emirates"
    "United Kingdom"
    "United States"
    "United States Minor Outlying Islands"
    "Uruguay"
    "Uzbekistan"
    "Vanuatu"
    "Venezuela"
    "Vietnam"
    "Virgin Islands, British"
    "Virgin Islands, U.S."
    "Wallis and Futuna"
    "Western Sahara"
    "Yemen"
    "Yugoslavia"
    "Zambia"
    "Zimbabwe"
  ]

  return User
])
