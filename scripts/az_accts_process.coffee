_ = require 'underscore'
async = require "async"
config = require '../config'
winston     = require 'winston'
moment    = require 'moment'

config.resolve (
  logger
  Secure
  User
	UserState
	AZPortalAccount
  Arizona
	HuntinFoolState
	HuntinFoolClient
) ->

	tenantId = "52c5fa9d1a80b40fd43f2fdd" #huntinfool
	#tenantId = "56f44d39e680961c4b86f6f7" #muleycrazy
	#tenantId = "5734f80007200edf236054e6" #zeroguidefees
	userTotal = 0
	userCount = 0
	typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

	loadAllAZUsers = (cb) ->
		saveUser = (hfState, next) ->
			userCount++
			console.log "****Processing #{userCount} of #{userTotal}, #{hfState.client_id}"
			AZPortalAccount.byClientId hfState.client_id, (err, azAcct) ->
				return next err if err
				console.log "SKIPPING, client already has entry in AZPortalAccount." if azAcct
				return next null, azAcct if azAcct

				HuntinFoolClient.byClientId hfState.client_id, (err, hfClient) ->
					return next err if err
					console.log "Error, HuntinFoolClient not found for clientId: #{hfState.client_id}" unless hfClient
					return next null, azAcct unless hfClient

					User.findById hfClient.userId, (err, user) ->
						return next err if err
						console.log "Error, User not found for userId: #{hfClient.userId}" unless user
						return next null, azAcct unless user

						isNewUser = false
						isNewUser = true if user.tenantId is "52c5fa9d1a80b40fd43f2fdd" or user.tenantId?.toString() is "52c5fa9d1a80b40fd43f2fdd"
						console.log "FOUND NEW USER userId, clientId:", user._id, user.clientId if isNewUser
						return next null, azAcct unless isNewUser

						data = {
							userId: user._id
							clientId: user.clientId
							first_name: user.first_name
							last_name: user.last_name
							tenantId: user.tenantId
							modified: new Date()
						}
						data.azUsername = user.azUsername if user.azUsername
						data.azPassword = user.azPassword if user.azPassword

						AZPortalAccount.upsert data, (err, AZAcct) ->
							return next err if err
							return next "Error, insert to AZPortalAccount failed." unless AZAcct
							console.log "Insert to AZPortalAccount successful.", AZAcct
							return next null, AZAcct


		HuntinFoolState.find({"az_check" : "True"}).lean().exec (err, hfStates) ->
			cb err if err
			cb "No hfStates found." unless hfStates
			userTotal = hfStates.length
			async.mapSeries hfStates, saveUser, (err, results) ->
				cb err if err
				cb null, results

	sendNewAZAcctRequests = (tenantId, cb) ->
		console.log "Starting send new AZ Account Requests"
		return cb "error, tenantId is required" unless tenantId

		createAZAccount = (azAcct, next) ->
			userCount++
			#return next null if userCount > 1
			console.log()
			console.log()
			console.log "****Processing #{userCount} of #{userTotal}, #{azAcct.clientId}, #{azAcct.tenantId}"

			User.byClientId azAcct.clientId, {internal: true}, (err, user) ->
				return cb err if err
				return cb "error, user not found for clientId: #{azAcct.clientId}" unless user
				Arizona.registerPointGuard user, (err, results) ->
					if typeof err?.msg is 'string' and err?.msg?.indexOf("is already taken") > -1
						console.log "AZ Create Account Send: #{user.azUsername} is already registered!"
						azAcct.azAcctReqSent = true
						azAcct.notes = "" unless azAcct.notes
						azAcct.notes += "AZ Create Account Send: #{err.msg}" if err?.msg
						AZPortalAccount.upsert azAcct, {}, (errUpsert, azAcct) ->
							return next errUpsert if errUpsert
							return next null
					else
						return next err if err
						azAcct.azAcctReqSent = true
						azAcct.notes = "" unless azAcct.notes
						azAcct.notes += "AZ Create Account Send: #{results.success}" if results?.success
						AZPortalAccount.upsert azAcct, {}, (err, azAcct) ->
							return next err if err
							console.log "New AZ Acct created for azUsername: #{user.azUsername}", azAcct
							return next null

		async.waterfall [
			(next) ->
				console.log 'Getting users from AZPortalAccount that have not yet had AZ Accounts created'
				singleUserTest = false
				if singleUserTest
					clientId = "MC2"
					AZPortalAccount.byClientId clientId, (err, AZAcct) ->
						azAccts = [AZAcct]
						return next err, azAccts
				else
					AZPortalAccount.needAZAcct tenantId, next

			(azAccts, next) ->
				console.log "found #{azAccts.length} azAccts to create new AZ accts"
				userTotal = azAccts.length
				async.mapSeries azAccts, createAZAccount, (err) ->
					return next err

		], (err, results) ->
			if err
				console.log "An error occured creating new AZ Accounts. Error:", err
				return cb err
			else
				return cb null, results

	checkValidLogins = (tenantId, cb) ->
		console.log "Starting AZ check valid logins"
		return cb "error, tenantId is required" unless tenantId

		azLogin = (azAcct, next) ->
			stateId = "52aaa4cae4e055bf33db6499"
			userCount++
			#return next null if userCount > 1
			console.log()
			console.log()
			console.log "****Processing #{userCount} of #{userTotal}, #{azAcct.clientId}, #{azAcct.tenantId}"

			User.byClientId azAcct.clientId, {internal: true}, (err, user) ->
				return cb err if err
				return cb "error, user not found for clientId: #{azAcct.clientId}" unless user

				UserState.byStateAndUser user._id, stateId, (err, userstate) ->
					return cb err if err
					return cb "error, user CID not found for userID: #{user._id}, stateId: #{stateId}" unless userstate
					user.cid = userstate.cid
					console.log "DEBUG: user.cid", user.cid
					Arizona.checkAndUpdatePortalAccount user, (err, results) ->
						azAcct.notes = ""
						if results?.login?.length
							azAcct.notes += results.login
							azAcct.azAcctLoginValidated = true
							azAcct.updatePortalAccountStatus = results.updatePortalAccountStatus if results.updatePortalAccountStatus
							if results.updatePortalAccountStatus == "Login Successful, No licenses associated with this account."
								azAcct.azAcctNeedsUpdated = true
							else
								azAcct.azAcctNeedsUpdated = false
						else
							azAcct.azAcctLoginValidated = false
							azAcct.azAcctNeedsUpdated = false
							azAcct.updatePortalAccountStatus = "" if azAcct.updatePortalAccountStatus
							azAcct.notes += "AZ Login Failed: #{JSON.stringify(results)}" unless err
							azAcct.notes += "AZ Login Failed: #{JSON.stringify(err)}" if err
							if azAcct.notes.indexOf("Account not activated") > -1
								azAcct.azAcctNeedsReActivated = true
						#return next null
						AZPortalAccount.upsert azAcct, {}, (err, azAcct) ->
							return next err if err
							console.log "AZ Account login test: #{azAcct.notes}", azAcct
							return next null

		async.waterfall [
			(next) ->
				console.log 'Getting users from AZPortalAccount to test AZ Login'
				singleUserTest = true
				if singleUserTest
					clientId = "ZGF_778275148732963458"
					AZPortalAccount.byClientId clientId, (err, AZAcct) ->
						return next err if err
						return next "Error AZAcct doesn't exist for clientId: #{clientId}" unless AZAcct
						azAccts = [AZAcct]
						return next err, azAccts
				else
					skipValidated = false
					AZPortalAccount.validateLogins tenantId, skipValidated, next

			(azAccts, next) ->
				console.log "found #{azAccts.length} azAccts to test login to AZ accts"
				userTotal = azAccts.length
				async.mapSeries azAccts, azLogin, (err) ->
					return next err

		], (err, results) ->
			if err
				console.log "An error occured creating new AZ Accounts. Error:", err
				return cb err
			else
				return cb null, results


	resetForgotPassword = (tenantId, cb) ->
		console.log "Starting AZ reset forgot passwords"
		return cb "error, tenantId is required" unless tenantId

		azResetForgotPassword = (azAcct, next) ->
			userCount++
			#return next null if userCount > 1
			console.log()
			console.log()
			console.log "****Processing #{userCount} of #{userTotal}, #{azAcct.clientId}, #{azAcct.tenantId}"

			User.byClientId azAcct.clientId, {internal: true}, (err, user) ->
				return cb err if err
				return cb "error, user not found for clientId: #{azAcct.clientId}" unless user
				user.azUsername = azAcct.azUsername
				user.azPassword = azAcct.azPassword
				Arizona.forgotPasswordReset user, (err, results) ->
					azAcct.notes = ""
					if results?.login?.length
						azAcct.notes += results.login
						if results?.login.indexOf("Forgot Password Confirmation") > -1
							azAcct.azAcctNeedsReActivated = false
					else
						azAcct.notes += "AZ Forgot Password Failed" unless err
						azAcct.notes += "AZ Forgot Password Failed: #{JSON.stringify(err)}" if err
					#return next null
					AZPortalAccount.upsert azAcct, {}, (err, azAcct) ->
						return next err if err
						console.log "AZ forgot password: #{azAcct.notes}", azAcct
						return next null

		async.waterfall [
			(next) ->
				console.log 'Getting users from AZPortalAccount to run AZ Forgot Password'
				singleUserTest = false
				if singleUserTest
					clientId = "GMT0001"
					AZPortalAccount.byClientId clientId, (err, AZAcct) ->
						return next err if err
						return next "Error AZAcct doesn't exist for clientId: #{clientId}" unless AZAcct
						azAccts = [AZAcct]
						return next err, azAccts
				else
					AZPortalAccount.resetPasswords tenantId, next

			(azAccts, next) ->
				console.log "found #{azAccts.length} azAccts to reset forgot passwords"
				userTotal = azAccts.length
				async.mapSeries azAccts, azResetForgotPassword, (err) ->
					return next err

		], (err, results) ->
			if err
				console.log "An error occured creating new AZ Accounts. Error:", err
				return cb err
			else
				return cb null, results


	updateAZAcctProfiles = (tenantId, cb) ->
		console.log "Starting update AZ Account Profiles"
		return cb "error, tenantId is required" unless tenantId
		return cb()

	doNothing = (tenantId, cb) ->
		console.error "Please determine which method should be run."
		return cb "error, tenantId is required" unless tenantId
		return cb()






	#loadAllAZUsers (err, results) ->
	#sendNewAZAcctRequests tenantId, (err, results) ->
	#checkValidLogins tenantId, (err, results) ->
	#resetForgotPassword tenantId, (err, results) ->
	doNothing tenantId, (err, results) ->
		console.log "Finished"
		if err
			logger.error "Found an error", err
			process.exit(1)
		else
			console.log "Done"
			process.exit(0)
