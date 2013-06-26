assert = require 'assert'
butler = require '../lib/butler'

describe 'routing', ->
  it "Should create the routing table correctly", ->
  model =
    swarm:
      drone1:
        host: "drone1.example.com"
        portMap:
          pid1:
            repo: "repo1"
            port: 8000
          pid2:
            repo: "repo2"
            port: 8001
      drone2:
        host: "drone2.example.com"
        portMap:
          pid3:
            repo: "repo1"
            port: 8001
          pid4:
            repo: "repo3"
            port: 8000

  butler.createRoutingTable model, (err, model) ->
    assert.equal err, null
    assert.equal model.routingTable, {
      repo1: [
        {
          host: 'drone1.example.com'
          port: 8000
        }
        {
          host: 'drone2.example.com'
          port: 8001
        }
      ]
      repo2: [
        {
          host: 'drone1.example.com'
          port: 8001
        }
      ]
      repo3: [
        {
          host: 'drone2.example.com'
          port: 8000
        }
      ]
    }
