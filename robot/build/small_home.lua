-- luacheck: globals FUEL_TYPE

local deep_copy = require("deep_copy")
local comms = require("comms")

local computer = require("computer")
local serialize = require("serialization")
local robot = require("robot")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
--local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")
-- local LogisticTransfer = require("complex_algorithms.LogisticTransfer")


local nav = require("nav_module.nav_obj")
local inv = require("inventory.inv_obj")
local reas = require("reasoning.reasoning_obj")

-- local general_functions = require("build.general_functions")
local generic_hooks = require("build.generic_hooks")

local Module = {parent = nil}
Module.name = "small_home"

Module.dictionary = {
    ["f"] = {"Furnace", "minecraft:furnace" }, -- if this doesn't work then ouch
    ["1"] = {"Chest", "minecraft:chest" },

    ["c"] = {"Cobblestone", "any:building" },
    ["l"] = {"nil", "any:plank"},
    ["d"] = {"nil", "any:grass"},
    ["a"] = {"air", "shovel"},
}

Module.base_table = {
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
    "laalll-",
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

Module.origin_block = {0,0,-1} -- x, z, y

Module.doors = {}
Module.doors[1] = MetaDoor:new()
Module.doors[1]:doorX(5, 1)

function Module:new()
    return deep_copy.copy(self, pairs)
end

-- as long as we're doing things right there should be no problem with this, well just stay on the
-- lookout for bugs, if we're not deep_copying the state everytime we create a new building object
-- this can have problems, but as of right now we always deep_copy the primitive, so it's
-- ok to do this
function Module.og_state()
    return {
        -- needed for the generic hook VVV
        ---
        fsm = 1,
        in_what_asterisk = 1,
        temp_reg = nil,

        in_building = false,
        ---
        furnace_tbl = nil,
        to_cook_def = nil,
        how_much_to_cook_total = 0,

        cooking_time = 0,
        last_item_def = nil,
    }
end

Module.shared_state = Module.og_state()

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return Module.shared_state -- takes a ref
    end,
    function(parent)
        local furnace_tbl = {
            MetaInventory:newMachine(nil, parent, '*', 1, "furnace"),
            MetaInventory:newMachine(nil, parent, '*', 2, "furnace"),
        }

        Module.furnace_tbl = furnace_tbl -- modifies shared state table
        return Module.shared_state -- takes the same ref
    end,
    function(parent)
        local st_table = {
            MetaInventory:newLongTermStorage({MetaItem:new("any:any", nil, false, nil)}, parent, "*", 1, "double_chest"),
            MetaInventory:newLongTermStorage({MetaItem:new("any:any", nil, false, nil)}, parent, "*", 2, "double_chest"),
        }

        return {st_table, 1}
    end
}

