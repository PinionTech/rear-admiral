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
        drones = JSON.parse JSON.stringify model.swarm
        drones = filterDrones drones, "bootstrapped"
        drones = filterDrones drones, "checkedin"
        if Object.keys(drones).length < 1
          err = "No bootstrapped drones"
        else
          targetDrone = (sortDrones drones)[0]
          model.swarm[targetDrone].load += repo.load
          model.swarm[targetDrone].pending ?= []
          model.swarm[targetDrone].pending.push reponame
  cb err, model

filterDrones = (drones, attr) =>
  for name, drone of drones
    delete drones[name] if !drone[attr]
  return drones

sortDrones = (drones) ->
  ([k, v.load] for k, v of drones).sort (a,b) ->
    a[1] - b[1]
  .map (n) -> n[0]

clearStalePortMaps = (model) ->
  for droneName, drone of model.portMap
    for pid of drone
      if !model.swarm[droneName].procs[pid]?
        delete drone[pid]
        continue
  return model

createRoutingTable = (model) ->
  routes = {}
  for droneName, drone of model.portMap
    for pid, service of drone
      continue if service.commit isnt model.manifest[service.repo].opts.commit
      routes[service.repo] ?= {}

      #read in all the options like routing method
      for k, v of model.manifest[service.repo].routing
        routes[service.repo][k] = v

      routes[service.repo].routes ?= []
      if model.swarm[droneName].procs[pid].status is 'running'
        routes[service.repo].routes.push
          host: model.swarm[droneName].host
          port: service.port
  model.routingTable = routes
  return model

module.exports =
  bootstrapStatus: bootstrapStatus
  bootstrapped: bootstrapped
  buildPending: buildPending
  sortDrones: sortDrones
  createRoutingTable: createRoutingTable
  clearStalePortMaps: clearStalePortMaps
