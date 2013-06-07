EventEmitter = require('events').EventEmitter
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

someDrones = (drones, manifest, hub, reponame, repo, jobs, procList, errors, cb) ->
  delta = repo.running - repo.instances
  if delta < 0
    jobs += delta
    while delta < 0
      delta++
      opts = JSON.parse JSON.stringify repo.opts
      targetDrone = (sortDrones drones)[0]
      opts.drone = targetDrone
      opts.repo = reponame
      drones[targetDrone].load += repo.load
      hub.spawn opts, (err, procs) ->
        if err?
          errors = [] if !errors?
          errors.push err
          console.error err
        procList[reponame] = [] if !procList[reponame]?
        procList[reponame].push procs
        jobs++
        cb errors, procList if jobs is 0

allDrones = (drones, manifest, hub, reponame, repo, jobs, procList, errors, cb) ->
  jobs -= Object.keys(drones).length
  for name, drone of drones
    isPresent = false
    for pid, proc of drone.procs
      isPresent = true if proc.repo == reponame and repo.opts.commit == proc.commit
    if isPresent
      jobs++
      cb errors, procList if jobs is 0
    else
      opts = JSON.parse JSON.stringify repo.opts
      opts.drone = name
      opts.repo = reponame
      opts.env.PORT = opts.env.PORT + Math.floor(Math.random()*101)
      drones[name].load += repo.load
      hub.spawn opts, (err, procs) ->
        if err?
          errors = [] if !errors?
          errors.push err
          console.error err
        procList[reponame] = [] if !procList[reponame]?
        procList[reponame].push procs
        jobs++
        cb errors, procList if jobs is 0

module.exports =
  checkFleet: (drones, manifest, cb) ->
    repo.running = 0 for reponame, repo of manifest
    for reponame, repo of manifest
      for dronename, drone of drones
        for procname, proc of drone.procs
          repo.running += 1 if proc.repo == reponame and proc.status == "running"
    cb null, manifest

  repairFleet: (drones, manifest, hub, cb) ->
    jobs = 0
    errors = null
    procList = {}
    errors = null
    for reponame, repo of manifest
      do (reponame, repo) ->
        if repo.instances == '*'
          allDrones drones, manifest, hub, reponame, repo, jobs, procList, errors, (errors, procList) ->
            cb errors, procList
        else
          someDrones drones, manifest, hub, reponame, repo, jobs, procList, errors, (errors, procList) ->
            cb errors, procList

  listDrones: (hub, manifest, cb) ->
    drones = {}
    em =  new EventEmitter

    em.on 'data', (name, procs) ->
      drone =
        name: name
        procs: procs
      drone = calcLoad drone, manifest
      drones[drone.name] =
        procs: drone.procs
        load: drone.load

    em.on 'end', ->
      cb null, drones

    hub.ps em.emit.bind em
  calcLoad: calcLoad
  sortDrones: sortDrones
