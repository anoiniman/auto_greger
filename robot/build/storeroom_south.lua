-- Made by Rine0333

local deep_copy = require("deep_copy")

local meta_door = require("build.MetaBuild.MetaDoorInfo")
local general_functions = require("build.general_functions")

local Module = {parent = nil}
Module.name = "chest.storeroomSouth"

Module.dictionary = {
    ["0"] = "Quarried Brick"
    ["1"] = "Birch Wood Planks",
    ["2"] = "Spruce Wood Planks",
    ["3"] = "Torch"
    -- Chest
    ["4"] = {"Chest", "north"},
    ["5"] = {"Trap Chest", "north"},
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
    {
    "b000db2",
    "b0000b2",
    "b0000b2",
    "b0000b2",
    "b000db2",
    "b000002",
    "adddddd",
    }
}
Module.layer1 = {
    {
    "A22d---",
    "9255---",
    "9244---",
    "9255---",
    "922dt--",
    "z2111l-",
    "aBC8yB-",
    }
}
Module.layer2 = {
    {
    "A12d3--",
    "-155---",
    "-144---",
    "-155---",
    "-12dp--",
    "v1111--",
    "ax-----",
    }
}
Module.layer3 = {
    {
    "z12d---",
    "A155---",
    "9144---",
    "9155---",
    "912dt--",
    "z1111h-",
    "aBAACx-",
    }
}
Module.layer4 = {
    {
    "v12d---",
    "w155---",
    "8144---",
    "8155---",
    "812dp--",
    "v11111h",
    "axAAAAx",
    }
}
Module.layer5 = {
    {
    "w12d---",
    "-155---",
    "-144---",
    "-155---",
    "-12dteu",
    "z111111",
    "aB99999",
    }
}
Module.layer6 = {
    {
    "w21a---",
    "8211---",
    "8211---",
    "8211---",
    "821apte",
    "v211111",
    "ax88888",
    }
}
Module.layer7 = {
    {
    "bb1adp-",
    "bb11---",
    "bb11---",
    "bb11---",
    "bb1adp-",
    "bb11199",
    "adddd--",
    }
}
Module.layer8 = {
    {
    "--baadp",
    "--bb---",
    "--bb---",
    "--bb---",
    "--baadp",
    "--ba1--",
    "--aaad-",
    }
}
Module.layer9 = {
    {
    "----aad",
    "----b--",
    "----b--",
    "----b--",
    "----aad",
    "----a88",
    "----add",
    }
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
} -- def == default

Module.doors = {}
Module.doors[1] = meta_door:new()
Module.doors[1]:doorX(6,2)

-- consuming what function is to be executed

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Modulea
