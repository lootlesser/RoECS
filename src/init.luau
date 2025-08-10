--!strict
--!native
--!optimize 2

local World = require(script.world)
local types = require(script.types)
local utils = require(script.utils)

local worlds: { [string]: types.World } = {}
local default: string?

local lib = {}

function lib.world(name: string?, is_default: boolean?): types.World
    if not name then
        assert(default, `${utils.error_prefix} No default world set so you must specify a name`)
        return worlds[default]
    end

    local world = worlds[name]
     
    if world then
        return world
    end

    local new_world = World.new()

    worlds[name] = new_world

    if is_default then
        default = name
    end

    return new_world
end

lib.utils = utils


return lib