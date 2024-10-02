bouncy = require "bouncy"
cache = require 'memory-cache'
crypto = require 'crypto'
fs = require "fs"
http = require "http"
config = require "./config"
Tenant = config.get 'Tenant'
logger = config.get 'logger'

loadTenants = (cb) ->
  Tenant.index (err, tenants) ->
    for tenant in tenants
      cache.put 'tenant-' + tenant.domain, tenant
    cb() if cb

setInterval loadTenants, 1000 * 60 * 30 # Refresh every 30 minutes

# load the tenants the first time
loadTenants ->

  server = http.createServer((req, res, next) ->
    res.writeHead(301, {Location: "https://#{req.headers.host}"});
    res.end();
  )
  server.listen 80

  sni_select = (hostname) ->
    domain = hostname # .split(':')[0]
    tenant = cache.get 'tenant-' + domain
    # winston.info "tenant 2:", tenant

    if not tenant
      logger.info "Tenant not found"
      return

    creds =
      key: tenant.ssl_key
      cert: tenant.ssl_crt

    creds.ca = tenant.ssl_issuer if tenant.ssl_issuer
    crypto.createCredentials(creds).context

  tenant = cache.get 'tenant-www.gotmytag.com'
  # logger.info "tenant 1:", tenant
  ssl =
    cert: tenant.ssl_pem
    key: tenant.ssl_key
    SNICallback: sni_select

  bouncy(ssl, (req, bounce) ->
    if req.headers.host is "test.gotmytag.com"
      logger.info "Forward #{req.headers.host}#{req.url} to port 5001"
      bounce 5001
    else if req.headers.host in ["dmv360.us", "www.dmv360.us"]
      logger.info "Forward #{req.headers.host}#{req.url} to port 8080"
      bounce 8080
    else
      logger.info "Forward #{req.headers.host}#{req.url} to port 5000"
      bounce 5000
  ).listen 443
