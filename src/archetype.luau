--!strict
--!native
--!optimize 2

-- TODO implement support for entity removal by swapping entities

local types = require(script.Parent.types)
local utils = require(script.Parent.utils)

type World = types.World
type Archetype = types.Archetype

local Archetype = {}

-- Creates a new archetype and adds it to the world
function Archetype.new(world: World, archetype_mask_array: buffer, mask_hash: string): Archetype
    local cache = {}
    local cache_index_to_component_id = {}
    local component_id_to_cache_index = {}

    for i = 0, 7 do 
        local mask = buffer.readu32(archetype_mask_array, i)
        if mask == 0 then
            continue
        end
        for component_id = 0, 31 do
            if bit32.extract(mask, component_id) == 1 then
               table.insert(cache, {})
               local index = #cache
               cache_index_to_component_id[index] = component_id
               component_id_to_cache_index[component_id] = index
            end
        end
    end

    local archetype = {
        cache = cache,
        component_id_to_cache_index = component_id_to_cache_index,
        cache_index_to_component_id = cache_index_to_component_id,
        entity_id_to_cache_position = {},
        cache_position_to_entity_id = {},
        entity_count = 0,
    }

    local world_query_masks = world.query_masks

    for query_index = 1, #world_query_masks do
        local query_mask_array = world_query_masks[query_index]

        local match = true
        for buffer_index = 0, utils.chunks_zeroed do
            local archetype_mask = buffer.readu32(archetype_mask_array, buffer_index)
            local query_mask = buffer.readu32(query_mask_array, buffer_index)
            if bit32.band(archetype_mask, query_mask) ~= query_mask then
                match = false
                break
            end
        end
        if not match then
            continue
        end
        local query_components = world.query_components[query_index]
        local query_views = world.query_views[query_index]
        local view = {}
        for n = 1, #query_components do
            local component = query_components[n]
            local cache_index = component_id_to_cache_index[component]
            table.insert(view, cache[cache_index])
        end
        table.insert(query_views, view)
    end

    local archetypes = world.archetypes
    table.insert(archetypes, archetype)
    local index = #archetypes
    world.archetype_masks[index] = archetype_mask_array
    world.archetype_hash_to_index[mask_hash] = index

    return archetype
end


local defaults_temp = table.freeze{}

function Archetype.add_entity(world: World, archetype: Archetype, entity_id: number, given_defaults: { [number]: any }?)
    archetype.entity_count += 1
    local cache_position = archetype.entity_count

    local cache = archetype.cache
    local cache_index_to_component_id = archetype.cache_index_to_component_id

    local defaults = given_defaults or defaults_temp
    local is_component_tables = world.is_component_tables

    for index = 1, #cache do
        local component_cache = cache[index]
        local component_id = cache_index_to_component_id[index]
        local default = defaults[component_id] or world.component_defaults[component_id]
        if is_component_tables[component_id] then
            default = table.clone(default)
        end
        component_cache[cache_position] = default
    end

    archetype.entity_id_to_cache_position[entity_id] = cache_position
    archetype.cache_position_to_entity_id[cache_position] = entity_id
end

function Archetype.transition_entity(world: World, entity_id: number, old_archetype: Archetype, new_archetype: Archetype, given_defaults: { [number]: any }?)
    new_archetype.entity_count += 1

    local old_cache = old_archetype.cache
    local new_cache = new_archetype.cache

    local old_cache_position = old_archetype.entity_id_to_cache_position[entity_id]
    local last_cache_position = old_archetype.entity_count

    local new_cache_index_to_component_id = new_archetype.cache_index_to_component_id
    local old_component_id_to_cache_index = old_archetype.component_id_to_cache_index
    local world_component_defaults = world.component_defaults

    local new_cache_position = new_archetype.entity_count

    -- use pre-allocated empty-table if given defaults is nil
    local defaults = given_defaults or defaults_temp
    local is_component_tables = world.is_component_tables

    -- for every data in the new archetype if there is the same component in the old archetype, copy the data else copy from default
    for i = 1, #new_cache do
        local component_id = new_cache_index_to_component_id[i]
        local old_index = old_component_id_to_cache_index[component_id]

        local new_component_cache = new_cache[i]

        if old_index then
            local old_component_cache = old_cache[old_index]
            local old_component_data = old_component_cache[old_cache_position]
            new_component_cache[new_cache_position] = old_component_data

            -- Swap the last data in the cache to the current positon and del the last positon from the old archetype
            if last_cache_position ~= old_cache_position then
                old_component_cache[old_cache_position] = old_component_cache[last_cache_position]
            end

            old_component_cache[last_cache_position] = nil
        else
            local default = defaults[component_id] or world_component_defaults[component_id]
            if is_component_tables[component_id] then
                default = table.clone(default)
            end
            new_component_cache[new_cache_position] = default
        end
    end

    -- Swap the last pointers for the removed entity pointers and remove the last pointer from the old archetype
    local old_cache_position_to_entity_id = old_archetype.cache_position_to_entity_id
    local old_entity_id_to_cache_position = old_archetype.entity_id_to_cache_position

    local last_entity_id = old_cache_position_to_entity_id[last_cache_position]

    old_cache_position_to_entity_id[last_cache_position] = nil
    old_entity_id_to_cache_position[entity_id] = nil

    if last_cache_position ~= old_cache_position then
        old_entity_id_to_cache_position[last_entity_id] = old_cache_position
        old_cache_position_to_entity_id[old_cache_position] = last_entity_id
    end

    old_archetype.entity_count -= 1

    new_archetype.cache_position_to_entity_id[new_cache_position] = entity_id
    new_archetype.entity_id_to_cache_position[entity_id] = new_cache_position
end


return Archetype