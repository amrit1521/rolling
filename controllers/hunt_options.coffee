_ = require "underscore"

module.exports = (
  HuntOption
  logger
) ->
  HuntOptions = {
    # app.get "/hunt_options/:huntId", auth.authenticate, hunt_options.get
    get: (req, res) ->
      logger.info "HuntOption::get huntId", req.param('huntId')
      HuntOption.byHuntId req.param('huntId'), (err, options) ->
        return res.json {error: err}, 500 if err
        res.json options
  }

  _.bindAll.apply _, [HuntOptions].concat(_.functions(HuntOptions))
  return HuntOptions
