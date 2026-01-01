local sides_api = require("sides")

local inventory_controller = {}
local robot_rep

function inventory_controller.setRobotRep(robot_rep_)
    robot_rep = robot_rep_
end

function inventory_controller.getInventorySize()
    return #robot_rep.inventory.inner
end

function inventory_controller.getStackInSlot(side, slot_num)
    local block = robot_rep.world:getBlockRelSide(robot_rep, sides_api[side])
    if block.inventory ~= nil then
        return block.inventory:getSlot(slot_num)
    end

    return nil
end
function inventory_controller.getStackInInternalSlot(slot_num)
    return robot_rep.inventory:getSlotInfo(slot_num)
end

function inventory_controller.dropIntoSlot(side, slot_num, count)
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(robot_rep.position, sides_api[side])
    if block.inventory ~= nil then
        return robot_rep:dropIntoSlot(block, slot_num, count)
    end

    return false, "No Inventory"
end
function inventory_controller.suckFromSlot(side, slot_num, count)
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(robot_rep.position, sides_api[side])
    if block.inventory ~= nil then
        return robot_rep:dropIntoSlot(block, slot_num, count)
    end

    return false, "No Inventory"
end

function inventory_controller.equip()
    robot_rep:equip()
end

return inventory_controller
