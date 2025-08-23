-- luacheck: globals FUEL_TYPE

local deep_copy = require("deep_copy")
local comms = require("comms")

local computer = require("computer")
local serialize = require("serialization")
local robot = require("robot")

local MetaInventory, MetaItem = table.unpack(require("inventory.MetaExternalInventory"))
--local MetaLedger = require("inventory.MetaLedger")
local MetaDoor = require("build.MetaBuild.MetaDoorInfo")
local LogisticTransfer = require("complex_algorithms.LogisticTransfer")


local nav = require("nav_module.nav_obj")
local inv = require("inventory.inv_obj")
local reas = require("reasoning.reasoning_obj")

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
    cooking_time = 0,

    -- needed for the generic hook VVV
    ---
    fsm = 1,
    in_what_asterisk = 1,
    temp_reg = nil,

    in_building = false,
    ---
    furnace_tbl = nil
}

-- First element of the hook array == special_symbol "*", etc.
Module.state_init = {
    function()
        return Module.shared_state -- takes a ref
    end,
    function(parent)
        local furnace_tbl = {
            MetaInventory:newMachine(input_items, parent, '*', 1, "furnace"),
            MetaInventory:newMachine(input_items, parent, '*', 2, "furnace"),
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

Module.hooks = {
    function(state, parent, flag, quantity_goal, state_table)
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

        return generic_hooks.std_hook1(state, parent, flag, Module.state_init[1], "coke_quad")
    end,
    function() -- Interact with furnace
        return 1
    end,
    function()
        return nil
    end,
}

return Module
