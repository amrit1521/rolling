_ = require "underscore"
async = require "async"
crypto = require "crypto"
moment = require "moment"

module.exports = (User) ->

	Custom = {
		#RollingBones custom code to authenticate passwords recieved from their memberdb
		RB_checkPassword: (login, password, tenantId, cb) ->
			User.findByEmailOrUsername login, login, tenantId, {internal: false}, (err, users) =>
				logger.info "RB_checkPassword error:", err if err
				return cb err if err
				return cb null, false, null unless users?.length

				exec = require('child_process').exec
				checkPassword = (user, cb2) ->
					cmd = "php ./lib/custom/rollingbones/password_test.php '#{password}' '#{user.password}'"
					exec cmd, (error, stdout, stderr) ->
						return cb2 error if error
						return cb2 stderr if stderr
						return cb2 null, {user: user, auth: stdout}

				async.mapSeries users, checkPassword, (err, results) ->
					return cb err if err

					for i,check of results
						return cb null, true, check.user if check.auth is "YES"
					return cb null, false, null
	}

	_.bindAll.apply _, [Custom].concat(_.functions(Custom))
	return Custom
