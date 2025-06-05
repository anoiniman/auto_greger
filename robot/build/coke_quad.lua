local deep_copy = require("deep_copy")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")
local general_functions = require("build.general_functions")

local Module = {parent = nil}
Module.name = "coke_quad"

Module.dictionary = {
    ["c"] = "Coke Oven Brick",  -- tmp name, I need to geolyze in game first or whatever
                                -- this needs to be distinguited from the brick from somehow
                                -- (this is the block form)
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
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(6,2)

-- consuming what function is to be executed
-- "Which Iteration" <-> "Which Height/Level"
function Module:iter()
    return general_functions.iter(self.base_table, 3, self.segments)
end

function Module:new()
    return deep_copy.copy(self, pairs)
end

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return MetaLedger:new()
    end,
    function() -- anonymous function, hopefully
        local input_items = {
            MetaItem:new("log", nil, true, "Charcoal" ),
            MetaItem:new(nil, "Coal", false, "Coal Coke"),
            MetaItem:new(nil, "Block of Coal", false, "Block of Coal Coke")
        }

        local new_machine = MetaInventory:newMachine(input_items)
        new_machine["state_type"] = "inventory"
        return new_machine
    end
}

-- TODO (low priority) add auto-clear creosote oil when abcd
-- time calculation assuming that each log takes 3000 ticks (150 seconds) to turn into charcoal
Module.hooks = { -- TODO this
    function()

    end,
    function()

    end
}

return Module
