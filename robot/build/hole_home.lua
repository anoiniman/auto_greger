local Module = {parent = nil}

local deep_copy = require("deep_copy")
local meta_door = require("build.MetaBuild.MetaDoorInfo")
local general_functions = require("build.general_functions")


Module.name = "hole_home"

Module.dictionary = {
    --["t"] = "Torch",
    --["d"] = {"sub", "dirt", "any"}, -- instruction, base, alternative(s) "any" == any
    ["d"]  = "Dirt"
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.human_readable = {
    "def", -- MetaData, string internalization for the win I guess
    {
    "-------", -- stairs from the top
    "-------",
    "-------",
    "-------",
    "-------",
    "-------",
    "-------",
    }
}
--  TODO: I think we'll simply improve the algorimth rather than, or in conjunction with defining walls
--  "ddddddd",
--  "dd----d",
--  "dd----d",
--  "dd----d",
--  "dd----d",
--  "d-----d",
--  "ddddddd",

local a = Module.human_readable
Module.origin_block = {0,0,-5} -- x, z, y
Module.base_table = { def = a, } -- def == default

-- local stairing = {1, 2, 3, 4, 5} - platitude
local sub_segment = {}
for index = 1, 5, 1 do
    local new_sub_seg = {}
    for j = 1, index, 1 do
        new_sub_seg[j] = j
    end

    sub_segment[index] = new_sub_seg
end

local ss = sub_segment
local b = "d------"
Module.segments = {
    [1] = {{b, ss[1]}},
    [2] = {{b, ss[2]}},
    [3] = {{b, ss[3]}},
    [4] = {{b, ss[4]}},
    [5] = {{b, ss[5]}}
}

Module.doors = {}
Module.doors[1] = meta_door:new()
Module.doors[1]:doorX(6,2)

Module.extra_sauce = {"top_to_bottom"}

-- consuming what function is to be executed
-- "Which Iteration" <-> "Which Height/Level"
function Module:iter()
    return general_functions.iter(self.base_table, 5, self.segments)
end

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
