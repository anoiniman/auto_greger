local module = {}
-- I'll assume we have 32 slots (2-inventory upgrades) because otherwise it is just to small dog :sob:
-- Or we'll stay with 16 slots with the expectation that we abandon internal crafting quickly, idk
local inventory_size = 16
local used_up_capacity = 0

local component = require("component")
local sides_api = require("sides")
local robot = require("robot")

local crafting = component.getPrimary("crafting")
local inventory = component.getPrimary("inventory_controller")

-- forbiden slots (because of crafting table) = 1,2,3 -- 5,6,7 -- 9,10,11
-- this means actual internal inventory size while crafing mode is true is == 7
local forbidden_slots = {1,2,3, -1, 5,6,7, -1, 9,10,11}

local use_self_craft = true
function module:is_craft_active()
    return self.use_self_craft
end

-- Hopefully robot.count == 0 works in detecting empty slots, otherwise.... woppps sorry
local crafting_table_clear = false
function module.maybe_something_added_to_inv() -- important to keep crafting table clear
    if used_up_capacity >= inventory_size then
        return false
    end

    if robot.count(1) > 0 then
        used_up_capacity = used_up_capacity + 1        
    end

    if use_self_craft then
         return clear_first_slot(non_craft_slot_iter)
    end
    return clear_first_slot(free_slot_iter)
end

local function clear_first_slot(iter)
    local real_size = inventory_size - 9
    if robot.count(1) == 0 then return true end -- nothing needs to be done

    local free_slot = nil
    for slot_num in iter(used_up_capacity, inventory_size) do
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

local function non_craft_slot_iter(cur_size, max_size)
    local iteration = cur_size + 1 -- +1 so that we always try to keep slot 1 free, (logically meaningless)
    return function ()
        iteration = iteration + 1
        if iteration > max_size then
            return nil
        end
        
        local cur_f = forbidden_slots[iteration]
        if cur_f ~= nil or cur_f ~= -1 then
            return -1 
        end

        return iteration
    end
end

local function free_slot_iter(cur_size, max_size) local iteration = cur_size
    local iteration = cur_size + 1

    return function ()
        iteration = iteration + 1
        if iteration > max_size then
            return nil
        end
        

        return iteration
    end
end

return module
