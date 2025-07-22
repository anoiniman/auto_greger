-- luacheck: globals EMPTY_STRING
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
local PPObj = require("common_pp_format")

local item_bucket = require("inventory.item_buckets")
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
local slot_managed = {}

local crafting_table_clear = true
local use_self_craft = true

-- Hopefully for now it'll be efficient enough to simply iterate all external ledgers
-- rather than having to create a sort of universal ledger
module.virtual_inventory = VirtualInventory:new(inventory_size)
module.virtual_inventory.equip_tbl = {}
module.virtual_inventory:reportEquipedBreak()

-- External Ledgers table actually holds fat-ledgers not raw ledgers (aka, MetaExternalInventory)
local external_inventories = {}

function module.get_data()
    local virtual_inventory = module.virtual_inventory:getData()
    local external_table = {}
    for _, vinv_external in pairs(external_inventories) do
        local vinv = vinv_external:getData()
        table.insert(external_table, vinv)
    end

    -- local inv_size = serialize.serialize(inventory_size, false)
    local big_table = {
        virtual_inventory, -- 1
        module.virtual_inventory.equip_tbl,
        external_table,

        used_up_capacity,
        slot_managed, -- 4

        crafting_table_clear,
        use_self_craft, -- 6
    }
    return big_table
end

local MetaExternalInventory = nil
function module.re_instantiate(big_table)
    module.virtual_inventory = VirtualInventory:reInstantiate(big_table[1])
    module.equip_tbl = big_table[2] -- it's ok to do this directly since only primitives are "in there"

    local external_table = {}
    for _, entry in ipairs(big_table[3]) do -- entry is fat ledger, remember
        -- another wholesome hack TODO (fix this shit)
        if MetaExternalInventory == nil then MetaExternalInventory = require("inventory.MetaExternalInventory")[1] end

        local external = MetaExternalInventory:reInstantiate(entry)
        table.insert(external_table, external)
    end
    external_inventories = external_table

    used_up_capacity = big_table[4]
    slot_managed = big_table[5]

    crafting_table_clear = big_table[6]
    use_self_craft = big_table[7]
end

