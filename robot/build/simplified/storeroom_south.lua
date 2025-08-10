local deep_copy = require("deep_copy")

local meta_door = require("build.MetaBuild.MetaDoorInfo")

local Module = {parent = nil}
Module.name = "simplified/storeroom_south"

Module.dictionary = {
    ["0"] = "Quarried Brick",
    ["1"] = "Birch Wood Planks",
    ["2"] = "Spruce Wood Planks",
    ["3"] = "Torch",

    ["4"] = "Chest",
    ["5"] = "Trap Chest",

    ["7"] = {"Birch Wood Slab", "down"},
    ["e"] = {"Spruce Wood Slab", "down"},
    ["9"] = {"Stone Bricks Slab", "down"},
    ["a"] = {"Spruce Wood", "up"},
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.base_table = {
    {
    "a000-a2",
    "a0000a2",
    "a0000a2",
    "a0000a2",
    "a000-a2",
    "a000002",
    "a------",
    },
    {
    "a22a---",
    "-255---",
    "-244---",
    "-255---",
    "-22a---",
    "a2111--",
    "a------",
    },
    {
    "a12a3--",
    "-155---",
    "-144---",
    "-155---",
    "-12a---",
    "-1111--",
    "a------",
    },
    {
    "a12a---",
    "a155---",
    "9144---",
    "9155---",
    "912a---",
    "a1111--",
    "a------",
    },
    {
    "-12a---",
    "-155---",
    "a144---",
    "a155---",
    "a12a---",
    "-11111-",
    "a------",
    },
    {
    "-12a---",
    "-155---",
    "-144---",
    "-155---",
    "-12a---",
    "a111111",
    "a------",
    },
    {
    "-21a---",
    "a211---",
    "a211---",
    "a211---",
    "a21a---",
    "-211111",
    "a------",
    },
    {
    "aa1aa--",
    "aa11---",
    "aa11---",
    "aa11---",
    "aa1aa--",
    "aa111--",
    "aaaaa--",
    },
    {
    "--aaaa-",
    "--aa---",
    "--aa---",
    "--aa---",
    "--aaaa-",
    "--aa1--",
    "--aaad-",
    },
    {
    "----aaa",
    "----a--",
    "----a--",
    "----a--",
    "----aaa",
    "----a--",
    "----aad",
    }
}

Module.origin_block = {0,0,-1} -- x, z, y

Module.doors = {}
Module.doors[1] = meta_door:new()
Module.doors[1]:doorX(6,2)

-- consuming what function is to be executed

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
