upnode = require 'upnode'
http = require 'http'
deepEqual = require 'deep-equal'
levelup = require 'levelup'
SECRET =
  butlerSecret: ''
  porterSecret: ''
hostCache = levelup './hostCache.leveldb'
connections = {}
currentRoutingTable = {}

getConnection = (drone, cb) ->
  return cb null, connections[drone] if connections[drone]?
  return cb new Error "Butler error: Unknown drone"

setConnection = (drone) ->
  hostCache.put drone.name, drone.host if drone.host?
  return new Error "Butler error: No host provided" if !drone.host?
  connections[drone.name] =
    host: drone.host
  connections[drone.name].up = upnode.connect drone.host, 7004, (remote, conn) ->
    remote.auth SECRET.porterSecret, (err, res) ->
      console.error err if err?
      conn.emit 'up', res
  null

associateHosts = (model, cb) ->
  jobs = 0
  for droneName, drone of model.swarm
    jobs++
    do (droneName, drone) ->
      hostCache.get droneName, (err, host) ->
        jobs--
        drone.host = host
        cb null, model if jobs is 0

propagateRoutingTable = (model, cb) ->
  currentRoutingTable = JSON.parse JSON.stringify model.routingTable
  jobs = Object.keys(model.swarm).length

  for droneName, drone of model.swarm
    drone.routingTable ?= {}
    dronesWritten = []
    model.butlerCache ?= {}
    model.butlerCache[droneName] ?= {}
    if deepEqual model.butlerCache[droneName].routingTable, model.routingTable
      jobs--
      return cb null, model, dronesWritten if jobs is 0
      continue
    model.butlerCache[droneName].routingTable = JSON.parse JSON.stringify model.routingTable
    getConnection droneName, (err, connection) ->
      return cb connection, model, dronesWritten if connection instanceof Error
      return cb (new Error "routingTable is blank"), model, dronesWritten if deepEqual model.routingTable, {}
      do (droneName) ->
        timer = setTimeout ->
          drone.routingTable = {}
        , 1000 * 10
        connection.up (remote) ->
          remote.updateRouting model.routingTable, (err) ->
            model.butlerCache[droneName].routingTable = {} if err?
            clearTimeout timer
            dronesWritten.push droneName
            jobs--
            cb err, model, dronesWritten if jobs is 0

module.exports =
  setSecret: (secret) ->
    SECRET = secret
  getPort: (drone, cb) ->
    getConnection drone, (err, connection) ->
      return cb err if err?
      connection.up (remote) ->
        remote.port cb
  associateHosts: associateHosts
  propagateRoutingTable: propagateRoutingTable

server = http.createServer (req, res) ->
  params = req.url.split '/'
  authArray = new Buffer(req.headers.authorization.split(' ')[1], 'base64').toString('ascii').split(':')
  if authArray[1] isnt SECRET.butlerSecret
    res.writeHead 403
    res.end '403'
  if params[1] is 'checkin'
    setConnection({name: params[2], host: req.socket.remoteAddress})
    res.writeHead 200
    res.end '200'
  else if params[1] is 'routingTable'
    res.end currentRoutingTable
  else
    res.writeHead 404
    return res.end '404'
server.listen 7003, '0.0.0.0'
