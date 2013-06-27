upnode = require 'upnode'
http = require 'http'
deepEqual = require 'deep-equal'
SECRET = ''
connections = {}

getConnection = (drone) ->
  return connections[drone.name] if connections[drone.name]?
  return new Error "Butler error: Unknown drone, no host provided" if !drone.host?
  connections[drone.name] =
    host: drone.host
  connections[drone.name].up = upnode.connect drone.host, 7004, (remote, conn) ->
    remote.auth 'o87asdoa87sa', (err, res) ->
      console.error err if err?
      conn.emit 'up', res
associateHosts = (model) ->
  for droneName, drone of model.swarm
    drone.host = getConnection({name: droneName}).host
  return model

propagateRoutingTable = (model, cb) ->
  jobs = Object.keys(model.swarm).length

  for droneName, drone of model.swarm
    drone.routingTable ?= {}
    if deepEqual drone.routingTable, model.routingTable
      jobs--
      continue
    drone.routingTable = JSON.parse JSON.stringify model.routingTable
    connection = getConnection({name: droneName})
    return cb connection, model if connection instanceof Error
    timer = setTimeout ->
      drone.routingTable = {}
    , 1000 * 10
    connection.up (remote) ->
      remote.updateRouting model.routingTable, (err) ->
        clearTimeout timer
        jobs--
        return cb err, model if err?
        return cb null, model if jobs < 0

module.exports =
  setSecret: (secret) ->
    SECRET = secret
  getPort: (drone, cb) ->
    connection = getConnection({name: drone})
    return cb connection if connection instanceof Error
    connection.up (remote) ->
      remote.port cb
  associateHosts: associateHosts
  propagateRoutingTable: propagateRoutingTable

server = http.createServer (req, res) ->
  params = req.url.split '/'
  if params[1] != 'checkin'
    res.writeHead 404
    return res.end '404'
  authArray = new Buffer(req.headers.authorization.split(' ')[1], 'base64').toString('ascii').split(':')
  if authArray[1] != SECRET
    res.writeHead 403
    res.end '403'
  getConnection({name: params[2], host: req.socket.remoteAddress})
  res.writeHead 200
  res.end '200'
server.listen 7003, '127.0.0.1'
