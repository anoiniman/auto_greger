local math = require("math")
local comms = require("comms")

local Module = {
    is_nil = true,
    primitive = {},

    door_info = { MetaDoorInfo:zeroed() },
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
    self.
end

function Module:require(name)
    self.primitive = dofile("build." .. name)
    self.init_primitive()

    local human_read = self.primitive.human_readable
    local schematic = self.schematic

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
end

function Module:getName()
    return primitive.name 
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


return Module
