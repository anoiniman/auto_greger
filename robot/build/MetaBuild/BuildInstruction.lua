-- This might be overly complicated for now, why don't we just run these extra instruction as separate
-- script instructions rather than as part of a build?
local deep_copy = require("deep_copy")
local comms = require("comms")

local Module = {
    what_base_type = nil,
    rel_coords = nil,
    what_chunk = nil, -- we are reliant on consumers pinky promissing not to mutate this ref :)
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
        block_lable = block_lable[1]
        block_name = block_lable[2]
    end

    local new = self:zeroed()
    new.rel_coords = rel
    new.block_info.lable = block_lable
    new.block_info.name = block_name

    new.what_base_type = "basic_build"
    return new
end

function Module:roadBuild(what_chunk, height)
    local new = self:zeroed()
    if height < 0 or height > 255 then
        print(comms.robot_send("error", "BuildInstructions:roadBuild, height set to something invalid!"))
    end

    new.what_chunk = what_chunk
    new.rel_coords = {-1, -1, height}

    new.what_base_type = "only_chunk"
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
function Module:nav_and_build_unpack()
    return self.rel_coords, self.what_chunk, self.door_info, self.block_info
end

function Module:includesOr(str_array)
    if str_array == nil then return false end
    if type(str_array) ~= "table" then return self:includes(str_array) end

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
        if type(sauce) == "table" then
            if sauce[1] == str then return true end
            goto continue
        end

        if sauce == str then return true end
        ::continue::
    end
    return false
end

function Module:getArg(str)
    if self.extra_sauce == nil then return nil end
    local found = nil
    for _, sauce in ipairs(self.extra_sauce) do
        if type(sauce) ~= "table" then goto continue end
        if sauce[1] == str then return sauce end

        ::continue::
    end
    return nil
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
function Module:addExtra(str_name, args)
    for _, cur_str in ipairs(self.extra_sauce) do
        if type(cur_str) == "table" then -- it doesn't care about arguments
            if cur_str[1] == str_name then
               print(comms.robot_send("debug", "BuildInstruction, instruction already present (in table), skipping"))
               return
            end
            goto continue
        end

        if cur_str == str_name then
            print(comms.robot_send("debug", "BuildInstruction, instruction already present, skipping"))
            return
        end

        ::continue::
    end

    local to_insert = str_name
    if args ~= nil then
        if type(args) == "table" then
             to_insert = {str_name, table.unpack(args)}
        else
            to_insert = {str_name, args}
        end
    end

    table.insert(self.extra_sauce, to_insert)
end

return Module
