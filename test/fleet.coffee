assert = require 'assert'
fleet = require '../lib/fleet'

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
