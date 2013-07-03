EventEmitter = require('events').EventEmitter
butler = require './butler'

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

repairFleet = (model, cb) ->
  em = new EventEmitter
  jobs = 0
  uncheckedDrones = Object.keys(model.swarm).length
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

        model.portMap ?= {}
        model.portMap[drone] ?= {}
        if opts.env.PORT?
          pid = procs[drone]
          model.portMap[drone][pid] =
            repo: repo
            port: opts.env.PORT
            commit: opts.commit

        model.swarm[drone].procs[pid] =
          status: 'pending'
          repo: repo

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
    uncheckedDrones--
    cb errors, model, procList if !drone.pending? and uncheckedDrones is 0 and jobs is 0
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

calcLoad = (drone, manifest) ->
  load = 0
  for proc, data of drone.procs
    load += manifest[data.repo].load
  drone.load = load
  return drone

module.exports =
  checkFleet: (model, cb) ->
    repo.running = 0 for reponame, repo of model.manifest
    for reponame, repo of model.manifest
      for dronename, drone of model.swarm
        for procname, proc of drone.procs
          repo.running += 1 if proc.repo is reponame and proc.status is "running" and proc.commit is repo.opts.commit
    cb null, model

  repairFleet: repairFleet
  listDrones: listDrones
