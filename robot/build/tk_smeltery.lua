local deep_copy = require("deep_copy")

--local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local Module = {parent = nil}
Module.name = "tk_smeltery"

Module.dictionary = {
    ["C"] = "Smeltery Controller",

    ["s"] = "Seared Bricks",
    ["f"] = "Seared Faucet",
    ["t"] = "Seared Tank",

    ["d"] = "Smeltery Drain",

    ["b"] = "Casting Basin",
    ["c"] = "Casting Table",
    ["|"] = {"air", "shovel"},
}

-- must always built it in quad 1 or 2, so the drains face north
Module.base_table = {
    {
    "-------",
    "--cb---",
    "--sss--",
    "--sss--",
    "--sss--",
    "-------",
    "-------",
    },
    {
    "--ff---",
    "-sddss-",
    "-s|||s-",
    "-s|||s-",
    "-s|||s-",
    "-ssCts-",
    "-------",
    },
}

Module.origin_block = {0,0,0} -- x, z, y

local one_seven = {1, 7}
local two_six = {2, 6}
Module.segments = { -- This nil assignment schtick makes it so for 99% of the cases 'ipairs' no longer works :) btw
    [1] = {{"-ccc*--", two_six}, {"-ccc---", one_seven}},   -- for height 1 change this
    [2] = {{"-c-c---", two_six}},   -- for height 2 change this
    [3] = nil                       -- ..
}

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(5, 1)

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
