APP = window.APP
APP.Services.factory('Format', [ ->
  Format = {
    checkDOB: (user) ->
      return unless user.dob
      dob = moment(user.dob)
      return unless dob.isValid()
      year = parseInt(dob.get('year'), 10)
      if year < 1900
        if year < 20
          year += 2000
        else
          year += 1900
        dob.set('year', year)
      if @supportsDateType()
        format = 'YYYY-MM-DD'
      else
        format = 'MM/DD/YYYY'
      formatted = dob.format(format)
      user.dob = formatted unless user.dob is formatted

    checkSSN: (user) ->
      return unless user?.ssn
      user.ssn = user.ssn.replace(/[^\d]/g, '')

    supportsDateType: ->
      type = 'date'
      input = document.createElement("input")
      input.setAttribute("type", type)
      return input.type is type
  }

  _.bindAll.apply _, [Format].concat(_.functions(Format))

  return Format
])
