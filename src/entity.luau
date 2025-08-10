--!strict
--!native
--!optimize 2

local types = require(script.Parent.types)
local utils = require(script.Parent.utils)
local Archetype = require(script.Parent.archetype)

type World = types.World
type Archetype = types.Archetype

local spawn_defaults: { [number]: any } = {}
local attach_defaults: { [number]: any } = {}

local Entity = {}

-- Spawns an entity in the given world
function Entity.spawn(world: World, ...): number
    local temp_id = table.remove(world.free_entity_ids, 1)
    local entity_id: number

    if not temp_id then
        world.entity_id_counter += 1
        entity_id = world.entity_id_counter
    else
        entity_id = temp_id
    end

    local components: { number } = utils.pack(...)

    local mask_array = utils.add_components_to_mask(components)
    local hash = buffer.tostring(mask_array)
    local archetype_index = world.archetype_hash_to_index[hash]
    local archetype = world.archetypes[archetype_index] or Archetype.new(world, mask_array, hash)
    Archetype.add_entity(world, archetype, entity_id, spawn_defaults)
    table.clear(spawn_defaults)   

    world.entities_masks[entity_id] = mask_array
    world.entities_hash[entity_id] = hash

    return entity_id
end


function Entity.despawn(world: World, id: number)
    local hashes = world.entities_hash

    local hash = hashes[id]

    local archetype_index = world.archetype_hash_to_index[hash]
    local archetype = world.archetypes[archetype_index]
    Archetype.remove_entity(archetype, id)

    hashes[id] = nil
    world.entities_masks[id] = nil

    table.insert(world.free_entity_ids, id)
end

function Entity.detach<T>(world: World, entity_id: number, component_id: { T }): World
    assert(typeof(component_id) == "number", `${utils.error_prefix} componentId must be a number`)

    local old_mask_array = world.entities_masks[entity_id]
    local new_mask_array = buffer.create(utils.buffer_size)
    buffer.copy(new_mask_array, 0, old_mask_array)
    

    local chunk = component_id // 32
    local bit_index = component_id % 32
    local mask = buffer.readu32(new_mask_array, chunk)

    if bit32.extract(mask, bit_index) == 0 then
        return world
    end

    mask = bit32.replace(mask, 0, bit_index)
    buffer.writeu32(new_mask_array, chunk, mask)

    local old_hash = world.entities_hash[entity_id]
    local new_hash = buffer.tostring(new_mask_array)

    local archetype_hash_to_index = world.archetype_hash_to_index
    local new_index = archetype_hash_to_index[new_hash]
    local old_index = archetype_hash_to_index[old_hash]
    
    local old_archetype = world.archetypes[old_index]
    local new_archetype = world.archetypes[new_index] or Archetype.new(world, new_mask_array, new_hash)

    if old_archetype then
        Archetype.transition_entity(world, entity_id, old_archetype, new_archetype)
    else
        Archetype.add_entity(world, new_archetype, entity_id)
    end

    world.entities_masks[entity_id] = new_mask_array
    world.entities_hash[entity_id] = new_hash    

    return world
end

-- Attach the given component to the entity and move it to the new archetype
function Entity.attach<T>(world: World, entity_id: number, component_id: { T }, default_value: T?): World
    assert(typeof(component_id) == "number", `${utils.error_prefix} componentId must be a number`)

    local world_default = world.component_defaults[component_id]
    assert(world_default, `${utils.error_prefix} componentId ${component_id} does not exist`)
    
    local old_mask_array = world.entities_masks[entity_id]
    local new_mask_array = buffer.create(utils.buffer_size)
    buffer.copy(new_mask_array, 0, old_mask_array)

    local chunk = component_id // 32
    local bit_index = component_id % 32
    local mask = buffer.readu32(new_mask_array, chunk)

    if bit32.extract(mask, bit_index) == 1 then
        return world
    end
    
    mask = bit32.replace(mask, 1, bit_index)
    buffer.writeu32(new_mask_array, chunk, mask)

    local old_hash = world.entities_hash[entity_id]
    local new_hash = buffer.tostring(new_mask_array)

    local archetype_hash_to_index = world.archetype_hash_to_index
    local new_index = archetype_hash_to_index[new_hash]
    local old_index = archetype_hash_to_index[old_hash]
    
    local old_archetype = world.archetypes[old_index]
    local new_archetype = world.archetypes[new_index] or Archetype.new(world, new_mask_array, new_hash)
    attach_defaults[component_id] = default_value

    if old_archetype then
        -- we use pre allocated empty table to reduce overhead from table instantiation
        Archetype.transition_entity(world, entity_id, old_archetype, new_archetype, attach_defaults)
    else
        Archetype.add_entity(world, new_archetype, entity_id, attach_defaults)
        
    end

    attach_defaults[component_id] = nil
    world.entities_masks[entity_id] = new_mask_array
    world.entities_hash[entity_id] = new_hash

    return world
end

return Entity