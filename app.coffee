propagit = require 'propagit'
levelup = require 'levelup'
fleet = require './lib/fleet'
surveyor = require './lib/surveyor'
butler = require './lib/butler'
fs = require 'fs'

console.log "Rear Admiral initialised"

OPTS = JSON.parse fs.readFileSync 'opts.json'.toString()

butler.setSecret
  butlerSecret: OPTS.butler.butlerSecret
  porterSecret: OPTS.butler.porterSecret

p = propagit(OPTS.propagit)
p.on 'error', (err) ->
  healthy = false
  console.error err
healthy = false
getManifest = (cb) ->
  fs.readFile './manifest.json', (err, data) ->
    return cb err if err?
    cb null, JSON.parse data.toString()

db = levelup './model.leveldb'
model = null
lock = false
alreadyChecking = false
db.get 'model', (err, data) ->
  return model = {} if !data?
  model = JSON.parse data

bail = (msg, err) ->
  if err?
    console.error msg, err
  else if msg?
    console.log msg
  lock = false
  db.put 'model', JSON.stringify model

startChecking = (hub) ->
  alreadyChecking = true
  setInterval ->
    return if !model?
    return if lock
    lock = true
    model.hub = hub
    getManifest (err, manifest) ->
      model.manifest = manifest
      fleet.listDrones model, (err, model) ->
        return bail "Error listing drones", err if err?
        return bail "No drones available", null if Object.keys(model.swarm).length < 1
        surveyor.bootstrapStatus model, (err, model) ->
          butler.checkedInStatus model, (err, model) ->
            fleet.checkFleet model, (err, model) ->
              surveyor.buildPending model, (err, model) ->
                fleet.repairFleet model, (err, model, procList) ->
                  console.error err if err?
                  console.log "Spawned processes for #{reponame}", procs for reponame, procs of procList
                  healthy = false if err?
                  butler.associateHosts model, (err, model) ->
                    model = surveyor.clearStalePortMaps model
                    model = surveyor.createRoutingTable model
                    butler.propagateRoutingTable model, (err, model, dronesWritten) ->
                      console.error "Error propagating routing table", err if err?
                      return bail "Error propagating routing table", err if err?
                      return bail "Wrote routing table to #{dronesWritten}" if dronesWritten.length > 0
                      return bail null, null
  , 3000

p.hub.on 'up', (hub) ->
  console.log 'connection up'
  healthy = true
  startChecking hub unless alreadyChecking

exit = () ->
  p.hub.close()
