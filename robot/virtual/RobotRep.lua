local deep_copy = require("deep_copy")
local Inventory = require("virtual.Inventory")

-- Mostly used to mapover component behaviour
local RobotGlobals = {

}

local RobotRep = {}
function RobotRep:new(world)
    local new = COPY(self)

    new.world = world

    new.equiped_item = nil
    new.inventory = Inventory:new()
    new.position = {0, 0, 0}
    new.orientation = "north",

    new.selected_slot = 1

    return new
end
function RobotRep:setPosition(x, z, y)
    if type(x) ~= "number" or type(z) ~= "number" or type(y) ~= "number" then
        error("Tried to setPosition to something that is not a number") 
    end

    self.position[1] = x
    self.position[2] = z
    self.position[3] = y
end

function RobotRep:getPosition()
    return self.position[1], self.position[2], self.position[3]
end

function RobotRep:dropIntoSlot(block, slot_num, count)
    if slot_num > #block.inventory.inner or slot_num < 1 then
        return false, "External Slot Number is Invalid"
    end
    if self.inventory:getSlot(self.selected_slot).is_empty then
        return false, "Nothing to be Droped in Selected Slot"
    end

    local item_info = self.inventory:getSlotInfo(self.selected_slot)
    local removed = self.inventory:removeFromSlot(self.selected_slot, count)
    local added = block.inventory:addToSlot(item_info, slot_num, removed)

    -- If we added less than we removed, for whatever reason, re-add
    local diff = math.abs(removed - added)
    self.inventory:addToSlot(slot_num, diff)

    return true
end

function RobotRep:suckIntoSlot(block, slot_num, count)
    if slot_num > #block.inventory.inner or slot_num < 1 then
        return false, "External Slot Number is Invalid"
    end
    if block.inventory:getSlot(self.selected_slot).is_empty then
        return false, "Nothing to be Sucked in Selected Slot"
    end

    local item_info = block.inventory:getSlotInfo(slot_num)
    local removed = block.inventory:removeFromSlot(slot_num, count)
    local added = self.inventory:addToSlot(item_info, self.selected_slot, removed)

    local diff = math.abs(removed - added)
    block.inventory:addToSlot(slot_num, diff)

    return true
end

function RobotRep:suckItem(item_info)
    return self.inventory:addItem(item_info) 
end

function RobotRep:equip()
    local i_item_info = self.inventory:overwriteSlot(e_item_info, self.selected_slot)
    self.equiped_item = i_item_info
end

-- After we "digitise" recipes we hook this up, until then just don't run any crafting related tests
function RobotRep:craft(count)
    error("Attempted to craft, TODO!")     
end


return RobotRep
