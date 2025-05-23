local module = {}
-- I'll assume we have 32 slots (2-inventory upgrades) because otherwise it is just to small dog :sob:
-- Or we'll stay with 16 slots with the expectation that we abandon internal crafting quickly, idk
local inventory_size = 32
local used_up_capacity = 0

local component = require("component")
local sides_api = require("sides")
local robot = require("robot")
local text = require("text")

local deep_copy = require("deep_copy")
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))
local crafting = component.getPrimary("crafting")
local inventory = component.getPrimary("inventory_controller")

-- forbiden slots (because of crafting table) = 1,2,3 -- 5,6,7 -- 9,10,11
-- this means actual internal inventory size while crafing mode is true is == 7
local crafting_table_slots = {1,2,3, -1, 5,6,7, -1, 9,10,11}
local tool_belt_slots = {}

local crafting_table_clear = false
local use_self_craft = true

local SlotDefinition = {
    slot_number = nil,
    material = nil,
    item_name = nil,
    item_level = nil,
}
--function SlotDefinition:newFromCurrent(slot_numbers, material, item_name, item_level)

-- slot_numbers, might actually be a non-table number!
function SlotDefinition:new(slot_number, item_name)
    local new = deep_copy.copy(self, pairs)
    new.slot_number = slot_number
    new.material = "none"
    new.item_name = item_name
    new.item_level = -1

    table.insert(tool_belt_slots, slot_number) -- important

    return new
end

local slot_managed = {}
local slot_manager = {}
function slot_manager.add(obj)
    if obj.item_name ~= nil then
        local name = obj.item_name
        if slot_managed[name] == nil then slot_managed[name] = {} end
        table.insert(slot_managed[name], obj)
        return
    end

    for _, definition in ipairs(obj) do
        local name = definition.item_name
        if slot_managed[name] == nil then slot_managed[name] = {} end
        table.insert(slot_managed[name], definition)
    end
end

function slot_manager.find_all(item_name, level)
    local return_table = {}
    for _, multi_def in pairs(slot_managed) do
        for _, def in pairs(multi_def) do
            if def.item_name == item_name and def.item_level >= level then
                table.insert(return_table, def)
            end
        end
    end
    if #return_table > 0 then return return_table end
    return nil
end

-- I think this is fine
function slot_manager.find_slot(item_name, level) -- returns a slot number
    local result = slot_manager.find_all(item_name, level)
    return result[1].slot_number
end

function slot_manager.find_empty_slot(item_name) -- returns a slot number
    -- This filters two times, but the performance drop is acceptable
    local result = slot_manager.find_all(item_name, -1)
    for _, def in ipairs(result) do
        if def.item_level == -1 then
            return def.slot_number
        end
    end
    return nil
end

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


--->>-- Iterator Shit --<<-----
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


--->>-- Ledger Shit --<<-----

local special_ledger = {} -- ledger for things that have a definition, rather than just a lable/and_or/name
local function s_ledger_add_or_create()
 -- TODO
end

local internal_ledger = {}  -- using just the lables should be fine, but I'll keep "name" here because
                            -- it might become useful in the future
--init_ledger()
for _, bucket in ipairs(item_buckets) do
    internal_ledger[bucket] = {}
end

local function i_ledger_add_or_create(name, lable, quantity)
    --if string.find(name, "gt.metaitem") then -- the question of meta-items is complex and I gave it thought
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special ~= nil then
        s_ledger_add_or_create()
        return
    end

    local entry_quantity = internal_ledger[bucket][lable]
    if entry_quantity == nil then
        internal_ledger[bucket][lable] = quantity
        return
    end
    internal_ledger[bucket][lable] = entry_quantity + quantity
end

local function find_in_slot(block_id, lable_type)
    if lable_type == "lable" then
        for index = 1, inventory_size, 1 do
            local item = inventory.getStackInInternalSlot(index)
            if item == nil then goto continue end

            -- This is needed because dictionary translation seems to mangle spaces
            -- this will destroy spaces to allow for comparison
            local split = text.tokenize(item.label)
            local reconstruct = table.concat(split)

            -- somehow, now that we have BuildInstruction it doesn't get mangled???
            if reconstruct == block_id or item.label == block_id then
                return index
            end

            ::continue::
        end
    elseif lable_type == "name" then
        print(comms.robot_send("error", "inv_obj: not valid lable_type"))
        return -2
    else
        print(comms.robot_send("error", "inv_obj: not valid lable_type"))
        return -2
    end

    return -1 -- in case nothing was found
end

-->>-- Useful shit? --<<--

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

--->>-- Tool Use --<<-----
-- Assume that the tools are in their correct slots at all the times, it is not the responsibility
-- of this function to make sure that the items are in the desitred slot, unless of course, the
-- thing is about returning currently equiped tools to the correct slot
function module.equip_tool(tool_type, wanted_level)
    local slot = slot_manager.find(tool_type, wanted_level)
    if slot == nil then return false end
    robot.select(slot)
    local result = inventory.equip()

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

local function swing_general(swing_function, dir)
    local g_info = geolyzer.simple_return(dir) -- hopefully this dir is relative to robot, run some tests
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

    return result
end

function module.blind_swing_front()
    return swing_general(robot.swing, sides_api.front)
end

function module.blind_swing_down()
    return swing_general(robot.swingDown, sides_api.down)
end

function module.blind_swing_up()
    return swing_general(robot.swingUp, sides_api.up)
end

--->>-- Block Placing --<<----
function module.place_block(dir, block_identifier, lable_type)
    if type(block_identifier) == "table" then
        if lable_type == "lable" then block_identifier = block_identifier.lable
        elseif lable_type == "name" then block_identifier = block_identifier.name
        else block_identifier = "invalid \"lable_type\"" end
    end

    local slot = find_in_slot(block_identifier, lable_type)
    if slot == -1 then
        print(comms.robot_send("warning", "couldn't find id: \"" .. block_identifier .. "\" lable -- " .. lable_type))
        return false
    elseif slot < -1 then
        return false
    end

    robot.select(slot)

    if dir == "down" then
        robot.placeDown()
    else
        print(comms.robot_send("error", "not yet implemented, inv_obj.place_block"))
        robot.select(1)
        return false
    end

    robot.select(1)
    return true
end


--TODO interaction with external inventories and storage inventories

--->>-- Crafter Shit --<<-----

function module.isCraftActive()
    return use_self_craft
end

function module.debug_force_add()
    for i in free_slot_iter() do
        local quantity = robot.count(i)
        if quantity == 0 then goto continue end

        local item = inventory.getStackInInternalSlot(i)
        local name = item.name; local lable = item.label
        i_ledger_add_or_create(name, lable, quantity)

        ::continue::
    end
end

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
        i_ledger_add_or_create(name, lable, quantity)
    end

    if use_self_craft then
         return clear_first_slot(non_craft_slot_iter)
    end
    return clear_first_slot(free_slot_iter)
end



return module
