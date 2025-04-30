local math = require("math")
local comms = require("comms")

local SchematicInterface = require("build.MetaBuild.SchematicInterface")

local BuildStack = { -- reading head maxxed printer pilled state machine adjacent
    rel_x = 0,
    rel_z = 0,
    height = 0,

    logical_x = 0,
    logical_z = 0,
    logical_y = 0
}
function BuildStack:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end



local primitive_cache = {}  -- as you might have noticed this value exists outside the MetaTable(s)
                            -- so it exists as a singleton all "inheritors" of the MetaTable have the same
                            -- reference for "build_cache"

local Module = {
    is_nil = true,
    built = false,
    primitive = {},

    build_stack = nil
    s_interface = nil
}
Module.__index = Module

function Module:new()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function Module:init_primitive()
    self.primitive.parent = self
end


function Module:rotatePrimitive(quad_num)
    if quad_num == 1 then
        
    end
end

function Module:setupBuild()
    local base_table = self.primitive.base_table

    if self.s_interface == nil then self.s_interface = SchematicInterface:new()
    local s_interface = self.s_interface
    s_interface.iter_init_func = self.primitive.iter

    self.checkHumanMap(base_table, primitive.name)
    if s_interface.iter_init_func == nil then
        for index = 1, #base_table, 1 do -- if we haven't defined a custom iterator, then the base_table must be ipairs-able
            s_interface.parseStringArr(base_table[index], index)
        end
    else
        for index, table_obj in s_interface.iter_init_func() do -- it is expected that table object does not include meta-data
            s_interface.parseStringArr(table_obj, index)
        end
    end
end

function Module:require(name)
    if primitive_cache[name] ~= nil then 
        self.primitive = primitive_cache[name].new()
        self.init_primitive()
        return true
    end

    no_error, build_table = pcall(dofile("/home/robot/build/" .. name))
    if no_error then
        self.primitive = build_table.new()
        primitive_cache[name] = build_table
        self.init_primitive()

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
