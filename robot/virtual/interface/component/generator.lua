require("deep_copy")
local Inventory = require("virtual.Inventory")

local generator = { }
local robot_rep

function generator.setRobotRep(robot_rep_)
    generator.inventory = Inventory:special(1)
    robot_rep = robot_rep_
end

function generator.count()
    if generator.inner == nil then
        return 0
    end
    return generator.inner.size
end

function generator.insert(count)
    local item_info = robot_rep.inventory:getSlotInfo(robot_rep.selected_slot)
    -- First we need to check if the thing we're trying to insert is fuel (TODO)
    -- For now we'll pretend everything is fuel, and pretend that fuel and energy is not a thing

    if generator.inventory.inner[1].is_empty then
        local removed = robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, count)
        generator.inventory:addToSlot(item_info, 1, removed)

        return true
    end

    if not generator.inventory:isItemSame(item_info, 1) then
        return false, "Item is not same"
    end

    local removed = robot_rep.inventory:removeFromSlot(robot_rep.selected_slot, count)
    local added = generator.inventory:addToSlot(item_info, 1, removed)
    local diff = removed - added
    robot_rep.inventory:addToSlot(item_info, robot_rep.selected_slot, diff)
end

-- "Removes up to the specified number of fuel items from the generator and places
-- them into the currently selected slot or the first free slot after it."
function generator.remove(count)
    if generator.inventory.inner[1].is_empty then return false, "Generator is Empty" end

    local item_info = generator.inventory:getSlotInfo(1)
    if not robot_rep.inventory:isItemSame(item_info, robot_rep.selected_slot) then
        return false, "Item is not same in selected slot"
    end

    local removed = generator.inventory:removeFromSlot(1, count)
    local added = robot_rep.inventory:addToSlot(item_info, robot_rep.selected_slot, removed)
    local diff = removed - added
    generator.inventory:addToSlot(item_info, 1, diff)

    local try_slot = robot_rep.selected_slot + 1
    while try_slot <= 32 do
        if robot_rep.inventory:isSlotEmpty(try_slot) then
            generator.inventory:removeFromSlot(1, diff)
            robot_rep.inventory:addToSlot(item_info, try_slot, diff)
            return true
        end
    end
    return false, "Ran out of inventory slots"
end

return generator
