assert = require 'assert'
fleet = require '../lib/fleet'

describe 'fleet', ->
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
      assert Array.isArray fleet.sortDrones drones
    it "Should have the lowest loaded drone at position 0", ->
      assert.equal (fleet.sortDrones drones)[0], 'low'
    it "Should have the highest loaded drone at last position", ->
      sorted = fleet.sortDrones drones
      assert.equal sorted[sorted.length - 1], 'high'
  describe 'bootstrapping', ->
    drones =
      drone1:
        load: 0
        procs: {}
      drone2:
        load: 0
        procs:{}
    manifest =
      bootstrapTask:
        instances: "*"
        load: 1
        opts:
          bootstrap: true
    it "Shouldn't return any drones if none are bootstrapped", (done) ->
      fleet.bootstrap null, drones, manifest, (err, drones) ->
        assert.equal Object.keys(drones).length, 0
        done()
    it "Should return only bootstrapped drones", (done) ->
      drones = JSON.parse JSON.stringify drones
      drones.strapped =
        load: 1
        procs:
          somePID:
            repo: "bootstrapTask"
      fleet.bootstrap null, drones, manifest, (err, drones) ->
        assert.equal Object.keys(drones).length, 1
        done()
