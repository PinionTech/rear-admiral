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
    for reponame, repo of manifest
      do (reponame, repo) ->
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
