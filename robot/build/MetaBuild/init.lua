local math = require("math")

local comms = require("comms")
local deep_copy = require("deep_copy")

local general_functions = require("build.general_functions")
local SchematicInterface = require("build.MetaBuild.SchematicInterface")


local primitive_cache = {}  -- as you might have noticed this value exists outside the MetaTable(s)
                            -- so it exists as a singleton all "inheritors" of the MetaTable have the same
                            -- reference for "build_cache"

local Module = {
    is_nil = true,
    built = false,
    primitive = {},

    build_stack = nil,
    s_interface = nil
}

function Module:new()
    return deep_copy.copy(self, pairs)
end

function Module:doBuild()
    if s_interface == nil then
        print(comms.robot_send("error", "MetaBuild, doBuild, attempted to build with nil s_interface, init plz"))
        return false
    end

    return self.s_interface.doBuild() -- string, 3d-coords, symbol 
end

function Module:initPrimitive()
    self.primitive.parent = self
end

function Module:rotateAndTranslatePrimitive(quad_num, logical_chunk_height)
    local base_table = self.primitive.base_table
    local segments = self.primitive.segments
    local origin_block = self.primitive.origin_block

    origin_block[3] = origin_block[3] + logical_chunk_height -- y

    if quad_num == 1 then
        general_functions.mirror_x(base_table, segments)

        origin_block[1] = origin_block[1] + 8 -- x
        origin_block[2] = origin_block[2] + 1 -- z
    elseif quad_num == 2 then
        origin_block[1] = origin_block[1] + 1
        origin_block[2] = origin_block[2] + 1
    elseif quad_num == 3 then
        general_functions.mirror_z(base_table, segments)

        origin_block[1] = origin_block[1] + 1
        origin_block[2] = origin_block[2] + 8
    elseif quad_num == 4 then
        general_functions.mirror_x(base_table, segments)
        general_functions.mirror_z(base_table, segments)

        origin_block[1] = origin_block[1] + 8 -- x
        origin_block[2] = origin_block[2] + 8
    else
        print(comms.robot_send("error", "MetaBuild rotatePrimitive impossible quad_num: " .. quad_num))
        return false
    end
    return true
end

--[[function Module:translatePrimitive(quad_num)

end--]]

function Module:dumpPrimitive()
    self.primitive = nil
end

function Module:setupBuild()
    local base_table = self.primitive.base_table

    if self.s_interface == nil then self.s_interface = SchematicInterface:new() end
    self.s_interface.dictionary = primitive.dictionary
    self.s_interface.origin_block = primitive.origin_block

    if self:checkHumanMap(base_table, primitive.name) ~= 0 then -- sanity check
        return false
    end

    -- Build the sparse array
    local iter_function = nil
    if self.primitive.iter == nil then -- if we haven't defined a custom iterator, then the base_table must be ipairs-able
        iter_function = ipairs
    else
        iter_function = self.primitive.iter
    end

    -- ATTENTION: VVVVVVVVVVVVVVVVVVVVVVVVV
    -- if returning the length of the MetaSchematic tables is faulty, we'll need to count the height of buildings here
    -- thanks to the magic of lua bogus arguments are ok!
    for index, table_obj in iter_function(base_table) do -- it is expected that table object does not include meta-data
        self.s_interface:parseStringArr(table_obj, index)
        max_index = max_index + 1
    end

    self.is_nil = false
    return true
end

function Module:require(name)
    if primitive_cache[name] ~= nil then 
        self.primitive = primitive_cache[name]:new()
        self:initPrimitive()
        return true
    end

    no_error, build_table = pcall(dofile("/home/robot/build/" .. name))
    if no_error then
        self.primitive = build_table:new()
        primitive_cache[name] = build_table
        self:initPrimitive()

        return true
    else
        print(comms.robot_send("error", "MetaBuild -- require -- No such build with name: \"" .. name .. "\""))
        return false
    end
end

function Module:getName()
    return self.primitive.name 
end

function Module:getSchematicInterface()
    return self.s_interface
end

function Module:isBuilt()
    return self.built
end

function Module:checkHumanMap(base_table, name)
    local watch_dog = false
    for _, base in pairs(base_table) do
        if base[1] == "def" then -- I wish there was a re-usable way to write this logic, but no pass by ref, no luck
            if watch_dog == false then
                watch_dog = true
            else
                goto continue
            end
        end

        local map = base[2]
        if #map > 7 then
            comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Too Many Lines!")
            return -1
        end

        for index, line in ipairs(map) do
            if string.len(line) > 7 then
                comms.robot_send("error", "In human map -- Build: \"" .. name .. "\" -- Line: \"" .. tostring(index) .. "\" -- Line is way too big!")
                return index
            end
        end

        ::continue::
    end

    return 0
end

function Module:getDoors()
    return self.primitive.doors
end


return Module
