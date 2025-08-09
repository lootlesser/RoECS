--!strict
--!native
--!optimize 2

export type Component<T> = {
    default: T,
    id: number,
    is_table: boolean,
}

export type Query<A...> = {
    view_all: (callback: (count: number, A...) -> ()) -> (),
}

export type Archetype = {
    cache: { { any } },
    index_to_id: { [number]: number },
    id_to_index: { [number]: number },
    entity_count: number,
}

export type Entity = number

local query_record = {}
local query_archetype_record = {}
local archetype_record: { [number]: Archetype } = {}
local component_record: { [number]: any } = {}
local component_is_table = {}

-----------------------------------------------
--                  Utils                    --
-----------------------------------------------
local function calculate_component_tuple_mask(components: { number }): number
    local mask = 0
    for i = 1, #components do
        local component = components[i]
        mask = bit32.replace(mask, 1, component)
    end

    return mask
end

-----------------------------------------------
--                  Component                --
-----------------------------------------------
local component_id_counter = 1

local function create_component<T>(default: T): {T}
    local id = component_id_counter
    component_id_counter += 1
    component_record[id] = default
    component_is_table[id] = typeof(default) == "table"
    return id:: any
end

-----------------------------------------------
--                  Query                    --
-----------------------------------------------
function build_query(mask, components)
    local query_archetypes = {}

    for archetype_mask, archetype in archetype_record do
        if bit32.band(archetype_mask, mask) == mask then
            local id_to_index = archetype.id_to_index
            local cache = archetype.cache
            local view = {}
            for i = 1, #components do
                local component = components[i]
                local index = id_to_index[component]
                table.insert(view, cache[index])
            end
            table.insert(query_archetypes, view)
        end
    end

    local function view_all(callback: (number, ...any) -> ())
        local local_query_archetypes = query_archetype_record[mask]
        for i = 1, #local_query_archetypes do
            local view = local_query_archetypes[i]
            callback(#view[1], table.unpack(view))
        end
    end

    local query = {
        view_all = view_all,
    }
    
    query_record[mask] = query
    query_archetype_record[mask] = query_archetypes

    return query
end

function create_query<A...>(...: A...): Query<A...>
    local components: { [any]: number } = table.pack(...):: any
    components["n"] = nil

    local mask = calculate_component_tuple_mask(components)
    
    return query_record[mask] or build_query(mask, components)
end

-----------------------------------------------
--                 Archetype                 --
-----------------------------------------------
local function create_archetype(mask: number, components: { number }): Archetype
    local cache = {}
    local index_to_id = {}
    local id_to_index = {}

    for i = 1, #components do
        local id = components[i]

        table.insert(cache, {})
        index_to_id[i] = id
        id_to_index[id] = i
    end

    local archetype = {
        cache = cache,
        index_to_id = index_to_id,
        id_to_index = id_to_index,
        entity_count = 0,
    }

    archetype_record[mask] = archetype

    --TODO : Make this more performant (switch to selective rebuilding)
    for query_mask, _ in query_record do
        if bit32.band(mask, query_mask) == query_mask then
            build_query(query_mask, components)
        end
    end

    return archetype
end

-----------------------------------------------
--                 Entity                    --
-----------------------------------------------
local entity_cache = {}
local entity_id_counter = 1

local function create_entity(...): Entity
    local id = entity_id_counter
    entity_id_counter += 1

    local components: { number } = {...}

    local mask = calculate_component_tuple_mask(components)

    local archetype: Archetype = archetype_record[mask] or create_archetype(mask, components)
    
    archetype.entity_count += 1

    local id_to_index = archetype.id_to_index
    local cache = archetype.cache

    for i = 1, #components do
        local component = components[i]
        local index = id_to_index[component]
        local default = component_record[component]

        if component_is_table[component] then
            default = table.clone(default)
        end

        table.insert(cache[index], default)
    end

    entity_cache[id] = mask

    return id
end

-----------------------------------------------
--                 Tests                     --
-----------------------------------------------
local position = create_component(Vector3.new(0, 0, 0))
local velocity = create_component(Vector3.new(1, 1, 1))
local gravity = create_component(nil)

local query_1 = create_query(position, velocity)
local query_2 = create_query(position)
local query_3 = create_query(position, velocity, gravity)
local query_4 = create_query(velocity)

for _ = 1, 800_000 do
    create_entity(position, velocity, gravity)
end

game:GetService("RunService").Heartbeat:Connect(function()
    query_1.view_all(function(count, positions, velocities)

        for i = 1, count do end        

    
    end)

    query_2.view_all(function(count, positions)

         for i = 1, count do end 

    end)

    query_3.view_all(function(count, positions, velocities, gravity)

        for i = 1, count do end

    end)

    query_4.view_all(function(count, velocities)

        for i = 1, count do end

    end)

end)



return 0