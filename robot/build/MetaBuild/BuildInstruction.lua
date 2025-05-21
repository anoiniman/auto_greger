-- This might be overly complicated for now, why don't we just run these extra instruction as separate
-- script instructions rather than as part of a build?
local deep_copy = require("deep_copy")
local comms = require("comms")

local Module = {
    rel_coords = nil,
    what_chunk = nil,
    door_info = nil,
    block_info = {lable = nil, name = nil},
    extra_sauce = nil
}

-- local function nav_and_build(rel_coords, what_chunk, door_info, block_name, post_run)
function Module:zeroed()
    return deep_copy.copy(self, pairs)
end

function Module:newBasic(rel, block_lable, block_name)
    -- Dangerous hack that should allow for some brain-dead polymorphism
    if type(block_lable) == "table" then
        block_name = block_lable[2]
        block_lable = block_lable[1]
    end

    local new = self:zeroed()
    new.rel_coords = rel
    new.block_info.lable = block_lable
    new.block_info.name = block_name
    return new
end

function Module:delete(str)
    local found = self[str]
    if found == nil then
        print("warning", "BuildInstruction:delete -- Attempted to delete something that is nil, \z
        check if what you are passing in \"str\" is valid, begin stack trace: ")
        debug.traceback()
    end
    self[str] = nil
end


-- For clarity, this instead of table.unpack()
function Module:unpack()
    return self.rel_coords, self.what_chunk, self.door_info, self.block_info
end

function Module:includesOr(str_array)
    if str_array == nil or type(str_array) ~= "table" then return false end

    for _, str in ipairs(str_array) do
        if self:includes(str) then
            return true
        end
    end
    return false
end


function Module:includes(str)
    if self.extra_sauce == nil then return false end
    for _, sauce in ipairs(self.extra_sauce) do
        if sauce == str then return true end
    end
    return false
end

function Module:addDoors(door)
    self.door_info = door
end

function Module:addChunkCoords(what_chunk)
    self.what_chunk = what_chunk
end

function Module:addMultipleExtras(extras)
    if type(extras) ~= table then
        self:addExtra(extras, nil)
    end

    for extra, args in pairs(extras) do
        self:addExtra(extra, args)
    end
end

-- smart clear by default
-- prob unecessary to do all these ifs idk
function Module:addExtra(str_name, args) -- luacheck: ignore args
    if str_name == "top_to_bottom" then
        table.insert(self.extra_sauce, str_name)
    elseif str_name == "build_shell" then
        error(comms.robot_send("fatal", "BuildInstruction: non-implemented instruction"))
    elseif str_name == "force_clear" then
        error(comms.robot_send("fatal", "BuildInstruction: non-implemented instruction"))
    else
        error(comms.robot_send("fatal", "BuildInstruction: non-recognized instruction"))
    end
end

return Module
