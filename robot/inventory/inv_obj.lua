local module = {}
--imports {{{
-- I'll assume we have 32 slots (2-inventory upgrades) because otherwise it is just to small dog :sob:
-- Or we'll stay with 16 slots with the expectation that we abandon internal crafting quickly, idk
local component = require("component")
local sides_api = require("sides")
local robot = require("robot")
local text = require("text")
local serialize = require("serialization")
local filesystem = require("filesystem")

local deep_copy = require("deep_copy")
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")
local search_table = require("search_table")

local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))
--local MetaLedger = require("inventory.MetaLedger")
local VirtualInventory = require("inventory.VirtualInventory")
local SpecialDefinition = require("inventory.SpecialDefinition")
--local external_iobj = require("inventory.external_inv_obj")

local crafting_component = component.getPrimary("crafting")
local inventory = component.getPrimary("inventory_controller")
--}}}

-- forbiden slots (because of crafting table) = 1,2,3 -- 5,6,7 -- 9,10,11
-- this means actual internal inventory size while crafing mode is true is == 7
local inventory_size = 32
local used_up_capacity = 0

local crafting_table_slots = {1,2,3, -1, 5,6,7, -1, 9,10,11}
local tool_belt_slots = {}
local slot_managed = {}

local crafting_table_clear = true
local use_self_craft = true

-- Hopefully for now it'll be efficient enough to simply iterate all external ledgers
-- rather than having to create a sort of universal ledger
local virtual_inventory = VirtualInventory:new(inventory_size)
module.virtual_inventory = virtual_inventory -- ref

-- External Ledgers table actually holds fat-ledgers not raw ledgers (aka, MetaExternalInventory)
local external_inventories = {}

local equiped_tool = nil

function module.serialize()
    local virtual_inventory = virtual_inventory:serialize()
    local external_table = {}
    for _, vinv_external in ipairs(external_inventories) do
        local serial = vinv_external:serialize()
        table.insert(external_table, serial)
    end
    
    -- local inv_size = serialize.serialize(inventory_size, false)
    local big_table = {
        virtual_inventory,
        external_table,

        used_up_capacity,
        tool_belt_slots,
        slot_managed,

        crafting_table_clear,
        use_self_craft,
    }
    local big_serial = serialize.serialize(big_table, false)
    return big_serial
end

function module.re_instantiate(serial_str)
    local big_table = serialize.unserialize(serial_str)
    virtual_inventory = VirtualInventory:reInstantiate(big_table[1])

    local external_table = {}
    for _, entry in ipairs(big_table[2]) do
        local external = VirtualInventory:reInstantiate(entry)
        table.insert(external_table, external)
    end
    external_inventories = external_table

    used_up_capacity = big_table[3]
    tool_belt_slots = big_table[4]
    slot_managed = big_table[5]

    crafting_table_clear = big_table[6]
    use_self_craft = big_table[7]

    -- TODO reinstantiate equiped tool if possible
end


