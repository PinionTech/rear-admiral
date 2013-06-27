upnode = require 'upnode'
http = require 'http'
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
    drone.host = getConnection(droneName).host
  return model

createRoutingTable = (model) ->
  routes = {}
  for droneName, drone of model.swarm
    for pid, service of drone.portMap
      routes[service.repo] ?= {}
      routes[service.repo].domain = model.manifest[service.repo].domain
      routes[service.repo].routes ?= []
      routes[service.repo].routes.push {
        host: drone.host
        port: service.port
      }
  model.routingTable = routes
  return model

module.exports =
  setSecret: (secret) ->
    SECRET = secret
  getPort: (drone, cb) ->
    up = getConnection({name: drone}).up
    return cb up if up instanceof Error
    up (remote) ->
      remote.port cb
  associateAndRoute: (model, cb) ->
    model = associateHosts(model)
    model = createRoutingTable(model)
    cb null, model
  associateHosts: associateHosts
  createRoutingTable: createRoutingTable

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
