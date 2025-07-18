local deep_copy = require("deep_copy")
local comms = require("comms")

local computer = require("computer")
local os = require("os")
local robot = require("robot")
local sides_api = require("sides")
local component = require("component")
local serialize = require("serialization")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local generic_hooks = require("build.generic_hooks")

local inv = require("inventory.inv_obj")

local suck = component.getPrimary("tractor_beam")
local inv_component = component.getPrimary("inventory_controller")

local Module = {parent = nil}
Module.name = "oak_tree_farm"

Module.dictionary = {
    ["s"] = {"Oak Sapling", "minecraft:sapling"},
    ["c"] = {"Chest", "minecraft:chest"},
    ["d"] = {"nil", "any:grass", "name"} -- TODO add code for this
}

-- No torches (so that it can be built in le early game)
-- This more compact / more inteligent design needs to be in a specific quadrant in order to work with
-- the current pathfinding techniques, since we try to go x first, this needs to be either north or south (?)

-- Is this true tho? I think the mirrorwing perserves orientation

-- things defined through * = inventories, and through + = action hooks?
Module.human_readable = {
    {
    "d-d-d-d",
    "d-d-d-d",
    "-------",
    "d-d-d-d",
    "d-----d",
    "d-d-d-d",
    "------d",
    },
    {
    "s*s-s*s",
    "s*s-s*s",
    "-------",
    "s*s-s*s",
    "c+---+c",
    "s*s-s*s",
    "-----?c",
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

--Module.origin_block = {0,0,-1} -- x, z, y
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
        return {
            last_checked = computer.uptime() - 60 * 23, -- temp thing
            -- last_checked = computer.uptime(),

            fsm = 1,
            in_what_asterisk = 1,
            temp_reg = nil,

            in_building = false
        } -- we only wait 1 minute now
    end,
    function()
        -- return { state_type = "action" } -- le chop trees
        return nil
    end,
    function(parent)
        local storage_table = {
            MetaInventory:newStorage(MetaItem:new(nil, "Oak Wood", true, nil), parent, '+', 1),
            MetaInventory:newStorage(MetaItem:new(nil, "Oak Sapling", true, nil), parent, '+', 2)
        }
        return {storage_table, 1}
    end,
    function()
        local new_cache = MetaInventory:newSelfCache()
        return new_cache
    end,
}

local lable_hint = "Oak Wood"
local name_hint = "any:log"

local function down_stroke()
    local err
    local result = true
    while result do
        result, err = nav.debug_move("down", 1)
        if not result and err == "block" then -- attempt to break a possibly placed block, or check if its dirt/grass
            local analysis = geolyzer.simple_return()
            if analysis.harvestTool ~= "shovel" then -- aka, not dirt/grass
                result = robot.swingDown()
                inv.maybe_something_added_to_inv(lable_hint, name_hint)
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

        inv.maybe_something_added_to_inv(lable_hint, name_hint)
        result, err = nav.debug_move("up", 1)
        if not result and err == "impossible" then -- atempt to place block below us, hopefully it'll stick to leaves
            local could_place = inv.place_block("down", "Oak Wood", "lable", nil)
            if could_place then result = true end -- keep trying to go up
        end
    end
end


-- TODO: write code that when the chests in the farm get to full transfers things into long-term storage
-- This is: 22 minutes for oak (1x1) farms -- and 11 minutes for spruce (2x2) farms
Module.hooks = {
    -- flag determines if we are running a check or a determinate logistic action
    -- (i.e -> picking up stuff from the output chest into the robot, or moving stuff to the input chest etc.)

    -- luacheck: no unused args
    function(state, parent, flag, quantity_goal, state_table)
        if flag == "only_check" then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() - state.last_checked < 60 * 22 then return "wait" end

            return "all_good"
        elseif flag ~=  "raw_usage" and flag ~= "no_store" then
            error(comms.robot_send("fatal", "oak_farm -- todo (3)"))
        end
        -- small debug thing for me :) to do le testing
        local serial = serialize.serialize(state, true)
        print(comms.robot_send("debug", "The state of the current runner function is:\n" .. serial))

        return generic_hooks.std_hook1(state, parent, flag, Module.state_init[1], "oak_tree_farm")
    end,
    function() -- only call this once the last_check is x minutes after uptime
        -- I think the orientation doesn't change as we mirror, so it's ok to define it in east-west
        local dir = "east" -- initial orientation
        for index = 1, 2, 1 do
            local old_dir = dir
            local new_dir
            nav.change_orientation(dir)

            local analysis = geolyzer.simple_return(sides_api.front)

            if geolyzer.sub_compare("log", "naive_contains", analysis) then -- aka ignore if it's still sapling
                inv.equip_tool("axe", 0)

                robot.swing()
                inv.maybe_something_added_to_inv(lable_hint, name_hint)
                nav.force_forward()

                up_stroke()
                down_stroke() -- then plant sapling

                new_dir = nav.get_opposite_orientation() -- something goes wrong here, it needs to spin around again
                nav.debug_move(new_dir, 1)
                nav.change_orientation(dir)
                inv.place_block("front", "Oak Sapling", "lable", nil)

                dir = new_dir -- smily face
            end
            if old_dir == dir then -- makes sure we spin around even in failure
                dir = nav.get_opposite_orientation()
            end

        end -- only then try to suck-up saplings

        os.sleep(6)
        local result = true
        while result do
            result = suck.suck()
        end

        inv.maybe_something_added_to_inv("Apple", nil)
        inv.maybe_something_added_to_inv(nil, "any:sapling")
        -- move in the z axis to not collide with the old trees
        nav.debug_move("north", 2) -- hopefully doesn't make us change chunk, and if it does it handles it gracefully

        return 1
    end,
    -- TODO some minor branches
    function(state) -- Simple dump what matches function [I think the chests are determinitstic?]
        local storage_table = state[1]; local cur_index = state[2]
        local cur_storage = storage_table[cur_index]

        for _, item_def in cur_storage:itemDefIter() do
            inv.dump_only_named(item_def.lable, item_def.name, cur_storage.ledger)
        end
        return 1
    end,
    function(ledger)
        local le_item = inv_component.getStackInSlot(sides_api.front, 1) -- check first slot
        if le_item ~= nil then -- we should suck everything dry
            inv.suck_all(ledger)
            return 1
        end -- if false we should dump instead

        if not inv.dump_all_possible(ledger) then print(comms.robot_send("error", "oak_tree_farm, failed to empty inventory")) end
        return 1
    end
}

return Module
