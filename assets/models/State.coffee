APP = window.APP
APP.Models.factory('State', ['$resource', ($resource) ->
  State = $resource(
    APIURL + '/states',
    {},
    {
      active:         { method: 'GET',  url: APIURL + '/states/active',         isArray: true }
      adminIndex:     { method: 'GET',  url: APIURL + '/admin/states/index',    isArray: true }
      adminRead:      { method: 'GET',  url: APIURL + '/admin/states/:id'                     }
      adminUpdate:    { method: 'PUT',  url: APIURL + '/admin/states'                         }
      byUser:         { method: 'GET',  url: APIURL + '/states/user/:id',       isArray: true }
      create:         { method: 'POST', url: APIURL + '/admin/states'                         }
      findUser:       { method: 'POST', url: APIURL + '/states/find/user'                     }
      get:            { method: 'GET',  url: APIURL + '/states/:id'                           }
      index:          { method: 'GET',  url: APIURL + '/states/index',          isArray: true }
      init:           { method: 'GET',  url: APIURL + '/states/init/:id',       isArray: true }
      montanaCaptcha: { method: 'GET',  url: APIURL + '/states/montana/captcha'               }
      update:         { method: 'PUT'                                                         }
    }
  )

  State.stateList = [
    "Alabama"
    "Alaska"
    "Alberta"
    "APO"
    "Arizona"
    "Arkansas"
    "Atlantic FPO"
    "British Columbia"
    "California"
    "Colorado"
    "Connecticut"
    "Delaware"
    "District of Columbia"
    "Florida"
    "Georgia"
    "Guam"
    "Hawaii"
    "Idaho"
    "Illinois"
    "Indiana"
    "International"
    "Iowa"
    "Kansas"
    "Kentucky"
    "Louisiana"
    "Maine"
    "Manitoba"
    "Maryland"
    "Massachusetts"
    "Michigan"
    "MILITARY POST"
    "Minnesota"
    "Mississippi"
    "Missouri"
    "Montana"
    "Nebraska"
    "Nevada"
    "New Brunswick"
    "New Hampshire"
    "New Jersey"
    "New Mexico"
    "New York"
    "Newfoundland"
    "North Carolina"
    "North Dakota"
    "NorthWest Territories"
    "Nova Scotia"
    "Ohio"
    "Oklahoma"
    "Ontario"
    "Oregon"
    "Pacific FPO"
    "Pennsylvania"
    "Puerto Rico"
    "Quebec"
    "Rhode Island"
    "Saskatchewan"
    "South Carolina"
    "South Dakota"
    "Tennessee"
    "Texas"
    "Utah"
    "Vermont"
    "Virgin Islands"
    "Virginia"
    "Washington"
    "West Virginia"
    "Wisconsin"
    "Wyoming"
    "Yukon Territory"
  ]

  return State;
])
