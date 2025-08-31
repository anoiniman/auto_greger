-- luacheck: globals WHAT_LOADOUT EMPTY_STRING
local computer = require("computer")

local deep_copy = require("deep_copy")
local comms = require("comms")

local LogisticTransfer = require("complex_algorithms.LogisticTransfer")
local inv = require("inventory.inv_obj")

local inventory_size = 32
local module = {}


-- aka, pickaxe and fuel, hopefully recipe management/crafting is well syncronized with this
local __l_test = {
    {"Stone Bricks", "minecraft:generic", 48, 12},
    {"Gravel", "minecraft:generic", 32, 8},
    {"nil", "any:log", 32, 8},
}

local __l_second = {
    {"Flint Pickaxe", "tool:pickaxe", 2, 1},
    {"nil", "any:plank", 128, 48},
    {"nil", "any:log", 64, 16},
}

local cur_loadout = {} -- is only the data field of a loadout
local loadouts = {
    {
        data = __l_second,
        condition = function()
            return WHAT_LOADOUT == "second"
        end,
    },
    {
        data = __l_test,
        condition = function()
            return WHAT_LOADOUT == "test"
        end,
    },
}

function module.get_cur_loadout() -- gives copy
    return deep_copy.copy(cur_loadout, pairs)
end

local __l_has_warned = false
local function select_loadout()
    local selected_loadout = nil
    for index = #loadouts, 1, -1 do
        local loadout = loadouts[index]
        if loadout.condition() then
            selected_loadout = loadout.data
            break
        end
    end

    if selected_loadout == nil then
        if not __l_has_warned then
            print(comms.robot_send("warning", "Attempted to select load_out, yet none is valid"))
            __l_has_warned = true
        end
        return false
    end
    cur_loadout = selected_loadout
end

