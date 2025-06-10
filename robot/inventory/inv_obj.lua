local module = {}
--imports {{{
-- I'll assume we have 32 slots (2-inventory upgrades) because otherwise it is just to small dog :sob:
-- Or we'll stay with 16 slots with the expectation that we abandon internal crafting quickly, idk
local component = require("component")
local sides_api = require("sides")
local robot = require("robot")
local text = require("text")

local deep_copy = require("deep_copy")
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))
local MetaLedger = require("inventory.MetaLedger")
local SpecialDefinition = require("inventory.SpecialDefinition")
--local external_iobj = require("inventory.external_inv_obj")

local crafting = component.getPrimary("crafting")
local inventory = component.getPrimary("inventory_controller")
--}}}

-- forbiden slots (because of crafting table) = 1,2,3 -- 5,6,7 -- 9,10,11
-- this means actual internal inventory size while crafing mode is true is == 7
local inventory_size = 32
local used_up_capacity = 0

local crafting_table_slots = {1,2,3, -1, 5,6,7, -1, 9,10,11}
local tool_belt_slots = {}

local crafting_table_clear = true
local use_self_craft = true

-- Hopefully for now it'll be efficient enough to simply iterate all external ledgers
-- rather than having to create a sort of universal ledger
local internal_ledger = MetaLedger:new()
module.internal_ledger = internal_ledger -- ref?

-- External Ledgers table actually holds fat-ledgers not raw ledgers (aka, MetaExternalInventory)
local external_ledgers = {}

local equiped_tool = nil

--->>-- Check on the ledgers --<<-----{{{

function module.register_ledger(fat_ledger)
    table.insert(external_ledgers, fat_ledger)
end

function module.how_many_internal(name, lable)
    local quantity = internal_ledger:howMany(name, lable)
    return quantity
end

function module.how_many_total(name, lable)
    local quantity = internal_ledger:howMany(name, lable)
    for _, fat_ledger in ipairs(external_ledgers) do
        local ledger = fat_ledger.ledger
        quantity = quantity + ledger:howMany(name, lable)
    end
    return quantity
end

---}}}

-- Slot Definition et al. {{{

local SlotDefinition = {
    slot_number = nil,
    special_definiiton = nil,
}
--function SlotDefinition:newFromCurrent(slot_numbers, material, item_name, item_level)

-- slot_numbers, might actually be a non-table number!
function SlotDefinition:new(slot_number, item_name)
    local new = deep_copy.copy(self, pairs)
    new.special_definition = SpecialDefinition:new(item_name)
    new.slot_number = slot_number

    table.insert(tool_belt_slots, slot_number) -- important
    return new
end


local slot_managed = {}
local slot_manager = {}
function slot_manager.add(obj)
    if obj.special_definition ~= nil then
        local name = obj.special_definition.item_name
        if slot_managed[name] == nil then slot_managed[name] = {} end
        table.insert(slot_managed[name], obj)
        return
    end

    local sd = obj.special_definition
    for _, slot_def in ipairs(obj) do
        local name = slot_def.special_definition.item_name
        if slot_managed[name] == nil then slot_managed[name] = {} end
        table.insert(slot_managed[name], slot_def)
    end
end

function slot_manager.find_all(item_name, level)
    local return_table = {}
    for _, multi_def in pairs(slot_managed) do
        for _, slot_def in pairs(multi_def) do
            local def = slot_def.special_definition
            if def.item_name == item_name and def.item_level >= level then
                table.insert(return_table, slot_def)
            end
        end
    end
    if #return_table > 0 then return return_table end
    return nil
end

-- I think this is fine
function slot_manager.find_slot(item_name, level) -- returns a slot number
    local result = slot_manager.find_all(item_name, level)
    if result ~= nil then
       return result[1].slot_number
    end
    return nil
end

function slot_manager.find_first(item_name, level)
    local result = slot_manager.find_all(item_name, level)
    if result ~= nil then
        return result[1]
    end
    return nil
end

function slot_manager.find_empty_slot(item_name) -- returns a slot number
    -- This filters two times, but the performance drop is acceptable
    local result = slot_manager.find_all(item_name, -1)
    for _, slot_def in ipairs(result) do
        local def = slot_def.special_definition
        if def.item_level == -1 then
            return def.slot_number
        end
    end
    return nil
end

-- puts item from x slot into appropriate tool slot
function slot_manager.put_from_slot(from_slot, item_name)
    local result = slot_manager.find_empty_slot(item_name)
    if result == nil then return false end -- return failure, aka, no empty slot, or no good item

    local old_select = robot.select(from_slot)
    result = robot.transferTo(result) -- if false failure, if true success
    robot.select(old_select)
    return result
end


--- Write more slot definitions :)
--
--  15,  16,  17,  18,  19,  20
-- (21)  22,  23,  24, (25)  26,
-- (27) (28) (29) (30) (31) (32)
local sd = SlotDefinition
slot_manager.add({sd:new(27, "pickaxe"), sd:new(21, "pickaxe")}) -- pickaxe
slot_manager.add({sd:new(31,"axe"), sd:new(25, "axe")}) -- axe
slot_manager.add({sd:new(29, "fuel"), sd:new(30, "fuel")}) -- fuel

slot_manager.add(sd:new(28, "shovel"))
slot_manager.add(sd:new(32, "sword"))
sd = nil

function module.special_slot_find_all(item_name, level)
    return slot_manager.find_all(item_name, level)
end

---}}}

