--!strict
--!native
--!optimize 2

local types = require(script.Parent.types)
type World = types.World

local Component = {}

function Component.new<T>(world: World, default: T): { T }
    local component_id = world.component_id_counter
    world.component_defaults[component_id] = default
    world.component_id_counter += 1
    world.is_component_tables[component_id] = typeof(default) == "table"
    return (component_id:: any):: { T }
end

return Component