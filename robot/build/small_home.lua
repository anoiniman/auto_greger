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
Module.name = "small_home"

Module.dictionary = {
    ["f"] = {"Furnace", "minecraft:furnace" }, -- if this doesn't work then ouch
    ["1"] = {"Chest", "minecraft:chest" },

    ["c"] = {"Cobblestone", "any:building" },
    ["l"] = {"nil", "any:plank"},
    ["d"] = {"nil", "any:grass"},
}

Module.human_readable = {
    {
    "dddddd-",
    "dddddd-",
    "dddddd-",
    "dddddd-",
    "dddddd-",
    "dddddd-",
    "-------",
    },
    {
    "cccc-c-",
    "c11+-c-",
    "c----c-",
    "c**-+c-",
    "cff11c-",
    "cccccc-",
    "-------",
    },
    {
    "llllll-",
    "llllll-",
    "l-l-ll-",
    "l-l-ll-",
    "llllll-",
    "llllll-",
    "-------",
    },
    {
    "-------",
    "-------",
    "--l----",
    "--l----",
    "-------",
    "-------",
    "-------",
    },
}

Module.origin_block = {0,0,0} -- x, z, y

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(5, 1)

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
        local coke_tbl = {
            MetaInventory:newMachine(input_items, parent, '*', 1, "coke_oven"),
            MetaInventory:newMachine(input_items, parent, '*', 2, "coke_oven"),
        }

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

-- This can be implemented by adding different usage_flags to the definition, and having a debug
-- command that allows us to forcefully use a given known building with a given flag

-- time calculation assuming that each log takes 1800 ticks (90 seconds) to turn into charcoal
Module.hooks = {
    function(state, parent, flag, quantity_goal, state_table)
        if flag == "only_check" then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() - state.last_checked < 60 * 12 then return "wait" end -- 12 minutes of waiting :)

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
            print(comms.robot_send("error", string.format("coke_quad, bad_flag: %s", flag)))
            return nil
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
        inv.force_update_einv(cur_inv) -- force updates contents of storage, since they are not tracked

        if state.in_what_asterisk == 1 then
            local how_many = inv.virtual_inventory:howMany(nil, "any:log")
            inv.dump_only_named(nil, "any:log", cur_inv, how_many / 2)
        else
            inv.dump_only_named(nil, "any:log", cur_inv, 65)
        end

        inv.suck_only_named(nil, "any:log", cur_inv, 65)
        -- TODO dealing with creosote goes here:

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
