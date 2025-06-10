local deep_copy = require("deep_copy")
local comms = require("comms")

local computer = require("computer")
local serialize = require("serialization")
local robot = require("robot")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
--local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")

local nav = require("nav_module.nav_obj")
local inv = require("inventory.inv_obj")

local general_functions = require("build.general_functions")
local generic_hooks = require("build.generic_hooks")

local Module = {parent = nil}
Module.name = "coke_quad"

Module.dictionary = {
    ["c"] = {"Coke Oven Brick", "Railcraft:machine.alpha" }, -- if this doesn't work then ouch
    ["d"] = {"Chest", "minecraft:chest"}
}

-- Orientation is assumed for sector 3 (x:-1,z:-1)
-- create rotation function somewhere
Module.human_readable = {
    "-ccc---",
    "-ccc---",
    "-ccc---",
    "-------",
    "-ccc---",
    "-ccc---",
    "-ccc---",
}

Module.origin_block = {0,0,0} -- x, z, y
Module.base_table = { def = Module.human_readable, [1] = Module.human_readable } -- def == default

local one_seven = {1, 7}
local two_six = {2, 6}
Module.segments = { -- This nil assignment schtick makes it so for 99% of the cases 'ipairs' no longer works :) btw
    [1] = {{"-ccc*--", two_six}, {"-ccc-+d", one_seven}},   -- for height 1 change this
    [2] = {{"-c-c---", two_six}},   -- for height 2 change this
    [3] = nil                       -- ..
}

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(5, 1)

-- consuming what function is to be executed
-- "Which Iteration" <-> "Which Height/Level"
function Module:iter()
    return general_functions.iter(self.base_table, 3, self.segments)
end

function Module:new()
    return deep_copy.copy(self, pairs)
end

local input_items = {
    MetaItem:new("log", nil, true, "Charcoal" ),
    MetaItem:new(nil, "Coal", false, "Coal Coke"),
    MetaItem:new(nil, "Block of Coal", false, "Block of Coal Coke")
}


-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return {
            --last_checked = computer.uptime()
            last_checked = computer.uptime() - 1000, -- temp (s)-

            fsm = 1,
            in_what_asterisk = 1,
            temp_reg = nil,

            in_building = false
        }
    end,
    function(parent) -- anonymous function, hopefully
        local new_machine = MetaInventory:newMachine(input_items, parent)
        -- new_machine["state_type"] = "inventory"
        return new_machine
    end,
    function(parent)
        local output_items = {
            MetaItem:new("Chracoal", nil, true, nil),
            MetaItem:new(nil, "Coal Coke", false, nil),
            MetaItem:new(nil, "Block of Coal Coke", false, nil)
        }

        local storage_table = {
            MetaInventory:newStorage(input_items, parent),
            MetaInventory:newStorage(output_items, parent)
        }
        return {storage_table, 1}
    end
}

-- TODO (low priority) add auto-clear creosote oil when abcd
-- time calculation assuming that each log takes 1800 ticks (90 seconds) to turn into charcoal
Module.hooks = { -- TODO this
    function(state, parent, flag, quantity_goal, state_table)
        if flag == "only_check" then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() - state.last_checked < 920 then return "wait" end
            -- TODO generisize this harder, in the sense, that'll look specifically for what the caller is trying to
            -- check, not just hardcoded "Oak Log"

            local storage_table = state_table[3][1]
            local input_storage = storage_table[1]
            local how_many_log = input_storage.ledger:tryDetermineHowMany("log", nil, "expand_bucket")
            if how_many_log < quantity_goal then
                --comms.robot_send("debug", "no_resources coke_quad: how many log is:" .. how_many_log)
                --comms.robot_send("debug", "no_resources coke_quad: needed is:" .. quantity_goal)
                return "no_resources"
            end -- else

            return "all_good"
        elseif flag ~=  "raw_usage" and flag ~= "no_store" then
            error(comms.robot_send("fatal", "coke_quad -- todo (3)"))
        end
        local serial = serialize.serialize(state, true)
        print(comms.robot_send("debug", "The state of the current runner function is:\n" .. serial))

        return generic_hooks.std_hook1(state, parent, flag, Module.state_init[1], "coke_quad")
    end,
    function()
        nav.change_orientation("east")
        local check, _ = robot.detect()
        if check then goto after_turn end

        nav.change_orientation("west")
        check, _ = robot.detect()
        if check then goto after_turn end

        ::after_turn::
        -- let us hope this is good enough:
        inv.dump_all_named("log", nil, "naive_contains", 0) -- should we do it for every item definition? Idk (TODO) for now ok
        return 1
    end,
    function(state)
        local storage_table = state[1]; local index = state[2]
        local cur_storage = storage_table[index]

        for _, item_def in cur_storage:itemDefIter() do
            if item_def.lable ~= nil and item_def.name == nil then
                if index == 1 then -- dependedent on how we've defined our storage_table in state_init
                    inv.dump_all_named(item_def.name, item_def.lable, "lable", cur_storage.ledger)
                end
            elseif item_def.lable == nil and item_def.name ~= nil then
                print("skip a") -- what'll happen when we try to store logs but we'll just skip
            elseif item_def.lable ~= nil and item_def.name ~= nil then
                print("skip b")
            else -- surely they cannot be both nil
                error(comms.robot_send("fatal", "You are very very very stupuid coke_quad"))
            end
        end

        state[2] = state[2] + 1
        return 1
    end
}

return Module
