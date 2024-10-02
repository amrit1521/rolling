config = require '../config'

config.resolve (
  Application
  Hunt
) ->
  stream = Application.find({stateId: null, year: "2016"}, {huntId: 1, huntIds: 1, stateId: 1}).stream()

  stream.on 'data', (application) ->
    _this = this
    console.log 'application:', application

    @pause()

    huntIds = if application.huntIds?.length then application.huntIds else [application.huntId]

    huntStream = Hunt.find({_id: {$in: huntIds}}).limit(1).stream()

    huntStream.on 'data', (hunt) ->
      console.log 'hunt:', hunt

      Application.update { _id: application._id }, { $set: { stateId: hunt.stateId }}, ->
        _this.resume()

    huntStream.on 'error', (err) ->
      console.log 'hunt stream err:', err
      return

    huntStream.on 'close', ->
      console.log 'hunt stream closed'

    return

  stream.on 'error', (err) ->
    # handle err
    console.log 'stream err:', err
    return

  stream.on 'close', ->
    # all done
    console.log 'stream closed'
    process.exit()
