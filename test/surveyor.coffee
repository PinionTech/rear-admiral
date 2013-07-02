assert = require 'assert'
surveyor = require '../lib/surveyor'

describe 'bootstrapping', ->
  model =
    manifest:
      bootstrapTask:
        instances: "*"
        load: 1
        opts:
          bootstrap: true
    swarm:
      drone1:
        load: 0
        procs: {}
      drone2:
        load: 0
        procs:{}
  it "Should mark a drone with no procs as unbootstrapped", ->
    assert.equal false, surveyor.bootstrapped model.swarm.drone1, model.manifest
  it "Shouldn't return any drones if none are bootstrapped", (done) ->
    surveyor.bootstrapStatus model, (err, model) ->
      assert.equal false, drone.bootstrapped for _, drone of model.swarm
      done()
  it "Should return only bootstrapped drones", (done) ->
    model = JSON.parse JSON.stringify model
    model.swarm.strapped =
      load: 1
      procs:
        somePID:
          repo: "bootstrapTask"
    surveyor.bootstrapStatus model, (err, drones) ->
      for name, drone of model.swarm
        assert drone.bootstrapped if name is "strapped"
        assert.equal false, drone.bootstrapped if name isnt "strapped"
      done()
describe 'buildPending', ->
  model =
    manifest:
      someTask:
        instances: '2'
        load: 1
        running: 0
    swarm:
      drone1:
        load: 0
        procs: {}
        bootstrapped: true
      drone2:
        load: 0
        procs: {}
        bootstrapped: true
  it "Should spread evenly across available drones", (done) ->
    surveyor.buildPending model, (err, model) ->
      assert (Object.keys(model.swarm).length > 0), "Swarm empty"
      for _, drone of model.swarm
        assert drone.load is 1, "Load is not 1"
        assert drone.pending.length is 1, "Pending length is not 1"
      done()

describe 'sortDrones', ->
  drones =
    high:
      load: 9.154
    filler1:
      load: 2.113
    filler2:
      load: 3.2532
    low:
      load: 1.87698
  it "Should return an array.", ->
    assert Array.isArray surveyor.sortDrones drones
  it "Should have the lowest loaded drone at position 0", ->
    assert.equal (surveyor.sortDrones drones)[0], 'low'
  it "Should have the highest loaded drone at last position", ->
    sorted = surveyor.sortDrones drones
    assert.equal sorted[sorted.length - 1], 'high'

describe 'routing', ->
  it "Should create the routing table correctly", ->
    model =
      manifest:
        repo1:
          opts:
            commit: "1"
          routing:
            domain: "repo1.example.com"
        repo2:
          opts:
            commit: "2"
          routing:
            domain: "repo2.example.com"
            method: "ip_hash"
        repo3:
          opts:
            commit: "3"
          routing:
            domain: "repo3.example.com"
      portMap:
        drone1:
          pid1:
            repo: "repo1"
            port: 8000
            commit: "1"
          pid2:
            repo: "repo2"
            port: 8001
            commit: "2"
        drone2:
          pid3:
            repo: "repo1"
            port: 8001
            commit: "1"
          pid4:
            repo: "repo3"
            port: 8000
            commit: "3"
      swarm:
        drone1:
          host: "drone1.example.com"
          procs:
            pid1:
              status: "running"
            pid2:
              status: "running"
        drone2:
          host: "drone2.example.com"
          procs:
            pid3:
              status: "running"
            pid4:
              status: "running"

    model = surveyor.createRoutingTable model
    assert.deepEqual model.routingTable,
      repo1:
        domain: 'repo1.example.com'
        routes: [
          {
            host: 'drone1.example.com'
            port: 8000
          }
          {
            host: 'drone2.example.com'
            port: 8001
          }
        ]
      repo2:
        domain: 'repo2.example.com'
        method: 'ip_hash'
        routes: [
          {
            host: 'drone1.example.com'
            port: 8001
          }
        ]
      repo3:
        domain: 'repo3.example.com'
        routes: [
          {
            host: 'drone2.example.com'
            port: 8000
          }
        ]
  it "Should clear non-existent processes from the portMap", ->
    model =
      portMap:
        drone1:
          pid1: "ohai"
          pid2: "ohai"
        drone2:
          pid3: "ohai"
          pid4: "ohai"
      swarm:
        drone1:
          procs:
            pid2:
              status: "running"
        drone2:
          procs:
            pid3:
              status: "running"
            pid4:
              status: "restarting"
    model = surveyor.clearStalePortMaps model
    assert.deepEqual model.portMap,
      drone1:
        pid2: "ohai"
      drone2:
        pid3: "ohai"
        pid4: "ohai"
