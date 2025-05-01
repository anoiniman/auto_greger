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
Module.origin_block = {0,0,0} -- x, z, y
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

-- consuming what function is to be executed
-- "Which Iteration" <-> "Which Height/Level"
function Module:iter()
    general_functions.iter(self.base_table, 3, self.segments)
end

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
