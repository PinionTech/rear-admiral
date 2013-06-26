EventEmitter = require('events').EventEmitter
butler = require './butler'
butler.setSecret 'asd123'
calcLoad = (drone, manifest) ->
  load = 0
  for proc, data of drone.procs
    load += manifest[data.repo].load
  drone.load = load
  return drone

sortDrones = (drones) ->
  ([k, v.load] for k, v of drones).sort (a,b) ->
    a[1] - b[1]
  .map (n) -> n[0]

filterBootstrapped = (drones) =>
  for name, drone of drones
    delete drones[name] if !drone.bootstrapped
  return drones

buildOpts = (input, targetDrone, reponame, setup, cb) ->
  jobs = 0
  errs = []
  checkDone = ->
    if jobs is 0
      errs = null if errs.length is 0
      cb errs, opts
  opts = JSON.parse JSON.stringify input
  opts.drone = targetDrone
  opts.repo = reponame
  if setup
    opts.command = opts.setup
    opts.once = true
  for variable, value of opts.env
    switch value
      when "DRONE_NAME"
        opts.env[variable] = targetDrone
      when "RANDOM_PORT"
        jobs++
        butler.getPort targetDrone, (err, port) ->
          errs.push err if err?
          jobs--
          opts.env[variable] = port
          checkDone()
  checkDone()

buildPending = (model, cb) ->
  err = null
  for reponame, repo of model.manifest
    if repo.instances == '*'
      #allDrones
      for name, drone of model.swarm
        running = false
        for pid, proc of drone.procs
          running = true if proc.repo is reponame and repo.opts.commit is proc.commit
        continue if running
        drone.pending ?= []
        if !drone.bootstrapped
          continue if !repo.opts.bootstrap
        drone.load += repo.load
        drone.pending.push reponame
    else
      #someDrones
      delta = repo.running - repo.instances
      while delta < 0
        delta++
        bootstrappedDrones = filterBootstrapped JSON.parse JSON.stringify model.swarm
        if Object.keys(bootstrappedDrones).length < 1
          err = "No bootstrapped drones"
        else
          targetDrone = (sortDrones bootstrappedDrones)[0]
          model.swarm[targetDrone].load += repo.load
          model.swarm[targetDrone].pending ?= []
          model.swarm[targetDrone].pending.push reponame
  cb err, model

repairFleet = (model, cb) ->
  em = new EventEmitter
  jobs = 0
  procList = {}
  errors = null

  em.on 'setupTask', (repo, drone) ->
    if model.manifest[repo].opts.setup?
      buildOpts model.manifest[repo].opts, drone, repo, true, (err, opts) ->
        throw new Error err if err?
        model.hub.spawn opts, (err, procs) ->
          em.emit 'error', err if err?
          em.emit 'spawn', repo, drone
    else
      em.emit 'spawn', repo, drone

  em.on 'spawn', (repo, drone) ->
    buildOpts model.manifest[repo].opts, drone, repo, false, (err, opts) ->
      throw new Error err if err?
      model.hub.spawn opts, (err, procs) ->
        em.emit 'error', err if err?
        procList[repo] ?= []
        procList[repo].push procs
        jobs--
        cb errors, model, procList if jobs is 0

  em.on 'error', (err) ->
    errors ?= []
    errors.push err
    console.error err

  for name, drone of model.swarm
    continue if !drone.pending?
    for repo in drone.pending
      jobs++
      em.emit 'setupTask', repo, name

listDrones = (model, cb) ->
  model.swarm = {}
  drones = model.swarm
  em =  new EventEmitter

  em.on 'data', (name, procs) ->
    drone =
      name: name
      procs: procs
    drone = calcLoad drone, model.manifest
    drones[drone.name] =
      procs: drone.procs
      load: drone.load

  em.on 'end', ->
    cb null, model

  model.hub.ps em.emit.bind em

bootstrapStatus = (model, cb) ->
  for drone, droneData of model.swarm
    if !bootstrapped droneData, model.manifest
      model.swarm[drone].bootstrapped = false
    else model.swarm[drone].bootstrapped = true
  cb null, model

bootstrapped = (drone, manifest) ->
  required = 0
  for job, jobData of manifest when jobData.opts.bootstrap is true
    required++
    for pid, data of drone.procs
      required-- if data.repo is job
  return true if required is 0
  return false

module.exports =
  checkFleet: (model, cb) ->
    repo.running = 0 for reponame, repo of model.manifest
    for reponame, repo of model.manifest
      for dronename, drone of model.swarm
        for procname, proc of drone.procs
          repo.running += 1 if proc.repo == reponame and proc.status == "running"
    cb null, model

  repairFleet: repairFleet
  listDrones: listDrones
  calcLoad: calcLoad
  sortDrones: sortDrones
  bootstrapStatus: bootstrapStatus
  bootstrapped: bootstrapped
  buildPending: buildPending
