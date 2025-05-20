-- This might be overly complicated for now, why don't we just run these extra instruction as separate
-- script instructions rather than as part of a build?
local deep_copy = require("deep_copy")
local comms = require("comms")

local Module = {
    rel_coords = nil,
    what_chunk = nil,
    door_info = nil,
    block_name = nil,
    extra_sauce = nil
}

-- local function nav_and_build(rel_coords, what_chunk, door_info, block_name, post_run)
function Module:zeroed()
    return deep_copy.copy(self, pairs) 
end

function Module:newBasic(rel, block)
    local new = self:zeroed()
    new.rel_coords = rel
    new.block_name = block
    return new
end

-- For clarity, this instead of table.unpack()
function Module.unpack()
    return self.rel_coords, self.what_chunk, self.door_info, self.block_name, self.extra_sauce
end


function Module:addDoors(door)
    self.door_info = door
end

function Module:addChunkCoords(what_chunk)
    self.what_chunk = what_chunk
end

function Module:addExtra(str_name, args)
    if str_name == "build_shell" then
        error(comms.robot_send("fatal", "non-implemented instruction"))
    elseif str_name == "force_clear" then

    elseif str_name == "smart_clear" then

    end
end

return module
