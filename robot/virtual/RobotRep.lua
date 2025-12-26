local deep_copy = require("deep_copy")
local Inventory = require("Inventory")

-- Mostly used to mapover component behaviour
local RobotGlobals = {

}

local RobotRep = {}
function RobotRep:new(world)
    local new = COPY(self)

    new.world = world

    new.equiped_tool = nil
    new.inventory = Inventory:new()
    new.position = {0, 0, 0}

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
    local diff = removed - added
    self.inventory:addToSlot(slot_num, diff)

    return true
end

-- Global robot funcs must follow the following interface:
-- (func_name = function (robot_rep, <Other Argumnets>))
function RobotRep:addGlobal(name, func_table)
    RobotGlobals[name] = func_table
end

return RobotRep