--->>-- Local Functions --<<-----{{{
--local tool_belt_slots = {}
local function in_tool_slot(slot_num)
    for _, forbidden in ipairs(tool_belt_slots) do
        if forbidden == slot_num then
            return true
        end
    end
    return false
end

local function non_craft_slot_iter()
    local iteration = used_up_capacity
    return function ()
        iteration = iteration + 1
        if iteration > inventory_size then
            return nil
        end

        local cur_f = crafting_table_slots[iteration]
        if (cur_f ~= nil and cur_f ~= -1) or in_tool_slot(iteration) then
            return -1
        end

        return iteration
    end
end

local function free_slot_iter()
    local iteration = used_up_capacity + 1 -- spares first slot, meaningless logically

    return function ()
        iteration = iteration + 1
        if iteration > inventory_size then
            return nil
        end
        if in_tool_slot(iteration) then
            return -1
        end

        return iteration
    end
end

--
local function find_in_slot(block_id, lable_type)
    if lable_type == "lable" then
        for index = 1, inventory_size, 1 do
            local item = inventory.getStackInInternalSlot(index)
            if item == nil then goto continue end

            -- commented out anti-mangling code in the hope that it'll no longer be necessary

            -- This is needed because dictionary translation seems to mangle spaces
            -- this will destroy spaces to allow for comparison
            -- local split = text.tokenize(item.label)
            --local reconstruct = table.concat(split)

            -- somehow, now that we have BuildInstruction it doesn't get mangled???
            --if reconstruct == block_id or item.label == block_id then
            if item.label == block_id then
                return index, item
            end

            ::continue::
        end
    elseif lable_type == "name" then
        if block_id == "any:building_block" then
            local last_cbbl_match, last_dirt_match, cbbl_item, dirt_item

            for index = 1, inventory_size, 1 do
                local item = inventory.getStackInInternalSlot(index)
                if item == nil then goto continue end

                if item.lable == "Cobblestone" then
                    dirt_item = item
                    last_cbbl_match = index
                elseif item.lable == "Dirt" then
                    cbbl_item = item
                    last_dirt_match = index
                end

                ::continue::
            end

            local to_return, to_return2
            if last_cbbl_match ~= nil then
                to_return, to_return2 = last_cbbl_match, cbbl_item
            elseif last_dirt_match ~= nil then
                to_return, to_return2 = last_dirt_match, dirt_item
            else
                print(comms.robot_send("error", "inv_obj: no building block found in any slot"))
                return -2
            end

            return to_return, to_return2
        end

        print(comms.robot_send("error", "inv_obj: not valid lable_type"))
        return -2
    elseif lable_type == "optional_name" then -- expects block_identifier to be .lable, and not .label
        for index = 1, inventory_size, 1 do
            local item = inventory.getStackInInternalSlot(index)
            if item == nil then goto continue end

            if item.label == block_id.lable and (block_id.name == nil or item.name == block_id.name) then
                return index, item
            end

            ::continue::
        end
    else
        print(comms.robot_send("error", "inv_obj: not valid lable_type"))
        return -2
    end

    return -1 -- in case nothing was found
end
---}}}

