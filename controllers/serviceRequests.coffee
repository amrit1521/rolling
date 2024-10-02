_ = require "underscore"
async = require "async"
crypto = require "crypto"
moment = require "moment"
amqp        = require "amqp"


module.exports = (ServiceRequest, User) ->

  ServiceRequests = {

    adminIndex: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      ServiceRequest.byTenant req.tenant._id, (err, serviceRequests) ->
        return res.json err, 500 if err

        addUser = (serviceRequest, done) ->
          if serviceRequest.first_name or serviceRequest.last_name
            serviceRequest.user_name = "#{serviceRequest.first_name} #{serviceRequest.last_name}".trim()
            return done null, serviceRequest
          else
            return done null, serviceRequest

        async.mapSeries serviceRequests, addUser, (err, serviceRequests) ->
          return res.json err, 500 if err
          res.json serviceRequests


    adminRead: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      ServiceRequest.byId req.param('id'), req.tenant._id, (err, serviceRequest) ->
        return res.json err, 500 if err
        res.json serviceRequest


    update: (req, res) ->
      return res.json {error: 'Tenant id required'}, 400 unless req?.tenant?._id
      return res.json {error: 'Service Request type required'}, 400 unless req?.body?.type

      #Special case, assign tenantId if the user was a super admin (isAdmin=true, and no tenantId)
      if !(req?.body?.tenantId) and req?.user?.isAdmin and !req?.user?.tenantId
        req.body.tenantId = req.tenant._id
      return res.json {error: 'Tenant id required'}, 400 unless req?.body?.tenantId

      ServiceRequest.upsert req.body, (err, serviceRequest) ->
        return res.json err, 500 if err
        res.json serviceRequest

  }

  _.bindAll.apply _, [ServiceRequests].concat(_.functions(ServiceRequests))
  return ServiceRequests
