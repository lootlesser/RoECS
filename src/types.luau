--!strict

export type Archetype = {
    entity_count: number,
    cache: { { any } },
    cache_index_to_component_id: { [number]: number },
    component_id_to_cache_index: { [number]: number },
    entity_id_to_cache_position: { [number]: number },
    cache_position_to_entity_id: { [number]: number },
}

export type Query<A...> = {
    view_all: (callback: (count: number, A...) -> ()) -> (),
}

export type Component<T = any> = { T }

export type World = {
    archetypes: { Archetype },
    archetype_masks: { buffer },
    archetype_hash_to_index : { [string]: number },

    entities_hash: { [number]: string },
    entities_masks: { [number]: buffer },

    component_defaults: { [number]: any },

    queries: { Query<...any> },
    query_masks: { buffer },
    query_components: { { number } },
    query_views: { { any } },
    query_hash_to_index : { [string]: number },

    entity_id_counter: number,
    free_entity_ids: { [number]: number },
    component_id_counter: number,

    spawn: (World, ...any) -> number,
    despawn: (World, number) -> (),

    attach: <T>(World, number, component: { T }, default: T?) -> World,
    detach: <T>(World, number, component: { T }) -> World,
    
    component: <T>(World, T) -> { T },
    query: <T...>(World, T...) -> Query<T...>,
}

return nil