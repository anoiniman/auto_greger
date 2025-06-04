local deep_copy = require("deep_copy")

local computer = require("computer")
local os = require("os")
local robot = require("robot")
local sides_api = require("sides")
local component = require("component")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local inv = require("inventory.inv_obj")

local suck = component.getPrimary("tractor_beam")

local Module = {parent = nil}
Module.name = "oak_tree_farm"

Module.dictionary = {
    ["s"] = "Oak Sapling",
    ["c"] = "Chest",
    ["d"] = {"any:grass", "name"} -- add code for this
}

-- No torches (so that it can be built in le early game)
-- This more compact / more inteligent design needs to be in a specific quadrant in order to work with
-- the current pathfinding techniques, since we try to go x first, this needs to be either north or south (?)

-- Is this true tho? I think the mirrorwing perserves orientation

-- things defined through * = inventories, and through + = action hooks?
Module.human_readable = {
    {
    "ddddddd",
    "ddddddd",
    "ddddddd",
    "ddddddd",
    "ddddddd",
    "ddddddd",
    "ddddddd",
    },
    {
    "s+s-s+s",
    "s+s-s+s",
    "-------",
    "s+s-s+s",
    "c*---*c",
    "s+s+s+s",
    "-----*c",
    },
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

Module.origin_block = {0,0,-1} -- x, z, y
Module.base_table = Module.human_readable

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

local function down_stroke()
    local err
    local result = true
    while result do
        result, err = nav.debug_move("down", 1)
        if not result and err == "block" then -- attempt to break a possibly placed block, or check if its dirt/grass
            local analysis = geolyzer.simple_return()
            if analysis.harvestTool ~= "shovel" then -- aka, not dirt/grass
                result = robot.swingDown()
                inv.maybe_something_added_to_inv()
            end
        end
    end
end

local function up_stroke() -- add resolution to: we couldn't move up, impossible move
    local err
    local result = true
    while result do
        result = robot.swingUp()
        if not result then break end -- if no break it means tree came to an end

        inv.maybe_something_added_to_inv()
        result, err = nav.debug_move("up", 1)
        if not result and err == "impossible" then -- atempt to place block below us, hopefully it'll stick to leaves
            local could_place = inv.place_block("down", "Oak Wood", "lable", nil)
            if could_place then result = true end -- keep trying to go up
        end
    end
end

-- This is: 22 minutes for oak (1x1) farms -- and 11 minutes for spruce (2x2) farms
Module.hooks = {
    function() -- only call this once the last_check is x minutos after uptime
        -- I think the orientation doesn't change as we mirror, so it's ok to define it in east-west
        local dir = "east"
        nav.change_orientation(dir) -- initial orientation
        for index = 1, 2, 1 do
            local new_dir
            local analysis = geolyzer.simple_return(sides_api.front)
            if geolyzer.sub_compare("log", "naive_contains", analysis) then -- aka ignore if it's still sapling
                inv.equip_tool("axe", 0)

                robot.swing()
                inv.maybe_something_added_to_inv()
                nav.force_forward()

                up_stroke()
                down_stroke() -- then plant sapling

                new_dir = nav.get_opposite_orientation()
                nav.debug_move(new_dir, 1)
                nav.change_orientation(dir)
                inv.place_block("front", "Oak Sapling", "lable", nil)

                dir = new_dir -- smily face
            end
        end -- only then try to suck-up saplings

        os.sleep(6)
        suck.suck() -- once again I hope it sucks it to the first slot
        inv.maybe_something_added_to_inv()
    end
}

return Module
