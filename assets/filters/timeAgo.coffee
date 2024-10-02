APP = window.APP
APP.Filters.filter 'timeAgo', ->

  templates =
    prefix: ''
    suffix: ' ago'
    seconds: 'less than a minute'
    minute: 'a minute'
    minutes: '%d minutes'
    hour: 'an hour'
    hours: '%d hours'
    day: 'a day'
    days: '%d days'
    month: 'a month'
    months: '%d months'
    year: 'a year'
    years: '%d years'

  template = (t, n) -> templates[t] and templates[t].replace /%d/i, Math.abs Math.round n

  (time) ->
    return 'Never' if not time

    time = time.replace /\.\d+/, ''
    time = time.replace(/-/, '/').replace /-/, '/'
    time = time.replace(/T/, ' ').replace /Z/, ' UTC'
    time = time.replace /([\+\-]\d\d)\:?(\d\d)/, ' $1$2'
    time = new Date time * 1000 || time

    now = new Date
    seconds = ((now.getTime() - time) * .001) >> 0
    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24
    years = days / 365

    return templates.prefix + (
      seconds < 45 and template('seconds', seconds) or
      seconds < 90 and template('minute', 1) or
      minutes < 45 and template('minutes', minutes) or
      minutes < 90 and template('hour', 1) or
      hours < 24 and template('hours', hours) or
      hours < 42 and template('day', 1) or
      days < 30 and template('days', days) or
      days < 45 and template('month', 1) or
      days < 365 and template('months', days / 30) or
      years < 1.5 and template('year', 1) or
      template 'years', years
      ) + templates.suffix

