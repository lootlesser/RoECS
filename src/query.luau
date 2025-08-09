--!strict
--!native
--!optimize 2

local types = require(script.Parent.types)
local utils = require(script.Parent.utils)

type World = types.World
type Archetype = types.Archetype
type Query<A...> = types.Query<A...>

local Query = {}

function Query.new<A...>(world: World, ...: A...): Query<A...>
    local world_query = world.queries

    local components: { number } = utils.pack(...)
    local query_mask_array = utils.add_components_to_mask(components)
    local hash = buffer.tostring(query_mask_array)
    local index = world.query_hash_to_index[hash]

    if index then
        return world_query[index]
    end

    local views = {}

    local archetype_masks = world.archetype_masks

    for i = 1, #archetype_masks do
        local archetype_mask_array = archetype_masks[i]
        local archetype = world.archetypes[i]
        local match = true
        for buffer_index = 0, utils.chunks_zeroed do
            local query_mask = buffer.readu32(query_mask_array, buffer_index)
            local archetype_mask = buffer.readu32(archetype_mask_array, buffer_index)
            if bit32.band(archetype_mask, query_mask) ~= query_mask then
                match = false
                break
            end
        end
        if not match then
            continue
        end
        local view = {}
        local cache = archetype.cache
        local component_id_to_cache_index = archetype.component_id_to_cache_index
        for n = 1, #components do
            local component = components[n]
            local cache_index = component_id_to_cache_index[component]
            table.insert(view, cache[cache_index])
        end
        table.insert(views, view)        
    end

    local function view_all(callback: (number, ...any) -> ())
        for i = 1, #views do
            local view = views[i]
            callback(#view[1], table.unpack(view))
        end
    end

    local query = table.freeze{
        view_all = view_all,
    }

    table.insert(world_query, query)
    local query_index = #world_query

    world.query_masks[query_index] = query_mask_array
    world.query_components[query_index] = components
    world.query_views[query_index] = views

    world.query_hash_to_index[hash] = query_index
    
    return query
end

return Query