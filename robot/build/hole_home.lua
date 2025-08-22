local Module = {parent = nil}

local deep_copy = require("deep_copy")
local meta_door = require("build.MetaBuild.MetaDoorInfo")
-- local general_functions = require("build.general_functions")


Module.name = "hole_home"

-- we'll need to place the chosen power generator since it is a non OpenOS part, but the rest we'll place by hand,
-- because... uhhhhh yeah, the rules, and then I guess locking ourselves in really is easier manually, eventually
-- we'll sub a door in I guess idk
Module.dictionary = {
    --["t"] = "Torch",
    --["d"] = {"sub", "dirt", "any"}, -- instruction, base, alternative(s) "any" == any
    ["d"] = {"nil", "any:grass"},
    ["a"] = {"air", "shovel"},
    ["s"] = {"air", "shovel"},
    ["r"] = "Radioisotope Thermoelectric Generator",
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.base_table = {
    {
    "*------", -- OSS will be to the right of the * point, or atleast adjacent to it
    "a------",
    "a------",
    "a------",
    "-------",
    "-------",
    "-------",
    },
    {
    "-------",
    "-------",
    "a------",
    "a||||||",
    "a||||||",
    "-||||||",
    "-||||||",
    },
    {
    "-------",
    "-------",
    "-||||||",
    "a||||||",
    "a||||||",
    "a||||||",
    "-||||||",
    },
    {
    "-------",
    "-------",
    "-|||||r",
    "-||||||",
    "a||||||",
    "a||||||",
    "a||||||",
    },
    -- dirt floor here
}

Module.origin_block = {0,0,-5} -- x, z, y

Module.doors = {}
Module.doors[1] = meta_door:new()
Module.doors[1]:doorX(1,1)

Module.extra_sauce = {"top_to_bottom"}

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
