local deep_copy = require("deep_copy")
local comms = require("comms")

local computer = require("computer")
local os = require("os")
local robot = require("robot")
local sides_api = require("sides")
local component = require("component")
local serialize = require("serialization")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local nav_to_build = require("nav_module.nav_to_build")

local inv = require("inventory.inv_obj")

local suck = component.getPrimary("tractor_beam")
local inv_component = component.getPrimary("inventory_controller")

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
    "s*s-s*s",
    "s*s-s*s",
    "-------",
    "s*s-s*s",
    "c+---+c",
    "s*s*s*s",
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
            ledger = MetaLedger:new(),
            last_checked = computer.uptime() - 60 * 21, -- temp thing
            -- last_checked = computer.uptime(),

            fsm = 1,
            in_what_asterisk = 1,
            temp_reg = nil,

            in_building = false
        } -- we only wait 1 minute now
    end,
    function()
        return { state_type = "action" } -- le chop trees
    end,
    function(index)
        local item
        if index == 1 then
            item = MetaItem:new("log", nil, true, nil)
        elseif index == 2 then
            item = MetaItem:new("sapling", nil, true, nil)
        end

        local item_list = {item}
        local new_machine = MetaInventory:newMachine(item_list)
        -- new_machine["state_type"] = "inventory"
        return new_machine
    end,
    function()  -- self_caches might as well be stateless fr fr, but I guess its important in order to know how much
                -- we can fill up our inventory with other stuff
        local new_cache = MetaInventory:newSelfCache()
        return new_cache
    end,
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

local function navigate_to_rel(target_coords, origin_fsm, target_jmp, target_fsm)
    if not nav.is_setup_navigte_rel() then
        nav.setup_navigate_rel(target_coords)
    end

    local jmp_to_func
    local set_fsm = origin_fsm

    local result = nav.navigate_rel()
    if result == 1 then error(comms.robot_send("fatal", "Couldn't rel_move oak_tree_farm, are we stupid? (2)"))
    elseif result == 0 then jmp_to_func = 1 -- hopefully this isn't arbitrary
    elseif result == -1 then -- we've arrived
        set_fsm = target_fsm
        jmp_to_func = target_jmp
    end

    return jmp_to_func, set_fsm
end

local function count_occurence_of_symbol(what_symbol, how_much, where)
    local to_return = nil
    local num_to_return = nil

    local hits = 0
    for _, symbol in ipairs(where) do
        if symbol[1] == what_symbol then hits = hits + 1 end
        if hits == how_much then
            num_to_return = how_much + 1
            local copy = deep_copy.copy(symbol, ipairs)
            table.remove(copy, 1)
            to_return = copy
            break
        end
    end

    return to_return, num_to_return
end

-- TODO: write code that when the chests in the farm get to full transfers things into long-term storage
-- This is: 22 minutes for oak (1x1) farms -- and 11 minutes for spruce (2x2) farms
Module.hooks = {
    function(state, parent, only_check)
        if only_check then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() - state.last_checked < 60 * 22 then return false end
            return true
        end
        -- small debug thing for me :) to do le testing
        local serial = serialize.serialize(state, true)
        print(comms.robot_send("debug", "The state of the current runner function is:\n" .. serial))


        local cur_chunk = nav.get_chunk()
        if not state.in_building and (cur_chunk[1] ~= parent.what_chunk[1] or cur_chunk[1] ~= parent.what_chunk[2]) then
            if nav_to_build.do_move(parent.what_chunk, parent.doors) then
                state.in_building = true -- make it so when we leave building this becomes false (TODO)
            end
            return 1
        end

        -- after these checks and basic movement, we'll now rel move towards the cache (remember that x-move comes first)
        if state.fsm == 1 then

            if not nav.is_setup_navigte_rel() then
                local target_coords, _ = count_occurence_of_symbol('?', 1, parent.s_interface:getSpecialBlocks())
                if target_coords == nil then error(comms.robot_send("fatal", "There is no '?' symbol, oak_tree_farm")) end
                nav.setup_navigate_rel(target_coords)
            end

            local result = nav.navigate_rel()
            if result == 1 then error(comms.robot_send("fatal", "Couldn't rel_move oak_tree_farm, are we stupid?"))
            elseif result == 0 then return 1
            elseif result == -1 then -- we've arrived (face towards the chest and return)
                state.fsm = 2 -- aka, after function no.3 returns, function no.1 will be dealing with the '*' things

                nav.change_orientation("east")
                local check, _ = robot.detect()
                if check then return 4 end

                nav.change_orientation("west")
                check, _ = robot.detect()
                if not check then error(comms.robot_send("fatal", "Couldn't face chest oak_tree_farm")) end
                return 4
            end

        elseif state.fsm == 2 then -- time to look at the *'s
            local what_asterisk = state.in_what_asterisk
            local success, new_what_asterisk = count_occurence_of_symbol('*', what_asterisk, parent.s_interface:getSpecialBlocks())

            if success == nil then -- we have run out of asterisks, time to go to state 4 ('+')
                state.in_what_asterisk = 1
                state.tmp_reg = nil
                state.fsm = 3
                return 1
            end -- else goto asterisk code (change to state 3 -- aka move towards '*')
            state.in_what_asterisk = new_what_asterisk
            state.temp_reg = success
            state.fsm = 21
            return 1

        elseif state.fsm == 21 then

            local target_coords = state.temp_reg
            local jmp_to_func, new_fsm = navigate_to_rel(target_coords, state.fsm, 2, 2)

            state.fsm = new_fsm
            return jmp_to_func

        elseif state.fsm == 3 then
            local what_plus = state.in_what_asterisk -- le reuse of registry
            local success, new_what_plus = count_occurence_of_symbol('+', what_plus, parent.s_interface:getSpecialBlocks())

            if success == nil then -- this means we've run out of +'s (go back to '?' and retrieve our items)
                state.in_what_asterisk = 1 -- prob useless
                state.tmp_reg = nil
                state.fsm = 4
                return 1
            end

            state.in_what_asterisk = new_what_plus
            state.temp_reg = success
            state.fsm = 31
            return 1
        elseif state.fsm == 31 then
            local target_coords = state.temp_reg
            local target_func = 3

            local jmp_to_func, new_fsm = navigate_to_rel(target_coords, state.fsm, target_func, 3)

            if jmp_to_func == target_func then
                nav.change_orientation("east")
                local check, _ = robot.detect()
                if check then goto a_after_turn end

                nav.change_orientation("west")
                check, _ = robot.detect()
                if not check then error(comms.robot_send("fatal", "Couldn't face chest (+) oak_tree_farm")) end
                goto a_after_turn
            end
            ::a_after_turn::

            state.fsm = new_fsm
            return jmp_to_func
        else
            error(comms.robot_send("fatal", "state.fsm went into undefined state"))
        end
    end,
    function() -- only call this once the last_check is x minutes after uptime
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
        suck.suck() -- once again I hope it sucks it to the first slot (fuck, apples?)
        -- IMPORTANT (TODO) CHECK IF APPLES ARE SUCKED SIMULTANEOSLY (we'll need to succcc several (2) slots at once)
        inv.maybe_something_added_to_inv()

        return 1
    end,
    function()
        -- TODO here

        return 1
    end,
    function() -- let's make stateless in a kind of stupid way
        local result = inv_component.getStackInSlot(sides_api.front, 1) -- check first slot
        if result then -- if true we should suck everything dry
            inv.suck_all()
            return 1
        end -- if false we should dump instead

        if not inv.drop_all_possible() then print(comms.robot_send("error", "oak_tree_farm, failed to empty inventory")) end
        return 1
    end
}

return Module
