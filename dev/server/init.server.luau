--!strict
--!native
--!optimize 2

local ECS = require(game.ReplicatedStorage.RoECS)

local world = ECS.world("server", true)

local position = world:component("pos")
local velocity = world:component("vel")

local query1 = world:query(position)
local query2 = world:query(velocity)
local query3 = world:query(position, velocity)

local e1 = world:spawn(position)
local e2 = world:spawn(velocity)
local e3 = world:spawn(position, velocity)

world:attach(e2, position)
world:attach(e1, velocity)

query1.view_all(function(count, position)
    for i = 1, count do
        print("query1", position[i])
    end
end)

query2.view_all(function(count, velocity)
    for i = 1, count do
        print("query2", velocity[i])
    end
end)

query3.view_all(function(count, position, velocity)
     for i = 1, count do
        print("query3", position[i], velocity[i])
    end
end)