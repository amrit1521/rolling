_ = require "underscore"

module.exports = (Tenant, logger) ->

  class MultiTenant

    tenant: (req, res, next) ->
      console.log "Testing"
      return unless req.headers?.host?.length
      domain = req.headers.host.split(':')[0]


      # console.log "tenadntid",tenantId

      # set req.tenant to the tenant info
      if req.user?.tenantId
        Tenant.findById req.user.tenantId, (err, tenant) ->
          return next(err) if err

          if not tenant
            logger.info "Page not found"
            return next('Page not found,')

          req.tenant = tenant
          tenant = null
          next()
      else
        domain = 'test.gotmytag.com' if domain is 'localhost'
        Tenant.findByDomain domain, (err, tenant) ->
          logger.info "Page not found"
          logger.info tenant
          return next(err) if err

          if not tenant
            logger.info "Page not found"
            return next('Page not found')

          req.tenant = tenant
          tenant = null
          next()

  new MultiTenant()
