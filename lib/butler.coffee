upnode = require 'upnode'
http = require 'http'
SECRET = ''
connections = {}

getConnection = (drone) ->
  return connections[drone.name] if connections[drone.name]?
  return new Error "Unknown drone, no host provided" if !drone.host?
  return connections[drone.name] = upnode.connect drone.host, 7004, (remote, conn) ->
    remote.auth 'o87asdoa87sa', (err, res) ->
      console.error err if err?
      conn.emit 'up', res

module.exports =
  setSecret: (secret) ->
    SECRET = secret
  getPort: (drone, cb) ->
    up = getConnection({name: drone})
    cb up if up instanceof Error
    up (remote) ->
      remote.port cb

server = http.createServer (req, res) ->
  params = req.url.split '/'
  if params[1] != 'checkin'
    res.writeHead 404
    return res.end '404'
  authArray = new Buffer(req.headers.authorization.split(' ')[1], 'base64').toString('ascii').split(':')
  if authArray[1] != SECRET
    res.writeHead 403
    res.end '403'
  getConnection({name: params[1], host: req.socket.remoteAddress})
  res.writeHead 200
  res.end '200'
server.listen 7003, '127.0.0.1'