-->>-- Clear Any Slot --<<-- {{{

local function clear_any_slot(iter, target_count)
    if robot.count(target_count) == 0 then return true end -- nothing needs to be done

    local free_slot = nil
    for slot_num in iter() do
        if slot_num == -1 then goto continue end
        if robot.count(slot_num) == 0 then
            free_slot = slot_num
            break;
        end

        ::continue::
    end
    if free_slot == nil then -- there is no free_slot
        crafting_table_clear = false
        return false
    end

    robot.select(target_count)
    robot.transferTo(free_slot)
    return true
end

local function clear_first_slot(iter)
    return clear_any_slot(iter, 1)
end
---}}}

--->>-- Tool Use --<<-----{{{
function module.get_equiped_tool_name()
    return equiped_tool.item_name
end

-- Assume that the tools are in their correct slots at all the times, it is not the responsibility
-- of this function to make sure that the items are in the desitred slot, unless of course, the
-- thing is about returning currently equiped tools to the correct slot
function module.equip_tool(tool_type, wanted_level)
    -- Listen, it might start swinging at air with a sword but who cares
    if tool_type == nil or wanted_level == nil then
        return true
    end
    print(comms.robot_send("debug", "Equiping tool: " .. tool_type .. ", " .. wanted_level))

    -- First, check if it already equiped
    if equiped_tool ~= nil and equiped_tool.item_name == tool_type and equiped_tool.item_level >= wanted_level then
        -- Update internal representation if the tool is now broken
        robot.select(1) -- empty slot
        inventory.equip()
        if robot.count(1) == 0 then -- tool broke
            goto fall_through
        end -- else tool is good!
        inventory.equip() -- equip it again

        return true -- "We equipped it succesefully"
    end
    ::fall_through::

    local first_tool = slot_manager.find_first(tool_type, wanted_level)
    local slot = nil
    local sp_definition = nil
    if first_tool ~= nil then
        slot = first_tool.slot_number
        sp_definition = first_tool.special_definition
    end

    -- Equip required tool if found else return false
    if slot == nil then return false end
    robot.select(slot)
    local result = inventory.equip()
    equiped_tool = sp_definition -- ref

    -- Check if something was swapped (aka there was already something equiped) and if it is a
    -- tool move it to the appropriate slot, else try to move item to an availabe free slot
    -- (since it was swapped into a forbiden slot)
    -- if it was tool and wasn't moved succesefully, just try and clear it from the current slot
    local new_item = inventory.getStackInInternalSlot(slot)
    local what_item = bucket_functions.identify(new_item.name, new_item.lable)
    local is_tool = slot_manager.find(what_item, -1)
    if is_tool ~= nil then
        if slot_manager.put_from_slot(slot, what_item) then
            return result, true
        end -- elseif unsucceseful
        local iter
        if use_self_craft then iter = non_craft_slot_iter
        else iter = free_slot_iter end
        local secondary_result = clear_any_slot(slot, iter)
        return result, secondary_result
    end -- else if it's not tool

    local iter
    if use_self_craft then iter = non_craft_slot_iter
    else iter = free_slot_iter end
    local secondary_result = clear_any_slot(slot, iter)
    return result, secondary_result
end

local function swing_general(swing_function, dir, pre_analysis)
    local g_info
    if pre_analysis ~= nil then
        g_info = pre_analysis
    else
        g_info = geolyzer.simple_return(dir) -- hopefully this dir is relative to robot, run some tests
    end

    if g_info == nil then return true end -- returning true is more ideomatic, I think.

    local needed_level = g_info.harvestLevel
    local needed_tool = g_info.harvestTool
    local result = module.equip_tool(needed_tool, needed_level)
    if not result and needed_level > 0 then
        print(comms.robot_send("warning", "unable to equip needed tool"))
    elseif not result and needed_level <= 0 then
        comms.robot_send("debug", "unable to equip tool, but block is mineable anyway")
    end

    local result, info = swing_function() -- luacheck: ignore
    if result == true and info == "block" then
        module.maybe_something_added_to_inv()
    end

    return result, info
end

-- in the case we already have a geo_analysis of what we want to mine send it in, :P saves some power
function module.blind_swing_front(pre_analysis)
    return swing_general(robot.swing, sides_api.front, pre_analysis)
end

function module.blind_swing_down(pre_analysis)
    return swing_general(robot.swingDown, sides_api.down, pre_analysis)
end

function module.blind_swing_up(pre_analysis)
    return swing_general(robot.swingUp, sides_api.up, pre_analysis)
end
---}}}


