local deep_copy = require("deep_copy")
local computer = require("computer")
local robot = require("robot")
local sides_api = require("sides")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")

local Module = {parent = nil}
Module.name = "oak_tree_farm"

Module.dictionary = {
    ["s"] = {"", "sapling", "naive_contains"}, -- check our instruction builder is smart enough for this
    ["c"] = "Chest"
}

-- No torches (so that it can be built in le early game)
-- This more compact / more inteligent design needs to be in a specific quadrant in order to work with
-- the current pathfinding techniques, since we try to go x first, this needs to be either north or south (?)

-- Is this true tho? I think the mirrorwing perserves orientation

-- things defined through * = inventories, and through + = action hooks?
Module.human_readable = {
    "s+s-s+s",
    "s+s-s+s",
    "-------",
    "s+s-s+s",
    "c*---*c",
    "s+s+s+s",
    "-----*c",
}
--[[Module.human_readable = {
    "s+s-s+s",
    "s+sts+s",
    "t-----t",
    "s+s-s+s",
    "c*---*c",
    "s+s+s+s",
    "t----*c",
}--]]

Module.origin_block = {0,0,0} -- x, z, y
Module.base_table = { Module.human_readable }

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(4, 1)

function Module:new()
    return deep_copy.copy(self, pairs)
end

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return {ledger = MetaLedger:new(), last_checked = computer.uptime()}
    end,
    function(index)
        local item
        if index == 1 then
            item = MetaItem:new("log", nil, true, nil)
        elseif index == 2 then
            item = MetaItem:new("sapling", nil, true, nil)
        elseif index == 3 then
            item = MetaItem:new("any:cache", nil, true, nil)
        end

        local item_list = {item}
        local new_machine = MetaInventory:newMachine(item_list)
        new_machine["state_type"] = "inventory"
        return new_machine
    end,
    function()
        return { state_type = "action" }
    end
}

-- TODO all of this
local function up_stroke() -- add resolution to: we couldn't move up, impossible move
    local result = true 
    while result and move do
        result = robot.swingUp()
        inv.maybe_something_added_to_inv()
        nav.debug_move("up", 1) 
    end
end

-- This is: 22 minutes for oak (1x1) farms -- and 11 minutes for spruce (2x2) farms
Module.hooks = {
    function() -- only call this once the last_check is x minutos after uptime
        -- I think the orientation doesn't change as we mirror, so it's ok to define it in east-west
        nav.change_orientation("east")
        for index = 1, 2, 1 do
            local analysis = geolyzer.simple_return(sides_api.front)
            if geolyzer.sub_compare("log", "naive_contains", analysis) then -- aka ignore if it's still sapling
                inv.equip_tool("axe", 0)

                robot.swing()
                inv.maybe_something_added_to_inv()
                nav.force_forward() 

            end
            nav.change_orientation("west")
        end
    end
}

return Module
