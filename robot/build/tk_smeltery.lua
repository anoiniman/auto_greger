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
    "---b---",
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

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(1, 1)

function Module:new()
    return deep_copy.copy(self, pairs)
end

return Module
