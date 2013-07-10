propagit = require 'propagit'
levelup = require 'levelup'
fleet = require './lib/fleet'
surveyor = require './lib/surveyor'
butler = require './lib/butler'
fs = require 'fs'
async = require 'async'

console.log "Rear Admiral initialised"

OPTS = JSON.parse fs.readFileSync 'opts.json'.toString()

butler.setSecret
  butlerSecret: OPTS.butler.butlerSecret
  porterSecret: OPTS.butler.porterSecret

p = propagit(OPTS.propagit)
p.on 'error', (err) ->
  healthy = false
  console.error err

model = null
hub = null
lock = false
alreadyChecking = false

db = levelup './model.leveldb'
db.get 'model', (err, data) ->
  return model = {} if !data?
  model = JSON.parse data

getManifest = (cb) ->
  fs.readFile './manifest.json', (err, data) ->
    return cb err if err?
    cb null, JSON.parse data.toString()

runSeries = ->
  async.series [
    (cb) ->
      return cb "Model is undefined" if !model?
      return cb "Lock was #{lock}" if lock
      lock = true
      model.hub = hub
      return cb null
    (cb) ->
      getManifest (err, manifest) ->
        model.manifest = manifest
        cb err
    (cb) ->
      fleet.listDrones model, (err, newModel) ->
        model = newModel
        cb err
    (cb) ->
      surveyor.bootstrapStatus model, (err, newModel) ->
        model = newModel
        cb err
    (cb) ->
      butler.checkedInStatus model, (err, newModel) ->
        model = newModel
        cb err
    (cb) ->
      fleet.checkFleet model, (err, newModel) ->
        model = newModel
        cb err
    (cb) ->
      surveyor.buildPending model, (err, newModel) ->
        console.error err if err?
        model = newModel
        cb null
    (cb) ->
      fleet.repairFleet model, (err, newModel, procList) ->
        model = newModel
        console.log "Spawned processes for #{reponame}", procs for reponame, procs of procList
        cb err
    (cb) ->
      butler.associateHosts model, (err, newModel) ->
        model = newModel
        cb err
    (cb) ->
      model = surveyor.clearStalePortMaps model
      model = surveyor.createRoutingTable model
      cb null
    (cb) ->
      butler.propagateRoutingTable model, (err, newModel, dronesWritten) ->
        console.log "Wrote routing table to #{dronesWritten}" if dronesWritten.length > 0
        cb err
  ], (err, results) ->
    console.error err if err?
    lock = false
    db.put 'model', JSON.stringify model

startChecking = (hub) ->
  setInterval ->
    runSeries()
  , 3000

p.hub.on 'up', (returnedHub) ->
  console.log 'connection up'
  hub = returnedHub
  startChecking() unless alreadyChecking
  alreadyChecking = true
