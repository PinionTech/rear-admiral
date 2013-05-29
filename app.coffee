propagit = require 'propagit'
fleet = require './lib/fleet'
fs = require 'fs'

OPTS =
  hub: '127.0.0.1:7000'
  secret: 'lolwat'

p = propagit(OPTS)
p.on 'error', (err) ->
  healthy = false
  console.error err
healthy = false
getManifest = (cb) ->
  fs.readFile './manifest.json', (err, data) ->
    return cb err if err?
    cb null, JSON.parse data.toString()

startChecking = (hub) ->
  setInterval ->
    getManifest (err, manifest) ->
      fleet.listDrones hub, manifest, (err, drones) ->
        fleet.checkFleet drones, manifest, (err, manifest) ->
          fleet.repairFleet drones, manifest, hub, (err, procList) ->
            console.log err if err?
            console.log "Spawned processes for #{reponame}", procs for reponame, procs of procList
            healthy = false if err?
  , 3000

p.hub.on 'up', (hub) ->
  console.log 'connection up'
  healthy = true
  startChecking hub

exit = () ->
  p.hub.close()
