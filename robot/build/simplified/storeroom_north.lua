local deep_copy = require("deep_copy")

local Module = {parent = nil}
Module.name = "simplified.storeroom_north"

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

Module.base_table = {
    {
    "a------",
    "a000-a2",
    "a0000a2",
    "a0000a2",
    "a0000a2",
    "a0000a2",
    "a000-a2",
    },
    {
    "a------",
    "a211111",
    "922a---",
    "9244---",
    "9255---",
    "9244---",
    "a22a---",
    },
    {
    "a------",
    "-121111",
    "-12a3--",
    "-144---",
    "-155---",
    "-144---",
    "a12a3--",
    },
    {
    "a------",
    "a221111",
    "912a---",
    "9144---",
    "9155---",
    "a144---",
    "a12a---",
    },
    {
    "a------",
    "-221111",
    "a12a---",
    "a144---",
    "a155---",
    "-144---",
    "-12a---",
    },
    {
    "a------",
    "a121111",
    "-12a---",
    "-144---",
    "-155---",
    "-144---",
    "-12a---",
    },
    {
    "a-----a",
    "-211111",
    "a21a---",
    "a211---",
    "a211---",
    "a211---",
    "-21a---",
    },
    {
    "a------",
    "aa11111",
    "aa1aa--",
    "aa11---",
    "aa11---",
    "aa11---",
    "aa1aa--",
    },
    {
    "-------",
    "--aaaaa",
    "--aaaa-",
    "--aa---",
    "--aa---",
    "--aa---",
    "--aaaa-",
    },
    {
    "-------",
    "-------",
    "----aaa",
    "----a--",
    "----a--",
    "----a--",
    "----aaa",
    },
}

Module.origin_block = {0,0,-1} -- x, z, y
Module.doors = nil

-- consuming what function is to be executed

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
