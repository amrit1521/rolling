clusterMaster = require "cluster-master"
slaves = if process.argv[2] then process.argv[2] else 1
clusterMaster({
  exec: "app.coffee"
  size: slaves
})
console.log "Start up #{slaves} processes"