--->>-- Check on the ledgers --<<-----{{{

function module.register_ledger(fat_ledger)
    table.insert(external_inventories, fat_ledger)
end

function module.how_many_internal(lable, name)
    local quantity = virtual_inventory:howMany(lable, name)
    return quantity
end

function module.how_many_total(lable, name)
    local quantity = virtual_inventory:howMany(lable, name)
    for _, fat_ledger in ipairs(external_inventories) do
        local ledger = fat_ledger.ledger
        quantity = quantity + ledger:howMany(lable, name)
    end
    return quantity
end

-- No, I'm not going to solve the travelling salesman problem
local max_combined_travel = 512 + 128
function module.get_nearest_external_inv(lable, name, min_quantity, total_needed_quantity)
    -- ordered with biggest in the pop position (#size - 1)
    local ref_quant_table = nil
    for _, fat_inv in ipairs(external_inventories) do
        local pinv = fat_inv.ledger

        local quantity = pinv:howMany(lable, name)
        if quantity == nil or quantity < min_quantity then goto continue end
        local new_ref_quant = {quantity, fat_inv}

        if ref_quant_table == nil then table.insert(ref_quant_table, new_ref_quant); goto continue end
        local distance = fat_inv:getDistance()

        for index, entry in ipairs(ref_quant_table) do
            local i_quantity = entry[1]
            local i_inv = entry[2]

            local i_distance = i_inv:getDistance()
            if distance > i_distance then -- smaller is better
                table.insert(ref_quant_table, index, new_ref_quant)
                goto continue
            end
        end -- else, we da biggest ork

        table.insert(ref_quant_table, new_ref_quant)
        ::continue::
    end
    if ref_quant_table == nil then return nil end

    local dist_sum = 0
    local quant_sum = 0
    -- check if we aren't going to do too much travelling
    for index, entry in ipairs(ref_quant_table) do
        local i_quantity = entry[1]
        local i_inv = entry[2]
        local i_distance = i_inv:getDistance()

        quant_sum = quant_sum + i_quantity
        dist_sum = dist_sum + i_distance
        if quant_sum >= total_needed_quantity then break end
    end
    if dist_sum > max_combined_travel or quant_sum < total_needed_quantity then return nil end

    return ref_quant_table[#ref_quant_table][2] -- we'll be recomputing the table for everystep but who cares?
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

local big_table = {tool_belt_slots, crafting_table_slots}

local function get_forbidden_table()
    if use_self_craft then return big_table end
    return tool_belt_slots
end

local function non_craft_slot_iter()
    local iteration = used_up_capacity
    return function ()
        iteration = iteration + 1
        if iteration > inventory_size then
            return nil
        end

        local cur_f = crafting_table_slots[iteration]
        if (cur_f ~= nil and cur_f ~= -1) or search_table.ione(get_forbidden_table(), iteration) then
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
        if search_table.ione(get_forbidden_table(), iteration) then
            return -1
        end

        return iteration
    end
end


local function sort_slot_table(tbl)
    for head = 2, #tbl do
        local key = tbl[head]

        local t_index = head - 1
        while t_index >= 1 and tbl[t_index][2] > key[2] do
            tbl[t_index + 1] = tbl[t_index]
            t_index = t_index - 1
        end

        tbl[t_index + 1] = key
    end
end

------>>-- LE CLEAR SLOTS FUNCTIONS --<<-----------

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

-- local function force_clear_crafting_table()
-- end

-----------------------------------------


local function compress_into_slot(lable, name, slot)
    local all_slots = virtual_inventory:getAllSlots(lable, name)

    -- Order things up in place (smallest to biggest)
    sort_slot_table(all_slots)

    -- Now we exclude the "slot" slot from the table, and "recover it" (transmute from number to table)
    for index, element in ipairs(all_slots) do
        if element[1] == slot then
            slot = table.remove(all_slots, index)
            break
        end
    end
    if type(slot) ~= "table" then error(comms.robot_send("fatal", "assertion failed")) end

    for _, element in ipairs(all_slots) do
        local inner_slot = element[1]
        local inner_size = element[2]
        if inner_size == 64 then break end

        local target_slot = slot[2]
        local cur_target_size = slot[2]

        local sum = cur_target_size + inner_size
        local diff = 64 - sum

        local to_transfer = math.min(64, 64 + diff) -- if diff is negative then the min will be smaller than 64
        if to_transfer <= 0 then break end

        local detect = robot.detectUp()
        if detect then
            print(comms.robot_send("error", "could not perform exchange, no space above"))
            return false
        end

        local empty_slot = virtual_inventory:getEmptySlot()
        if empty_slot == nil then error(comms.robot_send("error", "assertion failed")) end

        robot.select(inner_slot)
        if not robot.transferTo(empty_slot, to_transfer) then
            print(comms.robot_send("error", "could not perform exchange, couldn't transfer to empty"))
            robot.select(1)
            return false
        end
        robot.select(empty_slot)

        if not robot.dropUp() then -- drops entire item stack!
            print(comms.robot_send("error", "could not perform exchange, couldn't dropUp \n\z
                As a consequence the inventory representation is now effed, force updating inventory.... \n\z
                Crafting table is now probabily poluted, you'll have to fix that on your own!"
            ))
            module.force_update_vinv()

            robot.select(1)
            return false
        end

        robot.select(target_slot)
        local result = true
        while result do
            result = robot.suckUp()
        end

        -- Important: this below updates the internal represetation of the inventory to match the new state:
       virtual_inventory:removeFromSlot(inner_slot, to_transfer)
       virtual_inventory:forceUpdateSlot(lable, name, cur_target_size + to_transfer, target_slot)
    end
    robot.select(1)
    return true
end

--
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

    local b_lable
    local b_name
    if type(block_identifier) == "table" then
        b_lable = block_identifier.lable
        b_name = block_identifier.name
    else
        if lable_type == "name" then
            b_name = block_identifier
        elseif lable_type == "lable" then
            b_lable = block_identifier
        elseif lable_type == "table" then
            error(comms.robot_send("fatal", "It was supposed to be a table"))
        else
            error(comms.robot_send("fatal", "lable_type is not valid"))
        end
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

    local slot = virtual_inventory:getSmallestSlot(b_lable, b_name)
    if slot == nil then
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
        virtual_inventory:removeFromSlot(slot, 1)
    end
    return place_result
end
---}}}

--->>-- External Inventories --<<-------{{{
--TODO interaction with external inventories and storage inventories

-- if matching_slots is nil, return early and falsy, for sucking all use suck all, dummy
function module.suck_vinventory(external_inventory, left_to_suck, matching_slots)
    if matching_slots == nil then return false end

    local inv_table = external_inventory.inv_table
    for index = 1, #inv_table, 3 do
        local slot = (index + 2) / 3
        if not search_table.ione(matching_slots, slot) then goto continue end

        local lable = inv_table[index]
        local name = inv_table[index + 1]
        local quantity = inv_table[index + 2]

        local cur_suck_quantity = 64
        if left_to_suck ~= nil then
            if left_to_suck <= 0 then break end

            local div = math.floor(left_to_suck / 64)
            if div == 0 then cur_suck_quantity = left_to_suck
            elseif div < 0 then error(comms.robot_send("fatal", "impossible state")) end
            -- else retain 64
        end

        -- I'm going to trust it is this simple, because the way the api's "suck into slot" and our
        -- addOrCreate seem to map 1-to-1, if de-syncs start to happen use a smarter solution I guess
        local internal_slot = virtual_inventory:getSmallestSlot(lable, name)
        robot.select(internal_slot)

        if not inventory.suckFromSlot(sides_api.front, slot, cur_suck_quantity) then
            print(comms.robot_send("error", "An error occuring sucking all vinventory: unable to suck"))
            goto continue
        end

        local how_much_sucked = math.min(cur_suck_quantity, quantity)
        virtual_inventory:addOrCreate(lable, name, how_much_sucked, get_forbidden_table())
        external_inventory:removeFromSlot(slot, how_much_sucked)
        if left_to_suck ~= nil then
            left_to_suck = left_to_suck - how_much_sucked
        end

        ::continue::
    end

    robot.select(1)
end

-- after all this update inventories
function module.suck_ledger(external_ledger)
    error(comms.robot_send("fatal", "todo, the search things and maybe more?"))

    local result = true
    while result do
        result = robot.suck()
    end

    external_ledger:forceUpdateAsForeign()
    module.force_update_vinv()
end

-- the documentation says "However this will only take the first item available in that inventory"
-- I assume that first item available != first item SLOT available, otherwise big problem, well we'll see
-- robot.suck() will always try to get the first (from the left (?)) item from the foreign inventory
function module.suck_all(external_inventory) -- runs no checks what-so-ever (assumes that we're facing the inventory)
    local inv_type = external_inventory.inv_type
    if inv_type == nil then inv_type = "nil" end

    if inv_type == "ledger" then module.suck_ledger(external_inventory, false)
    elseif inv_type ~= "virtual_inventory" then module.suck_vinventory(external_inventory, false)
    else error(comms.robot_send("this a non-existent ledger/inv type!: " .. inv_type)) end
end

-- Selects only the sub-selected MetaItems to be sucked
function module.suck_only_matching(external_inventory, quantity, matching)
    local inv_type = external_inventory.inv_type
    if inv_type == nil then inv_type = "nil" end

    if inv_type == "ledger" then module.suck_ledger(external_inventory, true, quantity, matching)
    elseif inv_type ~= "virtual_inventory" then module.suck_vinventory(external_inventory, true, quantity, matching)
    else error(comms.robot_send("this a non-existent ledger/inv type!: " .. inv_type)) end
end

-- add the ability not to dump certain things, or don't, might not make sense
function module.dump_all_possible(external_inventory) -- respect "special slots" (aka, don't dump them tehe)
    for slot = 1, inventory_size, 1 do
        if search_table.ione(get_forbidden_table(), slot) then
            goto continue
        end -- else

        robot.select(slot)
        if not robot.drop() then goto continue end
        local lable, name, quantity = virtual_inventory:getSlotInfo(slot)

        external_inventory:addOrCreate(lable, name, quantity, nil)
        virtual_inventory:removeFromSlot(slot, 64) -- 64 for try to remove entire stack
        ::continue::
    end
    robot.select(1)
    return true
end

function module.dump_only_named(lable, name, external_inventory, how_much_to_dump)
    local matching_slots = external_inventory:getAllSlotsUpTo(lable, name, how_much_to_dump)
    return module.dump_only_matching(external_inventory, matching_slots)
end

-- if no "left_to_dump" provided dump everything
function module.dump_only_matching(external_inventory, matching_slots)
    local inv_type = external_inventory.inv_type
    if inv_type == "ledger" then error(comms.robot_send("fatal", "This is not supported right now")) end
    if matching_slots == nil then return false end

    for _, entry in ipairs(matching_slots) do
        local slot = entry[1]
        local quantity = entry[2]

        robot.select(slot)
        if not robot.drop(quantity) then goto continue end
        virtual_inventory:subtract(slot, quantity)

        local index = (slot * 3) - 2
        local lable = virtual_inventory.inv_table[index]
        local name = virtual_inventory.inv_table[index + 1]

        if external_inventory == nil or type(external_inventory) ~= "table" then goto continue end
        external_inventory:addOrCreate(lable, name, quantity, nil)

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

-- WARNING: can only craft (optimistically) up to a stack at the time! expected_output > 64 is floored to 64
local function self_craft(dictionary, recipe, how_much_to_craft, expected_output)
    expected_output = math.min(64, expected_output)

    if not crafting_table_clear then
        print(comms.robot_send("error", "attempted to self_craft, yet internal crafting table was not clear, aborting!"))
        return false
    end

    local ingredient_table = {}
    local occurence_table = {} -- = {slot_a, slob_b, .... slot_c}
    for slot, char in ipairs(recipe) do
        if occurence_table[char] == nil then
            occurence_table[char] = {slot}
            local ingredient = dictionary[char]
        else
            table.insert(occurence_table[char], slot)
        end
    end

    local clean_up = false
    for stbl_index, sub_table in ipairs(occurence_table) do
        local lable, name
        local ingredient = ingredient_table[stbl_index]
        if type(ingredient) == "table" then -- select strict search (or permissive is ingredient[1] is nil)
            lable = ingredient[1]
            name = ingredient[2]
        else -- select lable-only search
            lable = ingredient
            name = nil --> "generic" (remember than "generic" will match any other name)
        end

        local how_many_needed = #sub_table
        local how_many_in_inv = virtual_inventory:howMany(lable, name)
        local how_many_can_craft = math.floor(how_many_in_inv / how_many_needed)
        if how_many_can_craft < how_much_to_craft then -- no bueno
            clean_up = true
            break
        end

        for _, c_table_slot in ipairs(sub_table) do
            -- this correction needs to be done because crafting table is 3 slots wide, but robot inventory is 4 slots wide
            if c_table_slot > 6 then c_table_slot = c_table_slot + 2
            elseif c_table_slot > 3 then c_table_slot = c_table_slot + 1 end

            local ingredient_slot = virtual_inventory:getLargestSlot(lable, name)
            local slot_size = virtual_inventory:howManySlot(ingredient_slot)
            if slot_size < how_much_to_craft then
                local result = compress_into_slot(lable, name, ingredient_slot)
                if not result then clean_up = true; break end
            end

            local result = robot.select(ingredient_slot)
            if result ~= ingredient_slot or not robot.transferTo(c_table_slot, how_much_to_craft) then
                print(comms.robot_send("error", "something went wrong in self_crafting"))
                clean_up = true
                break
            end
        end
    end -- Then check for errors
    if clean_up then
        print(comms.robot_send("error", "TODO -> actually clean-up crafting-grid in case of error"))
        return false
    end

    -- Now the virtual crafting-table should be assembled, lets do the thing!
    local output_slot = virtual_inventory:getSmallestSlot(expected_output.lable, expected_output.name)
    if  output_slot == nil
        or virtual_inventory:howManySlot(output_slot) + how_much_to_craft > 64
    then
        output_slot = virtual_inventory:getEmptySlot(get_forbidden_table())
    end

    if output_slot == nil then error(comms.robot_send("fatal", "assert failed!")) end
    robot.select(output_slot)
    local result = crafting_component.craft(64)     -- craft as many as possible, in case of gross oversight
                                                    -- this should at least keep the crafting area clear

    if not result then
        error(comms.robot_send("fatal", "failed to craft :("))
    end


    -- Optimistically Update the thingy-majig
    if expected_output ~= nil then
        virtual_inventory:forceUpdateSlot(expected_output.lable, expected_output.name, how_much_to_craft, output_slot)
    else
        local item_info = inventory.getStackInInternalSlot(output_slot)
        virtual_inventory:forceUpdateSlot(item_info.label, item_info.name, how_much_to_craft, output_slot)
    end

    robot.select(1)
    return true
end

-- recipe as defined in reasoning
function module.craft(dictionary, recipe, how_much)
    if use_self_craft then return self_craft(dictionary, recipe, how_much)
    else error(comms.robot_send("fatal", "TODO!")) end
end

---}}}

function module.maybe_something_added_to_inv(lable_hint, name_hint) -- important to keep crafting table clear
    if used_up_capacity >= inventory_size - 1 then -- stop 1 early, to not over-fill
        return false
    end

    local result = true
    local quantity = robot.count(1)
    if quantity > 0 then    -- This is a rare occurence when something fell into the inventory that was not
                            -- there before, or if a stack was already full -> aka rare
        used_up_capacity = used_up_capacity + 1
        local item = inventory.getStackInInternalSlot(1)
        local lable = item.label; local name = item.name
        virtual_inventory:addOrCreate(lable, name, quantity, get_forbidden_table())

        -- Make sure that these clear_functions act in the sameway that addOrCreate does (I think it does but who knows)
        if use_self_craft then result = clear_first_slot(non_craft_slot_iter)
        else result = clear_first_slot(free_slot_iter) end

        -- fallthrough because imagine we input 44 items in, there is 1 stack that already has 32 items, there
        -- will be 12 items that'll got to slot 1 (I think), but now the already present stack has 64 items,
        -- if we return immediatly the update will only account for the 12 items, not the whole 44

        -- return result
    end -- else it means it either didn't fall into the first slot or it didn't fall in the first place

    local slot_table
    -- [1] - Strict Matching, find this lable, [2] - Name Matching, find all that matches this "bucket"
    -- [3] - We'll have to do it the dumb way
    if lable_hint ~= nil then slot_table = virtual_inventory:getAllSlots(lable_hint, name_hint)
    elseif name_hint ~= nil then slot_table = virtual_inventory:getAllSlotsPermissive(name_hint)
    else
        module.force_update_vinv()
        return true
    end

    if slot_table == nil then return true end -- ideomatic?

    for _, element in ipairs(slot_table) do
        local slot = element[1]
        local expected_quantity = element[2]
        local stack_info = inventory.getStackInInternalSlot(slot)
        -- haha, something did get added (assume only 1 stack at the time so return)
        local diff = expected_quantity - stack_info.size
        if diff > 0 then
            virtual_inventory:subtract(slot, diff)
        elseif diff < 0 then
            virtual_inventory:addOrCreate(stack_info.label, stack_info.name, math.abs(diff), get_forbidden_table())
        end -- else all good, keep checking
    end

    return result
end

function module.force_add_in_slot(slot) -- ahr ahr
    local quantity = robot.count(slot)
    if quantity > 0 then
        used_up_capacity = used_up_capacity + 1
        local item = inventory.getStackInInternalSlot(slot)
        local name = item.name; local lable = item.label
        virtual_inventory:forceUpdateSlot(lable, name, quantity, slot)
    end
    -- Separate out into a function that clears the crafting table for us?
end

function module.force_update_vinv()
    virtual_inventory:forceUpdateInternal()
end


-- temp thing to get us going
module.force_update_vinv()

return module
