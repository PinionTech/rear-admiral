assert = require 'assert'
fs = require 'fs'
rimraf = require 'rimraf'
propagit = require 'propagit'
spawn = require('child_process').spawn
fleet = require '../lib/fleet'

describe 'integration', ->
  this.timeout 10000
  fleetHub = null
  drone1 = null
  drone2 = null
  deployed = false
  before () ->
    fs.mkdirSync "#{__dirname}/#{dir}" for dir in ["tmp", "tmp/drone1", "tmp/drone2", "tmp/hub"]

    fleetHub = spawn "#{__dirname}/../node_modules/fleet/bin/hub.js", ["--port=7010", "--secret=rearadtest"], {cwd: "#{__dirname}/tmp/hub"}
    drone1 = spawn "#{__dirname}/../node_modules/fleet/bin/drone.js", ["--name=drone1", "--hub=127.0.0.1:7010", "--secret=rearadtest"], {cwd: "#{__dirname}/tmp/drone1"}
    drone2 = spawn "#{__dirname}/../node_modules/fleet/bin/drone.js", ["--name=drone2", "--hub=127.0.0.1:7010", "--secret=rearadtest"], {cwd: "#{__dirname}/tmp/drone2"}
    deploy = spawn "#{__dirname}/../node_modules/fleet/bin/deploy.js", ['deploy', '--hub=127.0.0.1:7010', '--secret=rearadtest'], {cwd: "#{__dirname}/../testrepos/test1"}

    deploy.stdout.on 'data', (data) ->
      deployed = true if data.toString().split(' ')[0] is 'deployed'
  after (done) ->
    killed = 0
    rimraf "#{__dirname}/tmp", () ->
      killed++
      done() if killed is 4
    drone1.kill()
    drone2.kill()
    fleetHub.kill()
    fleetHub.on 'exit', () ->
      killed++
      done() if killed is 4
    drone1.on 'exit', () ->
      killed++
      done() if killed is 4
    drone2.on 'exit', () ->
      killed++
      done() if killed is 4
  it 'Should spawn pending jobs', (done) ->
    checker = setInterval ->
      if deployed
        success = 0
        tripped = {}
        clearInterval checker
        p = propagit {hub: '127.0.0.1:7010', secret: 'rearadtest'}
        drone1.stdout.on 'data', (data) ->
          if data.toString().split(' ').slice(1, 4).join(' ') is "Server running at" and !tripped.drone1?
            success++
            tripped.drone1 = true
        drone2.stdout.on 'data', (data) ->
          if data.toString().split(' ').slice(1, 4).join(' ') is "Server running at" and !tripped.drone2?
            success++
            tripped.drone2 = true
        p.hub.on 'up', (hub) ->
          model =
            hub: hub
            manifest:
              "test1":
                load: 1
                instances: '*'
                running: 0
                opts:
                  env: {PORT: 3000}
                  command: ["node", "server.js"]
                  commit: '8b7243393950e0209c7a9346e9a1a839b99619d9'
            swarm:
              drone1:
                load: 0
                pending: ['test1']
                procs: {}
              drone2:
                load: 0
                pending: ['test1']
                procs: {}
          fleet.repairFleet model, (err, model, procList) ->
            assert.equal err, null
            assert procs.length > 0 for reponame, procs of procList
            stopped = 0
            successCheck = setInterval ->
              for reponame, procs of procList
                for instance in procs
                  for drone, id of instance
                    hub.stop {drone: drone, pid: id}, (err, drones) ->
                      stopped++
              clearInterval successCheck if success is 2 and stopped is 2
              done() if success is 2 and stopped is 2
            , 500
    , 500
