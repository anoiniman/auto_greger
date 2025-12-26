local RobotRep = require("RobotRep")
local event = require("event")
local sides_api = require("sides")

local Tunnel = {}
--[[local mm_core = {
    "localAddr",
    "remoteAddr",
    6969,
    255,
}
event.addToList("modem_message", mm_core)--]]
function Tunnel.send() -- should be enough since we print either way
    return
end

local InventoryController = {}
function InventoryController.getInventorySize(robot_rep)
    return #robot_rep.inventory.inner
end

function InventoryController.getStackInSlot(robot_rep, side, slot_num)
    local block = robot_rep.world:getBlockRelSide(robot_rep.position, sides_api[side])
    if block.inventory ~= nil then
        return block.inventory:getSlot(slot_num)
    end

    return nil
end
function InventoryController.getStackInInternalSlot(robot_rep, slot_num)
    return robot_rep.inventory:getSlotInfo(slot_num)
end

function dropIntoSlot(robot_rep, side, slot_num, count)
    count = count or 64
    local block = robot_rep.world:getBlockRelSide(robot_rep.position, sides_api[side])
    if block.inventory ~= nil then
        return robot_rep:dropIntoSlot(block, slot_num, count)
    end

    return false, "No Inventory"
end
function suckFromSlot(robot_rep, side, slot_num, count)
    count = count or 64
    error("TODO")
end

local component_list = {
    inventory_controller = InventoryController,
    crafting = nil,
    tractor_beam = nil,
    geolyzer = nil,
    generator = nil,

    tunnel = Tunnel,
}

local component = {}

function component.getPrimary(name)
    return component_list[name]
end

return component
