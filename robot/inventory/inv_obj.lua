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

local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))
local crafting = component.getPrimary("crafting")
local inventory = component.getPrimary("inventory_controller")

-- forbiden slots (because of crafting table) = 1,2,3 -- 5,6,7 -- 9,10,11
-- this means actual internal inventory size while crafing mode is true is == 7
local forbidden_slots = {1,2,3, -1, 5,6,7, -1, 9,10,11}

--->>-- Ledger Shit --<<-----

local internal_ledger = {}  -- using just the lables should be fine, but I'll keep "name" here because
                            -- it might become useful in the future
--init_ledger()
for _, bucket in ipairs(item_buckets) do
    internal_ledger[bucket] = {}
end

local function i_ledger_add_or_create(name, lable, quantity)
    --if string.find(name, "gt.metaitem") then -- the question of meta-items is complex and I gave it thought
    local bucket = bucket_functions.identify(name, lable)

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

            if reconstruct == block_id then
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

--->>-- Tool Use --<<-----
function module.equip_tool(tool_type)
    --TODO do things
    return true
end


--->>-- Block Placing --<<----
function module.place_block(dir, block_identifier, lable_type)
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

local use_self_craft = true
function module.isCraftActive()
    return use_self_craft
end

function module.blindSwingFront()
    local result = robot.swing()
    module.maybe_something_added_to_inv()
    return result
end

function module.blindSwingDown()
    local result = robot.swingDown()
    module.maybe_something_added_to_inv()
    return result
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
local crafting_table_clear = false
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
         local result = clear_first_slot(non_craft_slot_iter)
         if not result then
            crafting_table_clear = false
            return false
         end
         return true
    end
    return clear_first_slot(free_slot_iter)
end

function clear_first_slot(iter)
    local real_size = inventory_size - 9
    if robot.count(1) == 0 then return true end -- nothing needs to be done

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

    robot.select(1)
    robot.transferTo(slot_num)
    return true
end

function non_craft_slot_iter()
    local iteration = used_up_capacity
    return function ()
        iteration = iteration + 1
        if iteration > inventory_size then
            return nil
        end
        
        local cur_f = forbidden_slots[iteration]
        if cur_f ~= nil or cur_f ~= -1 then
            return -1 
        end

        return iteration
    end
end

function free_slot_iter()
    local iteration = used_up_capacity + 1 -- spares first slot, meaningless logically

    return function ()
        iteration = iteration + 1
        if iteration > inventory_size then
            return nil
        end

        return iteration
    end
end

return module
