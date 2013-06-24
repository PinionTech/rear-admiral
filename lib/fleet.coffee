EventEmitter = require('events').EventEmitter
butler = require './butler'
butler.setSecret 'asd123'
calcLoad = (drone, manifest) ->
  load = 0
  for proc, data of drone.procs
    load += manifest[data.repo].load
  drone.load = load
  return drone

bootstrapped = (drone, manifest) ->
  required = 0
  for job, jobData of manifest when jobData.opts.bootstrap is true
    required++
    for proc, data of drone.procs
      required-- if data.repo is job
  return true if required is 0
  return false

sortDrones = (drones) ->
  ([k, v.load] for k, v of drones).sort (a,b) ->
    a[1] - b[1]
  .map (n) -> n[0]

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

repairFleet = (drones, manifest, hub, cb) ->
  em = new EventEmitter
  jobs = 0
  procList = {}
  errors = null
  em.on 'allDrones', (reponame, repo) ->
    jobs -= Object.keys(drones).length
    droneList = []
    for name, drone of drones
      isPresent = false
      for pid, proc of drone.procs
        isPresent = true if proc.repo == reponame and repo.opts.commit == proc.commit
      if isPresent
        jobs++
        cb errors, procList if jobs is 0
      else
        drones[name].load += repo.load
        droneList.push name
    em.emit 'droneList', reponame, repo, droneList

  em.on 'someDrones', (reponame, repo) ->
    delta = repo.running - repo.instances
    droneList = []
    if delta < 0
      jobs += delta
      while delta < 0
        delta++
        targetDrone = (sortDrones drones)[0]
        drones[targetDrone].load += repo.load
        droneList.push targetDrone
      em.emit 'droneList', reponame, repo, droneList

  em.on 'droneList', (reponame, repo, droneList) ->
    for drone in droneList
      em.emit 'setupTask', reponame, repo, drone if repo.opts.setup?
      em.emit 'spawn', reponame, repo, drone if !repo.opts.setup?

  em.on 'setupTask', (reponame, repo, drone) ->
    buildOpts repo.opts, drone, reponame, true, (err, opts) ->
      return console.error err if err?
      hub.spawn opts, (err, procs) ->
        em.emit 'error', err if err?
        em.emit 'spawn', reponame, repo, drone

  em.on 'spawn', (reponame, repo, drone) ->
    buildOpts repo.opts, drone, reponame, false, (err, opts) ->
      return console.error err if err?
      hub.spawn opts, (err, procs) ->
        em.emit 'error', err if err?
        procList[reponame] ?= []
        procList[reponame].push procs
        jobs++
        cb errors, procList if jobs is 0

  em.on 'error', (err) ->
    errors ?= []
    errors.push err
    console.error err

  for reponame, repo of manifest
    if repo.instances == '*'
      em.emit 'allDrones', reponame, repo
    else
      em.emit 'someDrones', reponame, repo

module.exports =
  checkFleet: (drones, manifest, cb) ->
    repo.running = 0 for reponame, repo of manifest
    for reponame, repo of manifest
      for dronename, drone of drones
        for procname, proc of drone.procs
          repo.running += 1 if proc.repo == reponame and proc.status == "running"
    cb null, manifest

  repairFleet: repairFleet

  listDrones: (hub, manifest, cb) ->
    drones = {}
    em =  new EventEmitter

    em.on 'data', (name, procs) ->
      drone =
        name: name
        procs: procs
      if !bootstrapped drone, manifest
        shortCircuit =
          drones: {}
          manifest:
            JSON.parse JSON.stringify manifest
        shortCircuit.drones[drone.name] =
          procs: drone.procs
          load: 0
        delete shortCircuit.manifest[repo] for repo in shortCircuit.manifest when repo.bootstrap is false
        return repairFleet shortCircuit.drones, shortCircuit.manifest, hub, (err, procList) ->
      drone = calcLoad drone, manifest
      drones[drone.name] =
        procs: drone.procs
        load: drone.load

    em.on 'end', ->
      cb null, drones

    hub.ps em.emit.bind em
  calcLoad: calcLoad
  sortDrones: sortDrones