--->>-- Block Placing --<<----{{{

-- remember that because we're stupid, our own "lable" is lable, but the lable from
-- an item representation provided from OC is american "label"
--
-- TODO expand block searching in such a way that it beats duplicate lables
function module.place_block(dir, block_identifier, lable_type, side)
    -- if side is nil it doesn't matter
    if side ~= nil then side = sides_api[side] end

    if type(block_identifier) == "table" then
        if lable_type == "lable" then block_identifier = block_identifier.lable
        elseif lable_type == "name" then block_identifier = block_identifier.name
        elseif lable_type == "optional_name" then -- luacheck: ignore (do nothing)
        else block_identifier = "invalid \"lable_type\"" end
    end
    if block_identifier == "air" then
        local swing_result
        if dir == "up" then
            swing_result = module.blind_swing_up()
        elseif dir == "down" then
            swing_result = module.blind_swing_down()
        else print(comms.robot_send("warning", "place_block, punching air in: invalid dir for now")) end
        return swing_result
    end

    local slot, item_def = find_in_slot(block_identifier, lable_type)
    if slot == -1 then
        print(comms.robot_send("warning", "couldn't find id: \"" .. block_identifier .. "\" lable -- " .. lable_type))
        return false
    elseif slot < -1 then
        return false
    end

    robot.select(slot)

    local place_result
    if dir == "down" then
        place_result = robot.placeDown(side)
    elseif dir == "up" then
        place_result = robot.placeUp(side)
    elseif dir == "front" then
        place_result = robot.place(side)
    elseif dir == "back" or dir == "left" or dir == "right" then
        print(comms.robot_send("error", "not yet implemented, and unlikely to be implemented inv_obj.place_block"))
        robot.select(1)
        return false
    else
        print(comms.robot_send("error", "inv_obj.place_block -- Invalid direction: \"" .. dir .. "\""))
        print(comms.robot_send("error", "\n" .. debug.stracktrace()))
        robot.select(1)
        return false
    end

    robot.select(1)

    if place_result then
        if item_def == nil then
            print(comms.robot_send("error", "inv_obj.place_block -- item_def returned nil! But place was succeseful?"))
            return false
        elseif item_def.name == nil then
            print(comms.robot_send("error", "inv_obj.place_block -- item_def has no name?"))
            return false
        end

        local delete_result = internal_ledger:subtract(item_def.name, item_def.label, 1)
        if not delete_result then
            print(comms.robot_send("error", "inv_obj.place_block -- we weren't able to subtract from ledger!"))
            return false
        end
    end
    return place_result
end
---}}}

