local deep_copy = require("deep_copy")

local meta_door = require("build.MetaBuild.MetaDoorInfo")
local general_functions = require("build.general_functions")

local Module = {parent = nil}
Module.name = "coke_quad"

Module.dictionary = {
    ["c"] = "CokeOvenBrick", -- tmp name, I need to geolyze in game first or whatever
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.human_readable = {
    "def", -- MetaData, string internalization for the win I guess
    {
    "--ccc--",
    "--ccc--",
    "--ccc--",
    "-------",
    "--ccc--",
    "--ccc--",
    "--ccc--",
    }
}
Module.origin_pos = {0,0,0}
Module.base_table = { def = Module.human_readable } -- def == default

local two_six = {2, 6}
Module.segments = { -- This nil assignment schtick makes it so for 99% of the cases 'ipairs' no longer works :) btw
    [1] = {{"--ccc*-", two_six}},   -- for height 1 change this
    [2] = {{"--c-c--", two_six}},   -- for height 2 change this
    [3] = nil                       -- .. 
}

Module.doors = {}
doors[1] = meta_door:zeroed()
doors[1].doorX(6,2)

function Module:rotateX()
    general_functions.rotate_x(self.base_table, self.segments)
end

function Module:rotateY()
    general_function.rotate_y(self.base_table, self.segments)
end

-- consuming what function is to be executed
-- "Which Iteration" <-> "Which Height/Level"
function Module.iter(primitive)
    general_functions.iter(primitive.base_table, 3, primitive.segments)
end

function Module:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

return Module
