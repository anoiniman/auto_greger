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
    -- ["d"] = {"Chest", "minecraft:chest"}
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
    [1] = {{"-ccc*--", two_six}, {"-ccc---", one_seven}},   -- for height 1 change this
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

-- as long as we're doing things right there should be no problem with this, well just stay on the
-- lookout for bugs, if we're not deep_copying the state everytime we create a new building object
-- this can have problems, but as of right now we always deep_copy the primitive, so it's
-- ok to do this
Module.shared_state = {
    last_checked = computer.uptime(),

    fsm = 1,
    in_what_asterisk = 1,
    temp_reg = nil,

    in_building = false,
    ---
    coke_oven_tbl = nil
}

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return Module.shared_state -- takes a ref
    end,
    function(parent)
        local coke_tbl = {}

        table.insert(coke_tbl, MetaInventory:newMachine(input_items, parent, '*', 1))
        table.insert(coke_tbl, MetaInventory:newMachine(input_items, parent, '*', 2))

        Module.coke_oven_tbl = coke_tbl -- modifies shared state table
        return Module.shared_state -- takes the same ref
    end,
    -- removed local chest definition, git blame if you want it back :P
}

-- TODO (low priority) add auto-clear creosote oil when abcd
-- Hopefully the game won't run long enough for we needing to clear creosote oil, but idk, we'll see
-- very good furnace fuel as always, usually you only start having too much creosote when you start
-- doing steel, because you start burning lots of charcoal that you cannot offset with creosote,
-- anyway, I'll just order the robot arround manually if I need to

-- time calculation assuming that each log takes 1800 ticks (90 seconds) to turn into charcoal
Module.hooks = {
    function(state, parent, flag, quantity_goal, state_table)
        if flag == "only_check" then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() - state.last_checked < 920 then return "wait" end

            local storage_table = state_table[3][1]
            local input_storage = storage_table[1]
            local how_many_log = input_storage.ledger:howMany(nil, "any:log")
            if how_many_log < quantity_goal then
                --comms.robot_send("debug", "no_resources coke_quad: how many log is:" .. how_many_log)
                --comms.robot_send("debug", "no_resources coke_quad: needed is:" .. quantity_goal)
                return "no_resources"
            end -- else

            return "all_good"
        elseif flag ~= "raw_usage" then
            if flag == nil then flag = "nil" end
            error(comms.robot_send("fatal", string.format("coke_quad, bad_flag: %s", flag)))
        end
        local serial = serialize.serialize(state, true)
        print(comms.robot_send("debug", "The state of the current runner function is:\n" .. serial))

        return generic_hooks.std_hook1(state, parent, flag, Module.state_init[1], "coke_quad")
    end,
    function(state)
        nav.change_orientation("east")
        local check, _ = robot.detect()
        if check then goto after_turn end

        nav.change_orientation("west")
        check, _ = robot.detect()
        if check then goto after_turn end

        ::after_turn::
        local cur_inv = state.coke_oven_tbl[state.in_what_asterisk]

        if state.in_what_asterisk == 1 then
            local how_many = inv.virtual_inventory:howMany(nil, "any:log")
            inv.dump_only_named(nil, "any:log", cur_inv, how_many / 2)
        else
            inv.dump_only_named(nil, "any:log", cur_inv, 65)
        end

        inv.suck_only_named(nil, "any:log", cur_inv, 65)
        return 1
    end,
    --[[function(state)
        local storage_table = state[1]; local index = state[2]
        local cur_storage = storage_table[index]

        for _, item_def in cur_storage:itemDefIter() do
            inv.dump_only_named(item_def.lable, item_def.name, cur_storage.ledger)
        end

        state[2] = state[2] + 1
        return 1
    end--]]
}

return Module