--->>-- External Inventories --<<-------{{{
--TODO interaction with external inventories and storage inventories

local function in_array(index, array)
    for _, slot_num in ipairs(array) do
        if slot_num == index then return false end
    end
    return false
end

function module.suck_all(external_ledger) -- runs no checks what-so-ever (assumes that we're facing the inventory)
    local result = true
    while result do
        result = module.try_remove_any_from(external_ledger)
        module.maybe_something_added_to_inv()
    end
end

-- add the capacity of not dumping certain things, I don't, might not make sense
function module.dump_all_possible(external_ledger) -- respect "special slots" (aka, don't dump them tehe)
    for index = 1, inventory_size, 1 do
        if in_array(index, tool_belt_slots) then -- dumbest way possible
            goto continue
        end -- else

        module.try_add_to(external_ledger, index)
        ::continue::
    end
    robot.select(1)
    return true
end

-- luacheck: push ignore name
local function id_by_lable(what_in_slot, name, lable)
    return what_in_slot.label == lable
end
-- luacheck: pop

-- luacheck: push ignore lable
local function id_by_naive_contains(what_in_slot, name, lable)
    return string.find(what_in_slot.name, name) ~= nil
end
-- luacheck: pop

local function return_eval_func(id_type)
    local eval_func

    if id_type == "lable" then
        eval_func = id_by_lable
    elseif id_type == "naive_contains" then
        eval_func = id_by_naive_contains
    elseif id_type == "name" then
        error(comms.robot_send("fatal", "inventory, id_type: \"name\" not implemented"))
    else
        error(comms.robot_send("fatal", "inventory, id_type is invalid"))
    end

    return eval_func
end

function module.search_external_ledger()
    local eval_func = return_eval_func(id_type)

end

function module.dump_all_named(name, lable, id_type, external_ledger)
    local eval_func = return_eval_func(id_type)

    for index = 1, inventory_size, 1 do
        local what_in_slot = inventory.getStackInInternalSlot(index)
        if what_in_slot == nil then goto continue end

        if  in_array(index, tool_belt_slots) -- dumbest way possible
            or not eval_func(what_in_slot, name, lable)
        then
            goto continue
        end -- else

        if type(external_ledger) ~= "number" then -- hard crash if we haven't an external ledger and we don't acknoledge that fact
            module.try_add_to(external_ledger, index)
        else
            robot.select(index)
            if not robot.drop() then goto continue end
            internal_ledger:subtract(what_in_slot.name, what_in_slot.label, what_in_slot.size)
        end

        ::continue::
    end

    robot.select(1)
    return true
end

--}}}


--->>-- Crafter Shit --<<-----{{{

function module.isCraftActive()
    return use_self_craft
end

function module.debug_force_add()
    for i in free_slot_iter() do
        local quantity = robot.count(i)
        if quantity == 0 then goto continue end

        local item = inventory.getStackInInternalSlot(i)
        local name = item.name; local lable = item.label
        internal_ledger:addOrCreate(name, lable, quantity)

        ::continue::
    end
end

---}}}

-- assuming it gets sucked into slot 1 yadda yadda
function module.try_remove_any_from(external_ledger)
    robot.select(1)
    if not robot.suck() then return false end

    local item = inventory.getStackInInternalSlot(1)
    if item == nil then
        print(comms.robot_send("error", "we sucked yet item stack was nil"))
        return false
    end

    external_ledger:subtract(item.name, item.label, item.size)
    return true
end

function module.try_add_to(external_ledger, internal_slot)
    local item = inventory.getStackInInternalSlot(internal_slot)
    if item == nil then return true end

    -- WARNING, it might happen that: internal (60 coal) exteranl 1 slot with (63 coal) drops only 1 coal into
    -- the exteral, we're left with 59 in the internal slot, yet the ledger will be updated as if we've dumped
    -- everything succesefully, let us hope that the behaviour of robot.drop() is smarter than this! Otherwise
    -- we'll need to change our code (TODO)
    robot.select(internal_slot)
    if not robot.drop() then
        return false
    end

    robot.select(1)
    external_ledger:addOrCreate(item.name, item.label, item.size)
    internal_ledger:subtract(item.name, item.label, item.size)

    return true
end

local io = require("io")
-- IMPORTANT: this assumes that new items will always go into the first slot, this might not be the case
-- with things that drop more than one item; in that case uhhhhhhh we need better accounting
-- algorithms that detect if something is in the inventory that was not there previously,
-- I think we can just check back with the ledger but hey || TODO - what is said before

-- Hopefully robot.count == 0 works in detecting empty slots, otherwise.... woppps sorry
function module.maybe_something_added_to_inv() -- important to keep crafting table clear
    if used_up_capacity >= inventory_size - 1 then -- stop 1 early, to not over-fill
        return false
    end

    local quantity = robot.count(1)
    if quantity > 0 then
        used_up_capacity = used_up_capacity + 1
        local item = inventory.getStackInInternalSlot(1)
        local name = item.name; local lable = item.label
        internal_ledger:addOrCreate(name, lable, quantity)
    end

    local result
    if use_self_craft then
        result = clear_first_slot(non_craft_slot_iter)
    else
        result = clear_first_slot(free_slot_iter)
    end

    if not result then return false end

    -- Kludge time!
    local temp_ledger = MetaLedger:new()
    for index = 1, inventory_size, 1 do
        if in_tool_slot(index) then goto continue end -- do not check things in tool slots, I guess
        local item = inventory.getStackInInternalSlot(index)
        if item == nil then goto continue end

        temp_ledger:addOrCreate(item.name, item.label, item.size)

        ::continue::
    end
    local diff_table = internal_ledger:compareWithLedger(temp_ledger.ledger_proper)
    for _, diff in ipairs(diff_table) do
        if diff.diff < 0 then 
            internal_ledger:addOrCreate(diff.name, diff.lable, math.abs(diff.diff))
        end
    end
    -- Please work :sadge:

    return true
end

function module.force_add_in_slot(slot) -- ahr ahr
    local quantity = robot.count(slot)
    if quantity > 0 then
        used_up_capacity = used_up_capacity + 1
        local item = inventory.getStackInInternalSlot(slot)
        local name = item.name; local lable = item.label
        internal_ledger:addOrCreate(name, lable, quantity)
    end
    -- Separate out into a function that clears the crafting table for us?
end

function module.force_add_all_to_ledger()
    for index = 1, inventory_size, 1 do
        module.force_add_in_slot(index)
    end
end

-- temp thing to get us going
module.force_add_all_to_ledger()

return module
