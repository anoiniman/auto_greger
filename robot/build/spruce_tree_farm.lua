local deep_copy = require("deep_copy")
local comms = require("comms")

local computer = require("computer")
-- local os = require("os")
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
Module.name = "spruce_tree_farm"

Module.dictionary = {
    ["s"] = {"Spruce Sapling", "minecraft:sapling"},
    ["c"] = {"Chest", "minecraft:chest"},
    ["d"] = {"Dirt", "minecraft:dirt"},
    ["y"] = {"Stone Bricks Slab", "minecraft:", "down"},
    ["l"] = {"Cobblestone Slab", "minecraft:", "down"},
    ["k"] = {"Cobblestone", "minecraft:cobblestone"},
    ["t"] = {"Torch", "minecraft:torch", "down"},
}

-- No torches (so that it can be built in le early game)
-- This more compact / more inteligent design needs to be in a specific quadrant in order to work with
-- the current pathfinding techniques, since we try to go x first, this needs to be either north or south (?)

-- Is this true tho? I think the mirrorwing perserves orientation

-- things defined through * = inventories, and through + = action hooks?
Module.human_readable = {
    {
    "klllllk",
    "lddlyyl",
    "lddlyyl",
    "lllklll",
    "lyylddl",
    "lyylddl",
    "klllllk",
    },
    {
    "t-----t",
    "-dd--+c",
    "-dd--+c",
    "---t---",
    "c+--dd-",
    "c+--dd-",
    "tc+---t",
    },
    {
    "-------",
    "-ss----",
    "-ss----",
    "-*-----",
    "----ss-",
    "----ss-",
    "----*--",
    },
}

Module.origin_block = {0,0,-2} -- x, z, y
Module.base_table = Module.human_readable

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(4, 1)

function Module:new()
    return deep_copy.copy(self, pairs)
end

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function() -- general state
        return {ledger = MetaLedger:new(), last_checked = computer.uptime()}
    end,
    function(index)
        local item
        if index == 1 or index == 3 then
            item = MetaItem:new(nil, "Spruce Wood", true, nil)
        elseif index == 2 or index == 4 then
            item = MetaItem:new(nil, "Spruce Sapling", true, nil)
        elseif index == 5 then
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

local function up_stroke() -- add resolution to: we couldn't move up, impossible move
    local result

    local climb_amount = 0
    local err_watch_dog = 0
    while true do
        inv.equip_tool("axe", 0)
        if err_watch_dog > 12 then
            comms.robot_send("error", "It seems we've gotten stuck farming a spruce tree")
            return false, climb_amount
        end

        local something_above = robot.swingUp()
        if not something_above then break end
        inv.maybe_something_added_to_inv()

        result = nav.debug_move("up", 1)
        if not result then err_watch_dog = err_watch_dog + 1
        else climb_amount = climb_amount + 1 end
    end

    return true, climb_amount
end

local function down_stroke(climbed_amount)
    -- just in case of uneven tree
    local _, further_climbed = up_stroke()
    climbed_amount = climbed_amount + further_climbed

    local result
    local err_watch_dog = 0
    while climbed_amount > 0 do
        inv.equip_tool("axe", 0)
        if err_watch_dog > 12 then
            comms.robot_send("error", "It seems we've gotten stuck farming a spruce tree")
            return false
        end

        robot.swingDown()
        inv.maybe_something_added_to_inv("Spruce Wood", "any:log")
        result = nav.debug_move("down", 1)
        if not result then err_watch_dog = err_watch_dog + 1 end
    end
    -- Final checks
    while true do
        local analysis = geolyzer.simple_return()
        if analysis.harvestTool == "shovel" then break end
        -- else

        robot.swingDown()
        inv.maybe_something_added_to_inv("Spruce Wood", "any:log")
        local result = nav.debug_move("down", 1)
        if not result then break end
    end

    return true
end

local function go_next()
    for index = 1, 3, 1 do
        local _, what_detected = robot.detect()
        if what_detected == "solid" then break end

        nav.rotate_right()
    end
    robot.swing()
    inv.maybe_something_added_to_inv("Spruce Wood", "any:log")
    local result, _ = nav.force_forward()
    if not result then print(comms.robot_send("error", "We entered a strange state in spruce farming!")) end
end

-- This is: 22 minutes for oak (1x1) farms -- and 11 minutes for spruce (2x2) farms
Module.hooks = {
    -- takes control in between the specific * and + functions
    -- if check is true return true on start conditions being true, otherwise execute main code
    function(state, only_check)
        if computer.uptime() - state.last_checked < 60 * 11 then return false end
        if only_check then return true end
        -- TODO (the rest)
    end,
    function() -- only call this once the last_check is x minutos after uptime

        local analysis = geolyzer.simple_return(sides_api.front)
        if not geolyzer.sub_compare("log", "naive_contains", analysis) then
            return -- early return
        end
        inv.equip_tool("axe", 0)

        robot.swing()
        inv.maybe_something_added_to_inv("Spruce Wood", "any:log")
        nav.force_forward()

        local _
        local latest_climb = 0
        -- local dir = nav.get_orientation() -- relies on our current movement algorithm which moves on the z-axis after the x-axis
        for index = 1, 4, 1 do
            if index % 2 == 1 then
                _, latest_climb = up_stroke()
            else
                _ = down_stroke(latest_climb)
            end
            go_next()
        end -- only then try to suck-up saplings

        local do_suck = true
        while do_suck do
            do_suck = suck.suck() -- once again I hope it sucks it to the first slot
            inv.maybe_something_added_to_inv("Spruce Sapling", "any:sapling")
        end
    end
}

return Module
