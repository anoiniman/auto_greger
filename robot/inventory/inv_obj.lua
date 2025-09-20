-- luacheck: globals EMPTY_STRING
local module = {}
--imports {{{
-- I'll assume we have 32 slots (2-inventory upgrades) because otherwise it is just to small dog :sob:
-- Or we'll stay with 16 slots with the expectation that we abandon internal crafting quickly, idk
local component = require("component")
local sides_api = require("sides")
local robot = require("robot")
local computer = require("computer")
-- luacheck: push ignore
local text = require("text")
local serialize = require("serialization")
local filesystem = require("filesystem")
-- luacheck: pop

local deep_copy = require("deep_copy")
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")
local search_table = require("search_table")
-- local PPObj = require("common_pp_format")

local item_bucket = require("inventory.item_buckets")
--local MetaLedger = require("inventory.MetaLedger")
local VirtualInventory = require("inventory.VirtualInventory")

local crafting_component = component.getPrimary("crafting")
local inventory = component.getPrimary("inventory_controller")
local generator = component.getPrimary("generator")

--}}}

-- forbiden slots (because of crafting table) = 1,2,3 -- 5,6,7 -- 9,10,11
-- this means actual internal inventory size while crafing mode is true is == 7
local inventory_size = 32
local used_up_capacity = 0 -- has become useless because of better inventory management schemes, remove in future

local crafting_table_slots = {1,2,3, -1, 5,6,7, -1, 9,10,11}

local crafting_table_clear = true
local use_self_craft = true

-- Hopefully for now it'll be efficient enough to simply iterate all external ledgers
-- rather than having to create a sort of universal ledger
module.virtual_inventory = VirtualInventory:new(inventory_size)
module.virtual_inventory.equip_tbl = {}
module.virtual_inventory:reportEquipedBreak() -- smart?

-- External Ledgers table actually holds fat-ledgers not raw ledgers (aka, MetaExternalInventory)
local external_inventories = {}

-- It is difficult to serialize by building, since their references changes as the programme is loaded/unloaded,
-- and storing enough information to know what building is what is unwieldy, so this table needs to
-- be recomputed from the "main table" everytime we start the programme, still, it is useful for a wide
-- variety of reasons, mainly when you are interested in putting certain things in specific buildings
-- local short_lived_ordered_inventories = {}


function module.get_data()
    local virtual_inventory = module.virtual_inventory:getData()
    local external_table = {}
    for _name, inner_table in pairs(external_inventories) do
        for _, fat_ledger in ipairs(inner_table) do
            local vinv = fat_ledger:getData()
            table.insert(external_table, vinv)
        end
    end

    -- local inv_size = serialize.serialize(inventory_size, false)
    local big_table = {
        virtual_inventory, -- 1
        module.virtual_inventory.equip_tbl,
        external_table,

        used_up_capacity, -- 4

        crafting_table_clear,
        use_self_craft, -- 6
    }
    return big_table
end

local MetaExternalInventory = nil
function module.re_instantiate(big_table) -- WARNING: reInstantiate will DELETE equip_tbl, you need to reinstantiate equiptbl in separate for now
    module.virtual_inventory = VirtualInventory:reInstantiate(big_table[1])
    if big_table[2] ~= nil then
        module.virtual_inventory.equip_tbl = big_table[2] -- it's ok to do this directly since only primitives are "in there"
    else
        module.virtual_inventory.equip_tbl = {}
        module.virtual_inventory:reportEquipedBreak() -- smart?
    end

    external_inventories = {}
    for _, entry in ipairs(big_table[3]) do -- entry is fat ledger, remember
        -- another wholesome hack TODO (fix this shit)
        if MetaExternalInventory == nil then MetaExternalInventory = require("inventory.MetaExternalInventory")[1] end

        local external = MetaExternalInventory:reInstantiate(entry)
        if external.parent_build ~= nil then -- because it might just be a self-cache duh
            module.register_ledger(external)
        end
    end

    used_up_capacity = big_table[4]

    crafting_table_clear = big_table[5]
    use_self_craft = big_table[6]
end

