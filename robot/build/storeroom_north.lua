-- Made by Rinne0333
-- and corrected by me :)

local deep_copy = require("deep_copy")

local meta_door = require("build.MetaBuild.MetaDoorInfo")
local general_functions = require("build.general_functions")

local Module = {parent = nil}
Module.name = "storeroom_north"

Module.dictionary = {
    ["0"] = "Quarried Brick",
    ["1"] = "Birch Wood Planks",
    ["2"] = "Spruce Wood Planks",
    ["3"] = "Torch",
    -- Chest
    ["4"] = "Chest",
    ["5"] = "Trap Chest",
    -- Birch Wood Slab
    ["6"] = {"Birch Wood Slab", "up"},
    ["7"] = {"Birch Wood Slab", "down"},
    -- Spruce Wood Slab
    ["c"] = {"Spruce Wood Slab", "up"},
    ["e"] = {"Spruce Wood Slab", "down"},
    -- Stone Brick Slab
    ["8"] = {"Stone Brick Slab", "up"},
    ["9"] = {"Stone Brick Slab", "down"},
    -- Spruce Wood
    ["a"] = {"Spruce Wood", "up"},
    ["b"] = {"Spruce Wood", "north"},
    ["d"] = {"Spruce Wood", "east"},
    -- Birch Wood Stairs
    ["f"] = {"Birch Wood Stairs", "up", "north"},
    ["g"] = {"Birch Wood Stairs", "up", "south"},
    ["h"] = {"Birch Wood Stairs", "up", "east"},
    ["i"] = {"Birch Wood Stairs", "up", "west"},
    ["j"] = {"Birch Wood Stairs", "down", "north"},
    ["k"] = {"Birch Wood Stairs", "down", "south"},
    ["l"] = {"Birch Wood Stairs", "down", "east"},
    ["m"] = {"Birch Wood Stairs", "down", "west"},
    -- Spruce Wood Stairs
    ["n"] = {"Spruce Wood Stairs", "up", "north"},
    ["o"] = {"Spruce Wood Stairs", "up", "south"},
    ["p"] = {"Spruce Wood Stairs", "up", "east"},
    ["q"] = {"Spruce Wood Stairs", "up", "west"},
    ["r"] = {"Spruce Wood Stairs", "down", "north"},
    ["s"] = {"Spruce Wood Stairs", "down", "south"},
    ["t"] = {"Spruce Wood Stairs", "down", "east"},
    ["u"] = {"Spruce Wood Stairs", "down", "west"},
    -- Stone Bricks Stairs
    ["v"] = {"Stone Bricks Stairs", "up", "north"},
    ["w"] = {"Stone Bricks Stairs", "up", "south"},
    ["x"] = {"Stone Bricks Stairs", "up", "east"},
    ["y"] = {"Stone Bricks Stairs", "up", "west"},
    ["z"] = {"Stone Bricks Stairs", "down", "north"},
    ["A"] = {"Stone Bricks Stairs", "down", "south"},
    ["B"] = {"Stone Bricks Stairs", "down", "east"},
    ["C"] = {"Stone Bricks Stairs", "down", "west"},
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.layer0 = {
    "adddddd",
    "b000db2",
    "b0000b2",
    "b0000b2",
    "b0000b2",
    "b0000b2",
    "b000db2",
}
Module.layer1 = {
    "aBCB--C",
    "A211111",
    "922d---",
    "9244---",
    "9255---",
    "9244---",
    "z22d---",
}
Module.layer2 = {
    "axy---B",
    "w121111",
    "-12d3--",
    "-144---",
    "-155---",
    "-144---",
    "z12d3--",
}
Module.layer3 = {
    "aBC---x",
    "A221111",
    "912d---",
    "9144---",
    "9155---",
    "z144---",
    "A12d---",
}
Module.layer4 = {
    "ayx---B",
    "w221111",
    "812d---",
    "8144---",
    "8155---",
    "v144---",
    "w12d---",
}
Module.layer5 = {
    "aBC---x",
    "A121111",
    "-12d---",
    "-144---",
    "-155---",
    "-144---",
    "v12d---",
}
Module.layer6 = {
    "axyx--y",
    "w211111",
    "821a---",
    "8211---",
    "8211---",
    "8211---",
    "v21a---",
}
Module.layer7 = {
    "adddddd",
    "bb11111",
    "bb1adp-",
    "bb11---",
    "bb11---",
    "bb11---",
    "bb1adp-",
}
Module.layer8 = {
    "-------",
    "--bbbbb",
    "--baadp",
    "--bb---",
    "--bb---",
    "--bb---",
    "--baadp",
}
Module.layer9 = {
    "-------",
    "-------",
    "----aad",
    "----b--",
    "----b--",
    "----b--",
    "----aad",
}

Module.origin_block = {0,0,-1} -- x, z, y
Module.base_table = {
    Module.layer0,
    Module.layer1,
    Module.layer2,
    Module.layer3,
    Module.layer4,
    Module.layer5,
    Module.layer6,
    Module.layer7,
    Module.layer8,
    Module.layer9,
}  -- def == default

--Module.doors = {}
Module.doors = nil

-- consuming what function is to be executed

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
