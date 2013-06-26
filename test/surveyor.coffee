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
