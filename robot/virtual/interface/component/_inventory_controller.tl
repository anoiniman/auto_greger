local sides_api = require("sides")

local record inventory_controller end
local robot_rep: RobotRep

function inventory_controller.setRobotRep(robot_rep_: RobotRep)
    robot_rep = robot_rep_
end

function inventory_controller.getInventorySize(): integer
    return #robot_rep.inventory.inner
end

function inventory_controller.getStackInSlot(side: string | integer, slot_num: integer): SlotInfo | nil
    local block = robot_rep.world:getBlockRelSide(sides_api[side])
    if block.inventory ~= nil then
        return block.inventory:getSlot(slot_num)
    end

    return nil
end
function inventory_controller.getStackInInternalSlot(slot_num: integer): SlotInfo
    return robot_rep.inventory:getSlotInfo(slot_num)
end

function inventory_controller.dropIntoSlot(side: string | integer, slot_num: integer, count: integer): boolean, string | nil
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(sides_api[side])
    if block.inventory ~= nil then
        return robot_rep:dropIntoSlot(block, slot_num, count)
    end

    return false, "No Inventory"
end
function inventory_controller.suckFromSlot(side: string | integer, slot_num: integer, count: integer): boolean, string | nil
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(sides_api[side])
    if block.inventory ~= nil then
        return robot_rep:dropIntoSlot(block, slot_num, count)
    end

    return false, "No Inventory"
end

function inventory_controller.equip()
    robot_rep:equip()
end

return inventory_controller
