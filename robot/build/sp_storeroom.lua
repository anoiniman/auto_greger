local deep_copy = require("deep_copy")
local comms = require("comms")

local serialize = require("serialization")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local general_functions = require("build.general_functions")

local Module = {parent = nil}
Module.name = "sp_storeroom"

Module.dictionary = {
    c = {"Chest", "minecraft:chest"},
    p = {"nil", "any:plank"},
    l = {"nil", "any:log"} 
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
    "pp*-*pp", -- 5,6 (small)
    "l-c-c-l",
    },
    {
    "--l-l--",
    "l-----l",
    "-------",
    "cc*-*cc", -- 7,8
    "-------",
    "cc*-*cc", -- 9,10
    "l-----l",
    },
    {
    "--l-l--",
    "l-----l",
    "l-----l",
    "-------",
    "l-----l",
    "-------",
    "l-----l",
    },
    {
    "--l-l--",
    "lllllll",
    "--l-l--",
    "l-l-l-l",
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
        -- TODO change definitions
        local misc_chest = MetaInventory:newLongTermStorage({MetaItem:new("any:any", nil, false, nil)}, parent, "*", 1, "double_chest")

        local bd_table = {
            MetaItem:new("any:log", nil),
            MetaItem:new("any:building"),
            MetaItem:new("any:plank"),
            MetaItem:new("any:pretty_build"),
        }
        local st_table = {misc_chest}

        table.insert(st_table, MetaInventory:newLongTermStorage(bd_table, parent, "*", 2, "double_chest"))
        table.insert(st_table, MetaInventory:newLongTermStorage(bd_table, parent, "*", 3, "double_chest"))

        local ore_table = { MetaItem:new("gregtech:raw_ore", nil) }
        table.insert(st_table, MetaInventory:newLongTermStorage(ore_table, parent, "*", 4, "double_chest"))

        local material_b_crafting_table = {MetaItem:new("any:intermediate_material"), MetaItem:new("any:basic_crafting")}
        table.insert(st_table, MetaInventory:newLongTermStorage(material_b_crafting_table, parent, "*", 5, "double_chest"))

        return {st_table, 1}
    end,
    function(parent)
        local dump_chest = MetaInventory:newSelfCache()
        return dump_chest
    end,
}

Module.hooks = {
    function()
        print(comms.send_unexpected())
        return nil
    end,
    function(state)
        print(comms.send_unexpected())
        return nil
    end,
    general_functions.use_cache
}

return Module