--->>-- Check on the ledgers --<<-----{{{
local function iter_external_inv(build_name)
    if build_name == nil then
        local inner, next_index
        local iteration = math.max
        local function real_next(_tbl)
            if inner ~= nil and iteration <= #inner then
                iteration = iteration + 1
                local value = inner[iteration]
                if value == nil then inner = nil; return real_next(_tbl) end
                return iteration, inner[iteration]
            else
                next_index, inner = next(_tbl, next_index)
                if inner == nil then return nil end

                iteration = 0
                return real_next(_tbl)
            end
        end
        return real_next, external_inventories
    end

    return ipairs(external_inventories[build_name])
end

local function prepare_pp_print(uncompressed, fat_ledger, index, size, large_pp)
    local pp_obj
    if uncompressed then
        pp_obj = fat_ledger.ledger:getFmtObj()
    else
        pp_obj = fat_ledger.ledger:getCompressedFmtObj()
    end

    local title_string = {"<External Inventory> (", index, "/", size, ")"}
    pp_obj:setTitle(table.concat(title_string))
    pp_obj:initPages()

    if large_pp.title == nil then
        for k, v in pairs(pp_obj) do large_pp[k] = v end
        return
    end

    large_pp:addPagesToSelf(pp_obj) 
end

local function do_pp_print(large_pp)
    large_pp:printPage(false)
    local castrated_object = deep_copy.copy_no_functions(large_pp)
    comms.send_command("ppObj", "printPage", castrated_object, true) -- this is ok to do because they'll simple be queued
end

local interactive_print = true
function module.print_external_inv(name, index, uncompressed)
    comms.cls_nself()
    local le_next, tbl, num = iter_external_inv(name)

    -- TODO we'll prob have to concat the internal inventories or have alterante view modes or whatever, for now just a simple print
    if name ~= nil and index ~= nil then
        local fat_ledger = tbl[index]
        local pp_obj = {}
        prepare_pp_print(uncompressed, fat_ledger, index, #tbl, pp_obj)
        do_pp_print(pp_obj)
    elseif name == nil and index ~= nil then
        print(comms.robot_send("warning", "Invalid name / index combination"))
        return
    end

    local real_tbl_size = #tbl
    if num == nil then -- aka, we're iterating over multiple sub tables through our custom iteratior
        real_tbl_size = 0
        for _, _ in le_next, tbl, nil do real_tbl_size = real_tbl_size + 1 end
    end

    local pp_obj = {}
    for jindex, fat_ledger in le_next, tbl, num do
        prepare_pp_print(uncompressed, fat_ledger, jindex, #tbl, pp_obj)
    end
    do_pp_print(pp_obj)
end


function module.register_ledger(fat_ledger)
    local build_name = fat_ledger.parent_build.name
    if build_name == nil then print(comms.send_unexpected()); return end

    if external_inventories[build_name] == nil then
        external_inventories[build_name] = {fat_ledger}
        return
    end
    table.insert(external_inventories[build_name], fat_ledger)
end

function module.find_largest_slot(lable, name)
    return module.virtual_inventory:getLargestSlot(lable, name)
end

function module.how_many_internal(lable, name)
    local quantity = module.virtual_inventory:howMany(lable, name)
    return quantity
end

function module.how_many_total(lable, name)
    local quantity = module.virtual_inventory:howMany(lable, name)
    for _, fat_ledger in iter_external_inv(external_inventories) do
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
    for _, fat_inv in iter_external_inv(external_inventories) do
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

-- ->>-- Load Outs --<<--------- {{{
-- TODO :)

---}}}

--->>-- Local Functions --<<-----{{{

local function get_forbidden_table()
    if use_self_craft then return crafting_table_slots end
    return nil
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
    local all_slots = module.virtual_inventory:getAllSlots(lable, name)

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

        local empty_slot = module.virtual_inventory:getEmptySlot()
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
       module.virtual_inventory:removeFromSlot(inner_slot, to_transfer)
       module.virtual_inventory:forceUpdateSlot(lable, name, cur_target_size + to_transfer, target_slot)
    end
    robot.select(1)
    return true
end

--
---}}}

--->>-- Tool Use --<<-----{{{

-- Assume that the tools are in their correct slots at all the times, it is not the responsibility
-- of this function to make sure that the items are in the desitred slot, unless of course, the
-- thing is about returning currently equiped tools to the correct slot
function module.equip_tool(tool_type, tool_level)
    -- Listen, it might start swinging at air with a sword but who cares
    if tool_type == nil or tool_level == nil then
        return true
    end
    print(comms.robot_send("debug", "Equiping tool: " .. tool_type .. ", " .. tool_level))

    local equiped_lable, equiped_type, equiped_level = module.virtual_inventory:getEquipedInfo()
    -- First, check if it already equiped
    if equiped_lable ~= EMPTY_STRING and equiped_type == tool_type and equiped_level >= tool_level then
        -- Update internal representation if the tool is now broken
        robot.select(1) -- empty slot
        inventory.equip()
        if robot.count(1) == 0 then -- tool broke
            module.virtual_inventory:reportEquipedBreak()
            goto fall_through
        end -- else tool is good!
        inventory.equip() -- equip it again

        return true -- We "equipped" it succesefully
    end
    ::fall_through::


    local slot = module.virtual_inventory:equipSomething(tool_type, tool_level)
    -- Equip required tool if found else return false
    if slot == nil then return false end
    robot.select(slot)
    local result = inventory.equip()

    return result
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

    local slot = module.virtual_inventory:getSmallestSlot(b_lable, b_name)
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
        module.virtual_inventory:removeFromSlot(slot, 1)
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
        local internal_slot = module.virtual_inventory:getSmallestSlot(lable, name)
        robot.select(internal_slot)

        if not inventory.suckFromSlot(sides_api.front, slot, cur_suck_quantity) then
            print(comms.robot_send("error", "An error occuring sucking all vinventory: unable to suck"))
            goto continue
        end

        local how_much_sucked = math.min(cur_suck_quantity, quantity)
        module.virtual_inventory:addOrCreate(lable, name, how_much_sucked, get_forbidden_table())
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
        local lable, name, quantity = module.virtual_inventory:getSlotInfo(slot)

        external_inventory:addOrCreate(lable, name, quantity, nil)
        module.virtual_inventory:removeFromSlot(slot, 64) -- 64 for try to remove entire stack
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
        module.virtual_inventory:subtract(slot, quantity)

        local index = (slot * 3) - 2
        local lable = module.virtual_inventory.inv_table[index]
        local name = module.virtual_inventory.inv_table[index + 1]

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
local function self_craft(dictionary, recipe, output, how_much_to_craft)
    if not crafting_table_clear then
        print(comms.robot_send("error", "attempted to self_craft, yet internal crafting table was not clear, aborting!"))
        return false
    end

    local ingredient_table = {}
    local occurence_table = {} -- = {slot_a, slob_b, .... slot_c}
    for slot, char in ipairs(recipe) do
        if char == 0 then goto continue end
        if occurence_table[char] == nil then
            occurence_table[char] = {slot}
            local ingredient = dictionary[char]
            ingredient_table[char] = ingredient
        else
            table.insert(occurence_table[char], slot)
        end

        ::continue::
    end

    local clean_up = false
    for stbl_index, sub_table in pairs(occurence_table) do
        local lable, name
        local ingredient = ingredient_table[stbl_index]

        if ingredient == nil then
            error(comms.robot_send("fatal", "assertion failed"))
        end

        if type(ingredient) == "table" then -- select strict search (or permissive is ingredient[1] is nil)
            lable = ingredient[1]
            name = ingredient[2]
        else -- select lable-only search
            lable = ingredient
            name = nil --> "generic" (remember than "generic" will match any other name)
        end

        local how_many_needed = #sub_table
        local how_many_in_inv = module.virtual_inventory:howMany(lable, name)
        local how_many_can_craft = math.floor(how_many_in_inv / how_many_needed)
        if how_many_can_craft < how_much_to_craft then -- no bueno
            print(comms.robot_send("error", "how many can craft: " .. how_many_can_craft .. " || \z
                                    how much to craft: " .. how_much_to_craft))
            local print_name = name
            local print_lable = lable
            if print_name == nil then print_name = "nil" end
            if print_lable == nil then print_lable = "nil" end

            print(comms.robot_send("error", "lable was: " .. print_lable .. " || name was: " .. print_name))
            print(comms.robot_send("error", "how many in inv was: " .. how_many_in_inv .. " || how many needed was: " .. how_many_needed))
            clean_up = true
            break
        end

        for _, c_table_slot in ipairs(sub_table) do
            -- this correction needs to be done because crafting table is 3 slots wide, but robot inventory is 4 slots wide
            if c_table_slot > 6 then c_table_slot = c_table_slot + 2
            elseif c_table_slot > 3 then c_table_slot = c_table_slot + 1 end

            local ingredient_slot = module.virtual_inventory:getLargestSlot(lable, name)
            local slot_size = module.virtual_inventory:howManySlot(ingredient_slot)
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
    local output_slot = module.virtual_inventory:getSmallestSlot(output.lable, output.name)
    if  output_slot == nil
        or module.virtual_inventory:howManySlot(output_slot) + how_much_to_craft > 64
    then
        output_slot = module.virtual_inventory:getEmptySlot(get_forbidden_table())
    end

    if output_slot == nil then error(comms.robot_send("fatal", "assert failed!")) end

    robot.select(output_slot)
    local result = crafting_component.craft(64)     -- craft as many as possible, in case of gross oversight
                                                    -- this should at least crash hard

    if not result then
        error(comms.robot_send("fatal", "failed to craft :("))
    end

    -- TODO make it not use getStackInInternalSlot se we're a bit faster
    local new_quantity = inventory.getStackInInternalSlot(output_slot).size
    -- Optimistically Update the thingy-majig
    module.virtual_inventory:forceUpdateSlot(output.lable, output.name, new_quantity, output_slot)

    robot.select(1)
    return true
end

-- It seems that we we self_craft this is done in one execution cycle!
function module.craft(arguments)
    local dictionary = arguments[1]
    local recipe_grid = arguments[2]
    local output = arguments[3]
    local how_much = arguments[4]
    local loc_ref = arguments[5]

    if use_self_craft then
        self_craft(dictionary, recipe_grid, output, how_much) -- this returns a result, but we don't care?
        loc_ref[1] = 2
        return nil
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
        module.virtual_inventory:addOrCreate(lable, name, quantity, get_forbidden_table())

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
    if lable_hint ~= nil then slot_table = module.virtual_inventory:getAllSlots(lable_hint, name_hint)
    elseif name_hint ~= nil then slot_table = module.virtual_inventory:getAllSlotsPermissive(name_hint)
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
            module.virtual_inventory:subtract(slot, diff)
        elseif diff < 0 then
            module.virtual_inventory:addOrCreate(stack_info.label, stack_info.name, math.abs(diff), get_forbidden_table())
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
        module.virtual_inventory:forceUpdateSlot(lable, name, quantity, slot)
    end
    -- Separate out into a function that clears the crafting table for us?
end

function module.force_update_vinv()
    module.virtual_inventory:forceUpdateInternal()
end


-- temp thing to get us going
module.force_update_vinv()

return module