-- Btw, remember that this state is not saved on re-load, because we simple pretend build the buildings into
-- existance, we store no state, so... yeah, expect weirdness to happen if yeah we crash in between these
-- jobs, oh well
Module.hooks = {
    function(state, parent, flag, check_table, _state_table)
        local quantity_goal = check_table[2]
        if flag == "only_check" then -- this better be checked before hand otherwise the robot will be acting silly
            if computer.uptime() < state.cooking_time then return "wait" end
            local needed_fuel_SU = quantity_goal    -- This works under the assumption that 1 smelt = 1 output.....
                                                    -- not the best assumption.... well, better to over produce than
                                                    -- to under produce? Maybe shouldn't be a problem (MAYBE)

            if FUEL_TYPE == "wood" then
                local needed_wood = math.ceil((needed_fuel_SU * 2) / 3)

                local wood = inv.how_many_internal(nil, "any:plank")
                if wood >= needed_wood then return "all_good" end

                local extern_wood = inv.how_many_total(nil, "any:plank")
                if extern_wood >= needed_wood then return
                    -- We don't need this because we should always have fuel in our inventory

                    --[[local pinv = inv.get_nearest_external_inv(
                        inner.output.lable, inner.output.name, 4, needed_to_transfer
                    )

                    local item_table = {inner.output.lable, inner.output.name, needed_to_transfer}
                    local to_transfer = {item_table} -- table of items
                    local inner = LogisticTransfer:new(pinv, "self", to_transfer)
                    local logistic_nav = {inner.doTheThing, inner} -- command gets "completed" by caller

                    return "execute", logistic_nav--]]
                end

                return "replace", reas.create_temp_dependency({lable = nil, name = "any:plank"}, 2/3)
            elseif FUEL_TYPE == "loose_coal" then
                -- check for Creosote Buckets in storage TODO
                -- local creo = inv.how_many_total("Creosote Bucket", <name>)

                local needed_coal = math.ceil(needed_fuel_SU / 8)
                local coal = inv.how_many_internal(nil, "any:fuel")
                if coal >= needed_coal then return "all_good" end

                return "replace", reas.create_temp_dependency({lable = nil, name = "any:fuel"}, 1/8)
            end

            return "all_good"
        elseif flag ~= "raw_usage" then
            if flag == nil then flag = "nil" end
            print(comms.robot_send("error", string.format("coke_quad, bad_flag: %s", flag)))
            return nil
        end
        local serial = serialize.serialize(state, true)
        print(comms.robot_send("debug", "The state of the current runner function is:\n" .. serial))

        if state.to_cook_def == nil then
            state.to_cook_def = deep_copy.copy(check_table[1])
            state.how_much_to_cook_total = check_table[2]
            state.cooking_time = computer.uptime() + (state.how_much_to_cook_total * 10) -- 10 seconds per item
        end

        local next_func = generic_hooks.std_hook1(state, parent, flag, Module.og_state, "simple_home(furnace)")
        if next_func == nil then
            state.to_cook_def = nil
            state.how_much_to_cook_total = 0
            state.cooking_time = 0
        end
        return next_func
    end,
    function(state) -- Interact with furnace
        nav.change_orientation("south")
        local _, c_type = robot.detect()
        if c_type == "solid" then goto after_turn end

        nav.change_orientation("north")
        _, c_type = robot.detect()
        if c_type == "solid" then goto after_turn end

        ::after_turn::

        -- First we try to remove whatever exists in the third slot?, nah remove everything, that'll show them
        -- if it doesn't work (likely) we'll have to change the function interface to try and suck the "first" output slot


        local cur_inv = state.furnace_tbl[state.in_what_asterisk]
        inv.suck_only_matching(cur_inv, nil, {1,2,3})
        inv.force_update_einv(cur_inv) -- force updates contents of storage, since they are not tracked

        if  state.last_item_def ~= nil
            and state.to_cook_def.lable == state.last_item_def.lable and state.to_cook_def == state.last_item_def.name
        then
            -- early return, we've only come to pickup what we wanted in the first place
            state.last_item_def = nil
            return 1
        end

        -- then dump "into" the first slot, through the top side of the block,
        -- then fuel into the side -- this should emulate how hoppers

        local input = state.to_cook_def
        local how_much = state.how_much_to_cook_total
        inv.dump_only_named(input.lable, input.name, cur_inv, how_much / 2, 1)

        local fuel_slot = 2
        if FUEL_TYPE == "wood" then
            local needed_fuel = math.ceil((how_much * 2) / 3)
            inv.dump_only_named(nil, "any:planks", cur_inv, needed_fuel / 2, fuel_slot)
        elseif FUEL_TYPE == "loose_coal" then
            local needed_fuel = math.ceil(how_much / 8)
            inv.dump_only_named(nil, "any:fuel", cur_inv, needed_fuel / 2, fuel_slot)
        else
            error(comms.robot_send("fatal", "What the hell are you doing idiot"))
        end

        state.last_item_def = state.to_cook_def
        return 1
    end,
    function()
        return nil
    end,
}

return Module
