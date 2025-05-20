-- This might be overly complicated for now, why don't we just run these extra instruction as separate
-- script instructions rather than as part of a build?
local deep_copy = require("deep_copy")
local comms = require("comms")

local Module = {
    rel_coords = nil,
    chunk_coords = nil,
    door_info = nil,
    block_name = nil,
    extra_sauce = nil
}

-- local function nav_and_build(rel_coords, what_chunk, door_info, block_name, post_run)
function Module:zeroed()
    return deep_copy.copy(self, pairs) 
end

function Module:newBasic(rel, chunk, door, block)
    local new = self:zeroed()
    new.rel_coords = rel
    new.chunk_coords = chunk
    new.door_info = door
    new.block_name = block
    return new
end

function Module:addExtra(str_name, args)
    if str_name == "build_shell" then
        error(comms.robot_send("fatal", "non-implemented instruction"))
    elseif str_name == "force_clear" then

    elseif str_name == "smart_clear" then

    end
end

return module
