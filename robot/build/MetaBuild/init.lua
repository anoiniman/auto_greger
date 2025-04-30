local math = require("math")
local comms = require("comms")

local build_cache = {}  -- as you might have noticed this value exists outside the MetaTable(s)
                        -- so it exists as a singleton all "inheritors" of the MetaTable have the same
                        -- reference for "build_cache"

local Module = {
    is_nil = true,
    built = false,
    primitive = {}, -- pretend that there is a 'const' keyword here, "the primitve" is a 
                    -- reference that must NEVER be modified, only deep_copied or referenced without mut

    --door_info = { MetaDoorInfo:zeroed() },
    schematic = MetaMetaSchematic:new()
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

function Module:require(name)
    if build_cache[name] ~= nil then 
        self = build_cache[name]
        return true
    end

    no_error, build_table = pcall(dofile("/home/robot/build/" .. name))
    if no_error then
        self.primitive = build_table
    else
        print(comms.robot_send("error", "MetaBuild -- require -- No such build with name: \"" .. name .. "\""))
        return false
    end
    self.init_primitive()

    local human_read = self.primitive.human_readable
    local schematic = self.schematic
    schematic.iter_init_func = self.primitive.iter

    self.checkHumanMap(human_read, name)
    if schematic.iter_init_func == nil then
        for index = 1, #human_read, 1 do
            schematic.parseStringArr(human_read, index)
        end
    else
        for index, human_read_obj in schematic.iter_init_func(human_read) do
            schematic.parseStringArr(human_read_obj, index)
        end
    end

    table.insert(build_cache, 1, self)
    return true
end

function Module:getName()
    return self.primitive.name 
end

function Module:getSchematic()
    return self.
end

function Module:isBuilt()
    return self.built
end

function Module:checkHumanMap(map, name)
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
    return 0
end

function Module:getDoors()
    return self.primitive.doors
end


return Module
