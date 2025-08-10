--!strict
--!native
--!optimize 2

local types = require(script.Parent.types)
local Query = require(script.Parent.query)
local Entity = require(script.Parent.entity)
local Component = require(script.Parent.component)

type World = types.World
type WorldInterface = types.World

local World = {}

function World.new(): WorldInterface

    local world: World = {
        archetypes = {},
        archetype_hash_to_index = {},
        archetype_masks = {},

        queries = {},
        query_masks = {},
        query_hash_to_index = {},
        query_components = {},
        query_views = {},

        entities_hash = {},
        entities_masks = {},

        component_defaults = {},

        entity_id_counter = 0,
        free_entity_ids = {},
        
        component_id_counter = 0,

        component = Component.new,
        query = Query.new,
        spawn = Entity.spawn,
        despawn = Entity.despawn,
        attach = Entity.attach,
        detach = Entity.detach
    }

    return (world:: any):: WorldInterface
end


return World