-- pointer to loadout being done
local doing_loadout = nil
local was_preselected = false
local loadout_clock = computer.uptime()
function module.do_loadout(priority, pre_selected, lock) -- useful for when you are leaving on a predictable expedition (e.g - gathering ore)
    if doing_loadout ~= nil then -- just update the priority (or "delete")
        if pre_selected == nil then
            if not was_preselected then
                doing_loadout[1] = priority
                doing_loadout[#doing_loadout] = priority
            end
            return nil
        else
            doing_loadout[1] = -3 -- aka delete (back in the event-loop)
            doing_loadout = nil -- and set the ref as clear here
        end
    end

    if lock == nil then
        lock = {0} -- dummy lock
    end

    local selected_loadout
    if pre_selected == nil then
        select_loadout()
        selected_loadout = cur_loadout
    else
        selected_loadout = pre_selected
        was_preselected = true
    end

    if #selected_loadout == 0 then return nil end


    __l_has_warned = false
    loadout_clock = computer.uptime()

    local logistic_transfer = "nil"
    local item_index = 1
    local phase = 1

    local command_tbl = {priority, module.do_loadout_logistics, selected_loadout, logistic_transfer, item_index, phase, lock, priority}
    doing_loadout = command_tbl

    return command_tbl
end

local holdout_clock = computer.uptime()
function module.check_loadouts()
    if computer.uptime() - holdout_clock < 33 then return nil end

    select_loadout()

    ----------- Using min items --------------
    for _, def in ipairs(cur_loadout) do
        local internal_quantity = inv.virtual_inventory:howMany(def[1], def[2])
        local external_quantity = inv.how_many_total(def[1], def[2]) - internal_quantity
        if def[4] > internal_quantity and external_quantity > (def[3] / 2) then
            return "loadout", module.do_loadout(92)
        end
    end

    ------------ Using empty Slots ------------
    local empty_slots = inv.virtual_inventory:getNumOfEmptySlots() - 9 + math.floor((#cur_loadout / 3))
    local clock_diff = computer.uptime() - loadout_clock -- seconds
    local diff_m = clock_diff / 60

    local priority
    if empty_slots > 16 then
        return nil
    elseif empty_slots > 10 then
        if diff_m < 60 then -- aka 1 hour
            return nil
        end
        priority = 40
    elseif empty_slots > 5 then
        if diff_m < 12 then
            return nil
        end
        priority = 60
    else
        priority = 90
    end
    -------------------------------------------

    return "loadout", module.do_loadout(priority)
end


-- If this doesn't work, f'it do some stochastic static analysis as a first try
-- This goes into infinite loop :(
function module.do_loadout_logistics(arguments)
    local selected_loadout = arguments[1]
    local logistic_transfer = arguments[2]
    local item_index = arguments[3]
    local phase = arguments[4]
    local lock = arguments[5]
    local priority = arguments[6]

    local function do_return() -- using do_return() instead of just recursing allows the programme to block, which is important
        return {priority, module.do_loadout_logistics, selected_loadout, logistic_transfer, item_index, phase, lock, priority}
    end
    local function n_inv_warning(lable, name, up_to, dump)
        local variable_str
        if dump then variable_str = "external inv space (dump)"
        else variable_str = "items in external invs (suck)" end

        print(comms.robot_send("warning",
            string.format("\z
            The robot (tm) ran out %s to fulfil the following definition:\n\z
            lable: %s, name:%s, quantity:%s", variable_str, lable, name, up_to)
        ))
    end

    local function new_dump_transfer(lable, name, to_dump)
        if to_dump == nil then
            to_dump = inv.virtual_inventory:howMany(lable, name)
        end

        local nearest_inv = inv.get_nearest_inv_by_definition(lable, name, math.ceil(to_dump / 64))
        if nearest_inv == nil then
            n_inv_warning(lable, name, to_dump, true)
            return false
        end

        local item_table = {{lable, name, to_dump}}
        logistic_transfer = LogisticTransfer:new("self", nearest_inv, item_table)
        return true
    end

    local function new_suck_transfer(lable, name, to_suck) -- to_suck == how much to suck
        if to_suck == nil then
            print(comms.robot_send("warning", "Attempted to order a suckage with no wanted suckage ammount:\n" .. debug.traceback()))
            return false
        end

        local min_quant = math.min(to_suck / 3, 8)
        local nearest_inv = inv.get_nearest_external_inv(lable, name, min_quant, to_suck)
        if nearest_inv == nil then
            n_inv_warning(lable, name, to_suck, false)
            return false
        end

        local item_table = {{lable, name, to_suck}}
        logistic_transfer = LogisticTransfer:new(nearest_inv, "self", item_table)
        return true
    end


    if type(logistic_transfer) ~= "string" then
        local le_return = logistic_transfer.doTheThing({logistic_transfer, lock, priority})
        if le_return == nil then logistic_transfer = "nil" end

        return do_return()
    end

    if phase == 1 then -- aka, the dump fase
        -- here item_index is re_interpreted as slot index, and we'll keep going until we run out of slots
        if item_index > inventory_size then
            item_index = 1
            phase = 2
            return do_return()
        end

        local lable, name, _ = inv.virtual_inventory:getSlotInfo(item_index)
        item_index = item_index + 1 -- increases item_index no matter what, no matter if we succed or fail,
                                    -- we just need to make sure we don't increment when we already are working
                                    -- on a transfer

        if lable == EMPTY_STRING then
            return do_return() -- go again
        end

        for _, def in ipairs(selected_loadout) do
            -- In the case that something IS in the definition, but in too much of an ammount we DO want to dump it
            if (def[1] == lable and def[2] == name) or (def[1] == "nil" and def[2] == name) then
                local real_quantity = inv.virtual_inventory:howMany(lable, name)

                if real_quantity <= def[3] then -- don't dump, if we don't have too much of it
                    -- item_index = item_index + 1
                    return do_return()
                end -- else

                local to_dump = real_quantity - def[3]

                new_dump_transfer(lable, name, to_dump)
                return do_return()
            end -- if
        end -- for
        -- Now, if the thing was NOT in any loadout definition, then it MUST be dumped no matter what

        new_dump_transfer(lable, name)
        return do_return()
    end
    if phase ~= 2 then
        error(comms.robot_send("fatal", "How does this happen?"))
    end

    -- print("item_index")
    -- Now we are in the sucking phase, when we run out of items to fetch we terminate ourselves
    if item_index > #selected_loadout then
        item_index = 1
        phase = 1
        doing_loadout = nil
        was_preselected = false
        loadout_clock = computer.uptime()
        holdout_clock = computer.uptime()
        return nil
    end
    local cur_def = selected_loadout[item_index]
    item_index = item_index + 1

    local lable = cur_def[1]
    local name = cur_def[2]
    local wanted_num = cur_def[3]
    -- Now we run some checks

    local inv_num = inv.virtual_inventory:howMany(lable, name)
    local to_suck = wanted_num - inv_num
    if to_suck <= 0 then return do_return() end

    new_suck_transfer(lable, name, to_suck)
    return do_return()
end

return module