--->>-- Check on the ledgers --<<-----{{{

local function get_fat_ledger(table_name, index)
    if table_name == nil or index == nil  then
        print(comms.robot_send("error", "couldn't get fat_ledger, you have nils blud" ))
        return nil
    end

    local name_table = external_inventories[table_name]
    if name_table == nil then
        print(comms.robot_send("error", "couldn't add item to external, table_name has no table: " .. table_name))
        return nil
    end

    local fat_ledger = name_table[index]
    if fat_ledger == nil then
        print(comms.robot_send("error", "couldn't add item to external, index points to nothing: " .. index))
        return nil
    end

    return fat_ledger
end


function module.add_item_to_external(table_name, index, lable, name, to_be_added)
    local fat_ledger = get_fat_ledger(table_name, index)
    if fat_ledger == nil or lable == nil or name == nil or to_be_added == nil then
        print(comms.robot_send("error", "couldn't add item to external, you have nils blud" ))
        return false
    end

    local ledger = fat_ledger.ledger
    ledger:addOrCreate(lable, name, to_be_added)

    return true
end

function module.remove_stack_from_external(table_name, index, slot, how_much)
    local fat_ledger = get_fat_ledger(table_name, index)
    if fat_ledger == nil or slot == nil or how_much == nil or how_much < 0 then
        print(comms.robot_send("error", "couldn't add item to external, you have nils blud" ))
        return false
    end

    if how_much == 0 then return true end
    if how_much > 64 then how_much = 64 end

    local ledger = fat_ledger.ledger
    ledger:removeFromSlot(slot, how_much)

    return true
end

function module.list_external_inv()
    local print_buffer = {"\n"}
    for name, inner_tbl in pairs(external_inventories) do
        table.insert(print_buffer, string.format("%s = #%d\n", name, #inner_tbl))
        local other_buffer = {}

        -- TODO have it loop and find only the chunk/quad combinations that are unique

        local fat_buffer = inner_tbl[1]
        table.insert(other_buffer, "   -- ")
        table.insert(other_buffer, "chunk = (")
        local chunk = fat_buffer.parent_build.what_chunk
        table.insert(other_buffer, tostring(chunk[1]))
        table.insert(other_buffer, ", ")
        table.insert(other_buffer, tostring(chunk[2]))
        table.insert(other_buffer, ")\n")

        table.insert(other_buffer, "   -- ")
        table.insert(other_buffer, "quad = ")
        local quad_str = tostring(fat_buffer:getQuadNum())
        table.insert(other_buffer, quad_str)
        table.insert(other_buffer, "\n")

        table.insert(print_buffer, table.concat(other_buffer))
    end
    local str = table.concat(print_buffer)
    print(comms.robot_send("info", str))
end

local function iter_external_inv(build_name)
    if build_name == nil then
        local inner, next_index
        local iteration = math.max
        local function real_next(tbl)
            if inner ~= nil and iteration <= #inner then
                iteration = iteration + 1
                local value = inner[iteration]
                if value == nil then inner = nil; return real_next(tbl) end
                return iteration, inner[iteration]
            else
                next_index, inner = next(tbl, next_index)
                if inner == nil then return nil end

                iteration = 0
                return real_next(tbl)
            end
        end
        return real_next, external_inventories
    end

    if external_inventories[build_name] == nil then --some basic runtime checking
        return function() return nil end
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

    if large_pp.title == nil then -- aka, if large_pp is still just a {} instead of a inst of ppObj
        for k, v in pairs(pp_obj) do large_pp[k] = v end
        return
    end

    large_pp:addPagesToSelf(pp_obj)
end

local interactive_print = true
local function do_pp_print(large_pp)
    large_pp:printPage(false)
    local castrated_object = deep_copy.copy_no_functions(large_pp)
    comms.send_command("ppObj", "printPage", castrated_object, interactive_print) -- this is ok to do because they'll simple be queued
end

function module.print_external_inv(name, index, uncompressed)
    comms.cls_nself()
    local le_next, tbl, num = iter_external_inv(name)

    -- TODO we'll prob have to concat the internal inventories or have alterante view modes or whatever, for now just a simple print
    if name ~= nil and index ~= nil then
        local fat_ledger = tbl[index]
        local pp_obj = {}
        prepare_pp_print(uncompressed, fat_ledger, index, #tbl, pp_obj)
        do_pp_print(pp_obj)
        return
    elseif name == nil and index ~= nil then
        print(comms.robot_send("warning", "Invalid name / index combination"))
        return
    end
    if tbl == nil then return end

    --[[local real_tbl_size = #tbl
    if num == nil then -- aka, we're iterating over multiple sub tables through our custom iteratior
        real_tbl_size = 0
        for _, _ in le_next, tbl, nil do real_tbl_size = real_tbl_size + 1 end
    end--]]

    local pp_obj = {}
    local iterated = false
    for jindex, fat_ledger in le_next, tbl, num do -- NOTHING'S BEING PREPARED AHHHHHH
        iterated = true
        prepare_pp_print(uncompressed, fat_ledger, jindex, #tbl, pp_obj)
    end
    if iterated then do_pp_print(pp_obj)
    else print(comms.robot_send("info", "Empty")) end
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

    local empty_slot = module.virtual_inventory:getEmptySlot()
    if empty_slot == nil then return quantity end

    if name == "any:plank" or name == "any:fuel" or lable == "Charcoal" then
        robot.select(empty_slot)
        generator.remove(generator.count())
        local what_is = inventory.getStackInInternalSlot(empty_slot)
        if  what_is ~= nil and
            (what_is.label == lable or (what_is.name == name and (lable == nil or lable == "nil" or lable == "nil_lable"))) then
            quantity = quantity + what_is.size
        end

        generator.insert(64)
        robot.select(1)
    end

    return quantity
end

function module.how_many_total(lable, name)
    local quantity = module.virtual_inventory:howMany(lable, name)
    for _, fat_ledger in iter_external_inv() do
        local ledger = fat_ledger.ledger
        quantity = quantity + ledger:howMany(lable, name)
    end
    return quantity
end

local function smaller_than(a,b) return a < b end
local function bigger_than(a,b) return a > b end

-- In place (insertion?) sort, smallest to biggest!
local function sort_table_indexed(tbl, reverse, cmp_index)
    -- reverse == false then smallest to biggest
    -- reverse == true then biggest to smallest

    local cmp
    if reverse == nil or reverse == false then cmp = bigger_than
    else cmp = smaller_than end

    for head = 2, #tbl do
        local key = tbl[head]

        local t_index = head - 1
        while t_index >= 1 and cmp(tbl[t_index][cmp_index], key[cmp_index]) do
            tbl[t_index + 1] = tbl[t_index]
            t_index = t_index - 1
        end

        tbl[t_index + 1] = key
    end
end

local max_combined_travel = 512 + 128
-- The ammount of free space in the inventory should also be determinant
function module.get_nearest_inv_by_definition(lable, name, empty_slots_needed)
    if empty_slots_needed == nil then empty_slots_needed = 1 end

    local function check_and_add_to_tbl(tbl, fat_inv)
        local v_distance = fat_inv:getDistance() / max_combined_travel
        if v_distance > 1 then return end

        --[[local v_inv_space = fat_inv.ledger:getNumOfEmptySlots() / fat_inv.ledger.inv_size

        local cmp_value = d_distance * 0.80 + v_inv_space * 0.20
        if cmp_value > 1 then cmp_value = 1.0 end--]]
        if empty_slots_needed > fat_inv.ledger:getNumOfEmptySlots() then return end

        local cmp_value = v_distance
        local cmp_pair = {fat_inv, cmp_value}
        table.insert(tbl, cmp_pair)
    end


    local unsorted_inv_table_misc = {}
    local unsorted_inv_table = {}
    for _, fat_inv in iter_external_inv() do
        if not fat_inv.long_term_storage or not fat_inv.storage then
            goto continue
        end

        if fat_inv:canAdd(lable, name) then
            check_and_add_to_tbl(unsorted_inv_table, fat_inv)
            goto continue
        end
        if fat_inv:canAny() then
            check_and_add_to_tbl(unsorted_inv_table_misc, fat_inv)
            goto continue
        end

        ::continue::
    end

    -- Now we sort by the cmp value, a scaled value of distance and inventory space
    local sorted_inv_table
    if #unsorted_inv_table > 0 then
        sort_table_indexed(unsorted_inv_table, false, 2)
        sorted_inv_table = unsorted_inv_table
    elseif #unsorted_inv_table_misc > 0 then
        sort_table_indexed(unsorted_inv_table_misc, false, 2)
        sorted_inv_table = unsorted_inv_table_misc
    else
        return nil
    end

    local first_entry = sorted_inv_table[1]
    return first_entry[1]
end

-- No, I'm not going to solve the travelling salesman problem
function module.get_nearest_external_inv(lable, name, min_quantity, total_needed_quantity)
    -- ordered with biggest in the top position (#size - 1)
    local ref_quant_table = {}
    for _, fat_inv in iter_external_inv() do
        local pinv = fat_inv.ledger

        local quantity = pinv:howMany(lable, name)
        if quantity == nil or quantity < min_quantity then goto continue end
        local new_ref_quant = {quantity, fat_inv}

        if #ref_quant_table == 0 then table.insert(ref_quant_table, new_ref_quant); goto continue end
        local distance = fat_inv:getDistance()

        for index, entry in ipairs(ref_quant_table) do
            -- local i_quantity = entry[1]
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
    if #ref_quant_table == 0 then return nil end

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
    -- remembered to account for internal inventory
    quant_sum = quant_sum + module.how_many_internal(lable, name)
    if dist_sum > max_combined_travel or quant_sum < total_needed_quantity then return nil end

    -- we'll be recomputing the table for everystep but who cares?
    return ref_quant_table[#ref_quant_table][2] -- returns a MetaExternalInventory object
end

function module.print_build_inventory(map, uncompressed, name, index)
    local build_table = map.get_buildings(name)
    if build_table == nil then
        print(comms.robot_send("error", "No building with such a name exists/is built: " .. name))
        return
    end

    local build = build_table[index]
    if build == nil then
        if index <= 0 then build = build_table[1]
        elseif index > #build_table then build = build_table[#build_table]
        else error(comms.robot_send("fatal", "No Bueno!")) end
    end

    local looped = false
    local pp_obj = {}
    local inv_table = build:getInventories()
    for i, inv in ipairs(inv_table) do
        looped = true
        prepare_pp_print(uncompressed, inv, i, #inv_table, pp_obj)
    end

    if not looped then
        print(comms.robot_send("error", "Print Build Inventory, did not go into loop?!"))
        return
    end
    do_pp_print(pp_obj)
end

-- building index is relative to distance to building, where <1 is the nearest and #size> is the furthest
-- this is like this because I cannot be arsed to do better, and most additions/removings will not happen
-- through this interface, but rather directly through direct building interaction and building
-- agnostic direct inventory interaction, no point messing around with the data structuring just to
-- help out this very minor debug-ish function
function module.add_to_inventory(map, build_name, index, lable, name, quantity, slot_num)
    local build_table = map.get_buildings(build_name)
    if build_table == nil then
        print(comms.robot_send("error", "No building exists with such a name: " .. build_name))
        return false
    end

    local build = build_table[index]
    if build == nil then
        print(comms.robot_send("error", "Index for building_table is invalid! Index: " .. index))
        return false
    end

    local misc_list = {}
    local can_add_inv = nil
    for i = 2, #build.post_build_state, 1 do
        local state = build.post_build_state[i]
        if state == nil then goto continue end
        -- search_table.print_structure(state, "state")

        local inv_table = state[1]
        if inv_table == nil then goto continue end
        -- search_table.print_structure(inv_table, "inv_table")

        for _, inv in ipairs(inv_table) do
            if inv.storage == nil then goto short_continue end
            -- search_table.print_structure(inv, "inv")

            if inv:canAdd(lable, name) then
                can_add_inv = inv
                break
            end
            if inv:canAny() then table.insert(misc_list, inv) end

            ::short_continue::
        end

        if can_add_inv ~= nil then break end
        ::continue::
    end

    if can_add_inv == nil then
       if #misc_list == 0 then
            print(comms.robot_send("error", "There is no valid inventory in this building for this item: " .. name .. ", " .. lable))
            return false
        end -- listen, this is all very kludgy because I don't care rn

        can_add_inv = misc_list[1]
    end

    -- Remember, (inv) is a fat_ledger
    local v_inv = can_add_inv.ledger
    if slot_num == nil then
        v_inv:addOrCreate(lable, name, quantity)
    else
        v_inv:forceUpdateSlot(lable, name, quantity, slot_num)
    end

    return true
end

-- inv_index is optional
function module.get_inv_pos(map, bd_name, bd_index, state_index, inv_index)
    state_index = state_index + 1 -- because no.1 is always facking reserved

    local build_table = map.get_buildings(bd_name)
    if build_table == nil then
        print(comms.robot_send("error", "No building with such a name exists/is built: " .. bd_name))
        return false
    end

    local build = build_table[bd_index]
    if build == nil then
        print(comms.robot_send("error", "No building of such a name with such an index: " .. bd_index))
        return false
    end

    local state = build.post_build_state[state_index]
    if state == nil or type(state) ~= "table" or type(state[1]) ~= "table" then
        print(comms.robot_send("error", "No such state index: " .. state_index))
        return false
    end

    if inv_index ~= nil then
        local inv = state[1][inv_index]
        if inv == nil then
            print(comms.robot_send("error", "No such inv index: " .. inv_index))
            return false
        end
        local symbol = inv.symbol
        local coords = inv:getCoords()
        print(comms.robot_send("info", string.format("'%s' = (%d, %d) h:%d", symbol, coords[1], coords[2], coords[3])))

        return true
    end

    local print_buffer = {"\n List: \n"}
    for index, inv in ipairs(state[1]) do
        if inv == nil then goto continue end

        local symbol = inv.symbol
        local coords = inv:getCoords()

        -- temporary debugging thang
        local height = coords[3]
        if height == nil then height = -1 end
        table.insert(print_buffer, string.format("[%d] '%s' = (%d, %d) h:%d\n", index, symbol, coords[1], coords[2], height))

        ::continue::
    end
    print(comms.robot_send("info", table.concat(print_buffer)))
    return true
end


---}}}

--->>-- Local Functions --<<-----{{{

local function get_forbidden_table()
    if use_self_craft then return crafting_table_slots end
    return nil
end

----}}}


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

    local slot, skip_equip = module.virtual_inventory:equipSomething(tool_type, tool_level, get_forbidden_table())
    -- Equip required tool if found else return false
    if slot == nil then return false end

    local result = true
    if not skip_equip then
        robot.select(slot)
        result = inventory.equip()
        robot.select(1)
    end

    return result
end

function module.smart_swing(tool_name, dir, needed_level, maybe_added_func)
    if maybe_added_func == nil then maybe_added_func = module.maybe_something_added_to_inv end
    if needed_level == nil or needed_level < 0 then needed_level = 0 end

    local swing_func, blind_func, detect_func
    if dir == "front" then
        swing_func = robot.swing
        blind_func = module.blind_swing_front
        detect_func = robot.detect
    elseif dir == "up" then
        swing_func = robot.swingUp
        blind_func = module.blind_swing_up
        detect_func = robot.detectUp
    elseif dir == "down" then
        swing_func = robot.swingDown
        blind_func = module.blind_swing_down
        detect_func = robot.detectDown
    else
        if dir == nil then dir = "nil" end
        print(comms.robot_send("warning", "Bad smart_swing direction: " .. dir))
        return module.smart_swing("front", needed_level, maybe_added_func)
    end


    local result = module.equip_tool(tool_name, needed_level)
    if not result then
        if tool_name == nil then tool_name = "nil" end
        print(comms.robot_send("error", "Failed to equip " .. tool_name ..  "with needed level in mining: " .. needed_level))
        return false
    end

    local detect, _ = detect_func()
    if not detect then return true end

    local result, _ = swing_func()
    if not result then
        result = blind_func()
        if not result then
            return false
        end
    else
        maybe_added_func()
    end
    return true
end

-- These blind swing this are pretty much only needed if you don't know what you're swinging at
local function swing_general(swing_function, dir, pre_analysis)
    local g_info
    if pre_analysis ~= nil then
        g_info = pre_analysis
    else
        g_info = geolyzer.simple_return(dir) -- hopefully this dir is relative to robot, run some tests
    end

    -- TODO: check if we really need to check for air, prob idk
    if g_info == nil or g_info.name == "minecraft:air" then return true end -- returning true is more ideomatic, I think.

    local needed_level = g_info.harvestLevel
    local needed_tool = g_info.harvestTool

    -- needed to normalise some geolyzer intricacies
    if needed_tool == nil then
        needed_level = 0
        needed_tool = "empty"
    end

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

local function loop_recurse(dir, identifier, intended_lable_type, side)
    for _, sub_id in ipairs(identifier) do
        if module.place_block(dir, sub_id, intended_lable_type, side) then -- returns early if success
            return true
        end
    end
    return false
end

-- remember that because we're stupid, our own "lable" is lable, but the lable from
-- an item representation provided from OC is american "label"
--
-- TODO expand block searching in such a way that it beats duplicate lables
function module.place_block(dir, block_identifier, lable_type, side)
    -- if side is nil it doesn't matter
    if side ~= nil then side = sides_api[side] end

    local b_lable = nil
    local b_name = nil
    if type(block_identifier) == "table" and lable_type ~= "name_table" and lable_type ~= "lable_table" and lable_type ~= "table_table" then
        b_lable = block_identifier.lable
        b_name = block_identifier.name
    else
        if lable_type == "name" then
            b_name = block_identifier
        elseif lable_type == "lable" then
            b_lable = block_identifier
        elseif lable_type == "table_table" then
            return loop_recurse(dir, block_identifier, "table", side)
        elseif lable_type == "name_table" then
            return loop_recurse(dir, block_identifier, "name", side)
        elseif lable_type == "lable_table" then
            return loop_recurse(dir, block_identifier, "lable", side)
        elseif lable_type == "table" then
            error(comms.robot_send("fatal", "It was supposed to be a table"))
        else
            error(comms.robot_send("fatal", "lable_type is not valid"))
        end
    end

    if b_lable == "air" or b_lable == "Air" then
        local swing_result
        if dir == "up" then
            if b_name ~= nil and b_name ~= "generic" and b_name ~= "nil" then
                swing_result = module.smart_swing(b_name, dir, 0, nil)
            else
                swing_result = module.blind_swing_up()
            end
        elseif dir == "down" then
            if b_name ~= nil and b_name ~= "generic" and b_name ~= "nil" then
                swing_result = module.smart_swing(b_name, dir, 0, nil)
            else
                swing_result = module.blind_swing_down()
            end
        else print(comms.robot_send("warning", "place_block, punching air in: invalid dir for now")) end
        return swing_result
    end

    local slot = module.virtual_inventory:getSmallestSlot(b_lable, b_name)
    if slot == nil then
        print(comms.robot_send("debug", "couldn't find id: \"" .. block_identifier .. "\" lable -- " .. lable_type))
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

-- if matching_slots is nil, return early and falsy, for sucking all use suck all, dummy
function module.suck_vinventory(external_inventory, left_to_suck, matching_slots)
    local inv_table = external_inventory.ledger.inv_table
    for index = 1, #inv_table, 3 do
        local external_slot = (index + 2) / 3
        if matching_slots ~= nil and not search_table.ione(matching_slots, external_slot) then goto continue end

        -- isto devia ter tido o EMPTY_STRING check há que tempos chavlo fds
        local lable = inv_table[index]
        local name = inv_table[index + 1]
        local quantity = inv_table[index + 2]
        -- there is no quick and easy check we can do :(

        local cur_suck_quantity
        -- I'm going to trust it is this simple, because the way the api's "suck into slot" and our
        -- addOrCreate seem to map 1-to-1, if de-syncs start to happen use a smarter solution I guess
        local internal_slot = module.virtual_inventory:getSmallestSlot(lable, name)
        if internal_slot == nil then
            internal_slot = module.virtual_inventory:getEmptySlot(get_forbidden_table())
            cur_suck_quantity = 64
        else
            cur_suck_quantity = 64 - module.virtual_inventory:howManySlot(internal_slot)
        end

        if left_to_suck ~= nil then
            if left_to_suck <= 0 then break end -- HERE is the early return
            local available_quantity = cur_suck_quantity

            local div = math.floor(left_to_suck / available_quantity)
            if div == 0 then cur_suck_quantity = left_to_suck
            elseif div > 0 then cur_suck_quantity = available_quantity
            elseif div < 0 then error(comms.robot_send("fatal", "impossible state")) end
        end

        robot.select(internal_slot)

        if not inventory.suckFromSlot(sides_api.front, external_slot, cur_suck_quantity) then
            -- print(comms.robot_send("error", "An error occuring sucking all vinventory: unable to suck, slot: " .. external_slot))
            goto continue
        end

        local how_much_sucked = math.min(cur_suck_quantity, quantity)
        -- Change the addOrCreate to a forceUpdateInternal if you start running into problems :P, this should be fine tho
        module.virtual_inventory:addOrCreate(lable, name, how_much_sucked, get_forbidden_table())
        external_inventory.ledger:removeFromSlot(external_slot, how_much_sucked)
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

    if inv_type == "ledger" then module.ledger.suck_ledger(external_inventory)
    elseif inv_type == "virtual_inventory" then module.suck_vinventory(external_inventory, nil)
    else error(comms.robot_send("fatal", "(suck_all) this a non-existent ledger/inv type!: " .. inv_type)) end
end

function module.suck_only_named(lable, name, external_inventory, how_much_to_dump)
    local matching_slots = external_inventory:getAllSlots(lable, name, how_much_to_dump)
    return module.suck_only_matching(external_inventory, how_much_to_dump, matching_slots)
end

-- Selects only the sub-selected MetaItems to be sucked
function module.suck_only_matching(external_inventory, quantity, matching)
    local inv_type = external_inventory.ledger.inv_type
    if inv_type == nil then inv_type = "nil" end

    if inv_type == "ledger" then module.suck_ledger(external_inventory, quantity, matching)
    elseif inv_type == "virtual_inventory" then module.suck_vinventory(external_inventory, quantity, matching)
    else error(comms.robot_send("fatal", "(suck_only_matching) this a non-existent ledger/inv type!: " .. inv_type)) end
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

function module.dump_only_named(lable, name, external_inventory, how_much_to_dump, external_slot)
    local matching_slots = module.virtual_inventory:getAllSlots(lable, name)
    return module.dump_only_matching(external_inventory, how_much_to_dump, matching_slots, external_slot)
end

-- if no "up_to" provided dump everything
function module.dump_only_matching(external_inventory, up_to, matching_slots, external_slot)
    if up_to == nil then up_to = 100000 end

    local inv_type = external_inventory.ledger.inv_type
    if inv_type == "ledger" then error(comms.robot_send("fatal", "This is not supported right now")) end
    if matching_slots == nil or #matching_slots == 0 then
        print(comms.robot_send("warning", "dump_only_matching, matching_slots was nil or 0"))
        return false
    end

    for _, entry in ipairs(matching_slots) do
        local slot = entry[1]
        local slot_quantity = entry[2]

        local quantity = math.min(up_to, slot_quantity)

        robot.select(slot)
        if external_slot == nil then
            if not robot.drop(quantity) then
                print(comms.robot_send("warning", string.format("Failed to drop into extern inv. int_slot: %s", slot)))
                goto continue
            end
        else
            local result, err = inventory.dropIntoSlot(sides_api.front, external_slot, quantity)
            if not result then -- API is return error when we succed :(
                --[[print(comms.robot_send("warning",
                    string.format("Failed to drop into extern slot: %s, int_slot: %s || err: %s", external_slot, slot, err)
                ))
                goto continue--]]
            end
        end

        local index = (slot * 3) - 2
        local lable = module.virtual_inventory.inv_table[index]
        local name = module.virtual_inventory.inv_table[index + 1]

        -- add the entry into the external inventory
        if external_inventory == nil or type(external_inventory) ~= "table" then goto continue end
        if external_slot == nil then
            external_inventory.ledger:addOrCreate(lable, name, quantity, nil)
        else
            local _, _, cur_quantity = external_inventory.ledger:getSlotInfo(external_slot)
            external_inventory.ledger:forceUpdateSlot(lable, name, cur_quantity + quantity, external_slot)
            -- then we need to get the next free external slot, duh
            external_slot = external_inventory.ledger:getEmptySlot()
        end

        -- finally remove the entry
        module.virtual_inventory:removeFromSlot(slot, quantity)

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

-- WARNING: WILL have some problems with tools breaking and so on, let's just hope it is able of self-cleaning!
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

            local ingredient_slots = {}
            local accumulator = 0
            local i_slot_tbl = module.virtual_inventory:getAllSlots(lable, name)
            sort_table_indexed(i_slot_tbl, false, 2)
            if i_slot_tbl == nil then -- there has been an woopsie in the crafting/recipe/scripting
                print(comms.robot_send(
                    "error", string.format("While Crafting i_slot_tbl was nil, this means we didn't \z
                    have what we expected inside of the inventory: (l,n) -> (%s, %s)", lable, name)
                ))
                clean_up = true
                break
            end

            for _, inner_slot in ipairs(i_slot_tbl) do
                local slot_size = module.virtual_inventory:howManySlot(inner_slot)
                accumulator = accumulator + slot_size
                table.insert(ingredient_slots, inner_slot)

                if accumulator >= how_much_to_craft then
                    break
                end
            end
            if accumulator < how_much_to_craft then
                clean_up = true
                break
            end

            local reverse_accumulator = how_much_to_craft
            local do_break = false
            for _, i_slot in ipairs(ingredient_slots) do -- usually we'll only iterate once, but we never know!
                local slot_size = module.virtual_inventory:howManySlot(i_slot)
                local to_transfer = math.min(reverse_accumulator, slot_size)

                local result = robot.select(i_slot)
                if result ~= i_slot or not robot.transferTo(c_table_slot, to_transfer) then
                    print(comms.robot_send("error", "something went wrong in self_crafting"))
                    clean_up = true
                    do_break = true
                    break
                end -- else we succeded! (yay!)
                module.virtual_inventory:removeFromSlot(i_slot, to_transfer) -- it's ok to overshoot!
                -- reverse_accumulator = reverse_accumulator - slot_size
                reverse_accumulator = reverse_accumulator - to_transfer
            end
            if reverse_accumulator ~= 0 then print(comms.robot_send("warning", "r_accumulator was: " .. reverse_accumulator)) end
            if do_break then break end
        end
    end -- Then check for errors
    if clean_up then
        print(comms.robot_send("error", "Error while crafting, cleaning up"))
        module.force_update_vinv()
        for index = 1, 12, 1 do
            if index % 4 ~= 0 then module.simple_slot_check(index) end
        end
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
        print(comms.robot_send("error", "failed to craft :("))
        module.force_update_vinv() -- last hurah-ass
        for index = 1, 12, 1 do
            if index % 4 ~= 0 then module.simple_slot_check(index) end
        end

        return false
    end

    -- TODO make it not use getStackInInternalSlot se we're a bit faster (it'll require better recipe programming)
    local stack_rep = inventory.getStackInInternalSlot(output_slot)
    local new_quantity = stack_rep.size

    local update_name = output.name
    local update_lable = output.lable
    if update_name == nil then update_name = stack_rep.name end
    if update_lable == nil then update_lable = stack_rep.label end

    -- Optimistically Update the thingy-majig
    module.virtual_inventory:forceUpdateSlot(update_lable, update_name, new_quantity, output_slot)

    robot.select(1)
    return true
end

-- It seems that we we self_craft this is done in one execution cycle!
function module.craft(arguments)
    local dictionary = arguments[1]
    local recipe_grid = arguments[2]
    local output = arguments[3]
    local how_much = arguments[4]
    local lock_ref = arguments[5]

    if use_self_craft then
        self_craft(dictionary, recipe_grid, output, how_much) -- this returns a result, but we don't care?
        lock_ref[1] = 2
        return nil
    else error(comms.robot_send("fatal", "TODO!")) end
end

---}}}

local function simple_slot_check(slot)
    local quantity = robot.count(slot)
    if quantity > 0 then    -- this is a rare occurence when something fell into the inventory that was not
                            -- there before, or if a stack was already full -> aka rare
        local item = inventory.getStackInInternalSlot(slot)
        local lable = item.label; local name = item.name; local quantity = item.size

        -- make sure that these clear_functions act in the sameway that addorcreate does (i think it does but who knows)
        local new_slot = module.virtual_inventory:getEmptySlot(get_forbidden_table())
        robot.select(slot)
        if robot.transferTo(new_slot) then
            module.virtual_inventory:forceUpdateSlot(EMPTY_STRING, EMPTY_STRING, 0, slot) -- force clear origin slot dih
            module.virtual_inventory:forceUpdateSlot(lable, name, quantity, new_slot)
        else
            print(comms.robot_send("error", "maybe_something_added_to_inv, very bad error"))
        end
    end
    robot.select(1)
end

function module.simple_slot_check(slot) return simple_slot_check(slot) end

function module.maybe_something_added_to_inv(lable_hint, name_hint) -- important to keep crafting table clear
    -- added some bullshit to deal with multiple drops
    simple_slot_check(1)
    simple_slot_check(2)
    simple_slot_check(3)

    local slot_table
    -- [1] - Strict Matching, find this lable, [2] - Name Matching, find all that matches this "bucket"
    -- [3] - We'll have to do it the dumb way
    if lable_hint ~= nil then slot_table = module.virtual_inventory:getAllSlots(lable_hint, name_hint)
    elseif name_hint ~= nil then slot_table = module.virtual_inventory:getAllSlotsPermissive(name_hint)
    else
        module.force_update_vinv()
        return true
    end

    if slot_table == nil then return false end -- now it is ideomatic

    for _, element in ipairs(slot_table) do
        local slot = element[1]
        local expected_quantity = element[2]
        local stack_info = inventory.getStackInInternalSlot(slot)
        -- haha, something did get added (assume only 1 stack at the time so return)
        local diff = expected_quantity - stack_info.size
        if diff > 0 then
            module.virtual_inventory:removeFromSlot(slot, diff)
        elseif diff < 0 then
            module.virtual_inventory:addOrCreate(stack_info.label, stack_info.name, math.abs(diff), get_forbidden_table())
        end -- else all good, keep checking
    end

    return true
end

-- For now this is enough, better interface far in the future
function module.force_set_slot_as(slot, new_lable, new_name, new_quantity)
    if new_lable == nil then return end
    if new_name == nil then new_name = item_bucket.identify(new_name, new_lable) end

    local offset = (slot * 3) - 2
    local inv_table = module.virtual_inventory.inv_table

    inv_table[offset] = new_lable
    inv_table[offset + 1] = new_name
    if new_quantity ~= nil and new_quantity > 0 and new_quantity <= 64 then
        inv_table[offset + 2] = new_quantity
    end
end

function module.force_add_in_slot(slot) -- ahr ahr
    local quantity = robot.count(slot)
    if quantity > 0 then
        local item = inventory.getStackInInternalSlot(slot)
        local name = item.name; local lable = item.label
        module.virtual_inventory:forceUpdateSlot(lable, name, quantity, slot)
    end
    -- Separate out into a function that clears the crafting table for us?
end

function module.remove_from_slot(what_slot, quantity)
    if what_slot == nil or type(what_slot) ~= "number" then
        print(comms.robot_send("error", "failure to remove_from slot"))
        return false
    end
    module.virtual_inventory:removeFromSlot(what_slot, quantity)

    return true
end

function module.force_update_vinv()
    local result = module.virtual_inventory:forceUpdateInternal()
    for index = 1, 12, 1 do
        if index % 4 ~= 0 then module.simple_slot_check(index) end
    end
    return result
end

function module.force_update_einv(external_inventory)
    return external_inventory.ledger:forceUpdateAsForeign()
end

local function press_enter()
    print(comms.robot_send("info", "Press Enter to continue"))
    io.read()
end

-- temp thing to get us going
function module.load_preset(map)
    module.force_update_vinv()
    -- if not module.add_to_inventory(map, "sp_storeroom", 1, "Flint", "minecraft:generic", 31, 1) then press_enter() end
    -- if not module.add_to_inventory(map, "sp_storeroom", 1, "Oak Wood", "any:log", 31, 1) then press_enter() end
end

return module
