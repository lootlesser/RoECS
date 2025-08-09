--!strict
--!native
--!optimize 2

local max_components = 256
local chunks = math.ceil(max_components / 32)
local buffer_size = chunks * 4

local utils = {}

function utils.add_components_to_mask(components: { number }, old_mask_array: buffer?): buffer
    local new_mask_array = old_mask_array or buffer.create(buffer_size)
    for i = 1, #components do
        local component = components[i]
        local chunk = component // 32
        local mask = buffer.readu32(new_mask_array, chunk)
        local bit_index = component % 32
        mask = bit32.replace(mask, 1, bit_index)
        buffer.writeu32(new_mask_array, chunk, mask)
    end
    return new_mask_array
end


function utils.pack(...): {}
    return {...}
end

utils.log_prefix = "[RoECS] [LOG]: "
utils.error_prefix = "[RoECS] [ERROR]: "
utils.warn_prefix = "[RoECS] [WARN]: "
utils.buffer_size = buffer_size
utils.max_components = max_components
utils.chunks = chunks
utils.chunks_zeroed = chunks - 1

return table.freeze(utils)