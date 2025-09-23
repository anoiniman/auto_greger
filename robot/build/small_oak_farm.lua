------- /usr/lib/ ----------
local deep_copy = require("deep_copy")
local comms = require("comms")

-------- Open OS ------------
local computer = require("computer")
local os = require("os")
local keyboard = require("keyboard")

local robot = require("robot")
local sides_api = require("sides")
local component = require("component")

local serialize = require("serialization")

-------- Other ------------
local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local generic_hooks = require("build.generic_hooks")

local inv = require("inventory.inv_obj")


---------------
local suck = component.getPrimary("tractor_beam")
local inv_component = component.getPrimary("inventory_controller")

local Module = {parent = nil}
Module.name = "small_oak_farm"

Module.dictionary = {
    ["s"] = {"Oak Sapling", "minecraft:sapling"},
    ["c"] = {"Chest", "minecraft:chest"},
    ["d"] = {"nil", "any:grass"},
    ["|"] = {"air", "shovel"},
}

-- No torches (so that it can be built in le early game)
-- This more compact / more inteligent design needs to be in a specific quadrant in order to work with
-- the current pathfinding techniques, since we try to go x first, this needs to be either north or south (?)

-- Is this true tho? I think the mirrorwing perserves orientation

-- things defined through * = inventories, and through + = action hooks?
Module.human_readable = {
    {
    "-------",
    "-d---d-",
    "-------",
    "-------",
    "-------",
    "-d---d-",
    "-------",
    },
    {
    "|||||||",
    "|s*|*s|",
    "|||||||",
    "|||||||",
    "|||||||",
    "|s*|*s|",
    "|||||||",
    },
}

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
            -- last_checked = computer.uptime() - 60 * 23, -- temp thing
            last_checked = computer.uptime(),

            fsm = 1,
            in_what_asterisk = 1,
            temp_reg = nil,

            in_building = false
        } -- we only wait 1 minute now
    end,
    function()
        return { state_type = "action" } -- le chop trees
    end,
    --[[function(parent)
        local storage_table = {
            MetaInventory:newStorage(MetaItem:new(nil, "Oak Wood", true, nil), parent, '+', 1),
            MetaInventory:newStorage(MetaItem:new(nil, "Oak Sapling", true, nil), parent, '+', 2)
        }
        return {storage_table, 1}
    end,
    function()
        local new_cache = MetaInventory:newSelfCache()
        return new_cache
    end,--]]
}

local lable_hint = "Oak Wood"
local name_hint = "any:log"
local function something_added()
    inv.maybe_something_added_to_inv(lable_hint, name_hint)
end

local function down_stroke()
    local err
    local result = true
    while result do
        if keyboard.isKeyDown(keyboard.keys.q) then
            print("force_stoped downstroke")
            break
        end


        result, err = nav.debug_move("down", 1)
        if not result and err == "solid" then -- attempt to break a possibly placed block, or check if its dirt/grass
            local analysis = geolyzer.simple_return()
            if analysis.harvestTool ~= "shovel" then -- aka, not dirt/grass
                inv.smart_swing("axe", "down", 0, something_added)
            end
        end
    end
end

local function up_stroke() -- add resolution to: we couldn't move up, impossible move
    local err
    local result = true
    while result do
        if keyboard.isKeyDown(keyboard.keys.q) then
            print("force_stoped upstroke")
            break
        end


        result = inv.smart_swing("axe", "up", 0, something_added)
        if not result then break end -- if no break it means tree came to an end

        result, err = nav.debug_move("up", 1)
        if not result and err == "impossible" then -- atempt to place block below us, hopefully it'll stick to leaves
            local could_place = inv.place_block("down", "Oak Wood", "lable", nil)
            if could_place then result = true end -- keep trying to go up
        end
    end
end


-- This is: 22 minutes for oak (1x1) farms -- and 11 minutes for spruce (2x2) farms
Module.hooks = {
    -- flag determines if we are running a check or a determinate logistic action
    -- (i.e -> picking up stuff from the output chest into the robot, or moving stuff to the input chest etc.)

    -- luacheck: no unused args
    function(state, parent, flag, quantity_goal, state_table)
        if flag == "only_check" then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() - state.last_checked < 60 * 16 then return "wait" end -- prev was 60 * 22

            return "all_good"
        elseif flag ~= "raw_usage" then
            error(comms.robot_send("fatal", "oak_farm -- todo (3)"))
        end
        -- small debug thing for me :) to do le testing
        local serial = serialize.serialize(state, true)
        print(comms.robot_send("debug", "The state of the current runner function is:\n" .. serial))

        local go_next = generic_hooks.std_hook1(state, parent, flag, Module.state_init[1], "oak_tree_farm")
        if go_next == nil or go_next > 2 then
            state.fsm = 1
            state.in_what_asterisk = 1
            state.temp_reg = nil
            state.in_building = false

            return nil
        end
        return go_next
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
                inv.smart_swing("axe", "front", 0, something_added)
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
}

return Module
