local deep_copy = require("deep_copy")
local comms = require("comms")

-- local serialize = require("serialization")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

-- local general_functions = require("build.general_functions")

local Module = {parent = nil}
Module.name = "sp_storeroom"

Module.dictionary = {
    c = {"Chest", "minecraft:chest"},
    p = {"nil", "any:plank"},
    l = {"nil", "any:log"},
}

-- (*) stand for permanent storage
Module.base_table = {
    {
    "ppppppp",
    "ppppppp",
    "ppppppp",
    "ppppppp",
    "ppppppp",
    "ppppppp",
    "ppppppp",
    },
    {
    "--l-l--",
    "l-----l",
    "cc*-*cc", -- 1,2
    "pp---pp",
    "cc*-*cc", -- 3,4
    "pp*-*pp",
    "l-c-c-l", -- 5,6 (small)
    },
    {
    "--l-l--",
    "-------",
    "-------",
    "cc*-*cc", -- 7,8
    "-------",
    "cc*-*cc", -- 9,10
    "l-----l",
    },
    {
    "--l-l--",
    "l-----l",
    "-------",
    "-------",
    "-------",
    "-------",
    "l-----l",
    },
    {
    "--l-l--",
    "lllllll",
    "l-l-l-l",
    "--l-l--",
    "--l-l--",
    "l-l-l-l",
    "lllllll",
    },
}

Module.origin_block = {0,0,-1} -- x, z, y

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(4, 1)

function Module:new()
    return deep_copy.copy(self, pairs)
end

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return {
            --last_checked = computer.uptime()
        }
    end,
    function(parent)
        local bd_table = {
            -- Building Material
            MetaItem:new("any:log", nil),
            MetaItem:new("any:building"),
            MetaItem:new("any:plank"),
            MetaItem:new("any:pretty_build"),
            MetaItem:new("any:grass"),
            -- Tools
            MetaItem:new("tool:sword", nil),
            MetaItem:new("tool:pickaxe", nil),
            MetaItem:new("tool:axe", nil),
            MetaItem:new("tool:shovel", nil),
        }
        local ore_table = {
            MetaItem:new("gregtech:raw_ore", nil),
            MetaItem:new("gregtech:crushed_ore", nil),
            MetaItem:new("gregtech:impure_dust", nil),
            MetaItem:new("gregtech:done_dust", nil),
        }

        local ingots_n_shit_table = {
            MetaItem:new("any:ingot", nil),
        }

        local material_b_crafting_table = {
            MetaItem:new("any:intermediate_material"),
            MetaItem:new("any:basic_crafting"),
        }

        local st_table = {
            MetaInventory:newLongTermStorage({MetaItem:new("any:any", nil, false, nil)}, parent, "*", 1, "double_chest"),
            MetaInventory:newLongTermStorage({MetaItem:new("any:any", nil, false, nil)}, parent, "*", 2, "double_chest"),
            MetaInventory:newLongTermStorage(bd_table, parent, "*", 3, "double_chest"),
            MetaInventory:newLongTermStorage(bd_table, parent, "*", 4, "double_chest"),

            MetaInventory:newLongTermStorage(material_b_crafting_table, parent, "*", 5, "double_chest"),
            MetaInventory:newLongTermStorage(material_b_crafting_table, parent, "*", 6, "double_chest"),

            MetaInventory:newLongTermStorage(ore_table, parent, "*", 7, "double_chest"),
            MetaInventory:newLongTermStorage(ore_table, parent, "*", 8, "double_chest"),

            MetaInventory:newLongTermStorage(ingots_n_shit_table, parent, "*", 9, "double_chest"),
            MetaInventory:newLongTermStorage({MetaItem:new("gregtech:generic")}, parent, "*", 10, "double_chest"),
        }

        return {st_table, 1}
    end,
}

Module.hooks = {
    function()
        print(comms.send_unexpected())
        return nil
    end,
    function()
        print(comms.send_unexpected())
        return nil
    end,
}

return Module
