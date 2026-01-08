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

function RobotRep:transferTo(slot_num, count)
    local to_entry = self.inventory:getSlot(slot_num)
    local from_entry = self.inventory:getSlot(self.selected_slot)
    
    if from_entry.empty then return false end

    local item_info = from_entry.item
    if not self.inventory:isItemSame(item_info, slot_num) then return false end

    local removed = self.inventory:removeFromSlot(self.selected_slot, count)
    local added = self.inventory:addToSlot(item_info, slot_num, removed)
    local diff = math.abs(removed - added)
    self.inventory:addToSlot(self.selected_slot, diff)

    return true
end

function RobotRep:dropIntoSlot(block, slot_num, count)
    if slot_num > #block.inventory.inner or slot_num < 1 then
        return false, "External Slot Number is Invalid"
    end
    if self.inventory:isSlotEmpty(self.selected_slot) then
        return false, "Nothing to be Droped in Selected Slot"
    end

    local item_info = self.inventory:getSlotInfo(self.selected_slot)
    if not block.inventory:isItemSame(item_info, slot_num) then return false, "Invalid Item Mixing" end

    local removed = self.inventory:removeFromSlot(self.selected_slot, count)
    local added = block.inventory:addToSlot(item_info, slot_num, removed)
    local diff = math.abs(removed - added)
    self.inventory:addToSlot(self.selected_slot, diff)

    return true
end

function RobotRep:suckIntoSlot(block, slot_num, count)
    if slot_num > #block.inventory.inner or slot_num < 1 then
        return false, "External Slot Number is Invalid"
    end
    if block.inventory:isSlotEmpty(self.selected_slot) then
        return false, "Nothing to be Sucked in Selected Slot"
    end

    local item_info = block.inventory:getSlotInfo(slot_num)
    -- Check for impossible to add, if it was impossible revert and return false
    if not self.inventory:isItemSame(item_info, self.selected_slot) then
        return false, "Invalid Item Mixing"
    end

    local removed = block.inventory:removeFromSlot(slot_num, count)
    local added = self.inventory:addToSlot(item_info, self.selected_slot, removed)
    local diff = math.abs(removed - added)
    block.inventory:addToSlot(slot_num, diff)

    return true
end

function RobotRep:suckItem(item_info)
    local bool, removed = self.inventory:addItem(item_info) 
    return bool
end

function RobotRep:equip()
    local i_item_info = self.inventory:overwriteSlot(e_item_info, self.selected_slot)
    self.equiped_item = i_item_info
end


-- TODO After we "digitise" recipes we hook this up, until then just don't run any crafting related tests
function RobotRep:craft(count)
    error("Attempted to craft, TODO!")     
end

function RobotRep:forward()
    local ori = self.orientation
    if ori == "north" then
        self.position[2] = self.position[2] - 1
    elseif ori == "south" then
        self.position[2] = self.position[2] + 1
    elseif ori == "west" then
        self.position[1] = self.position[1] - 1
    elseif ori == "east" then
        self.position[1] = self.position[1] + 1
    end
end

function RobotRep:back()
    local ori = self.orientation
    if ori == "north" then
        self.position[2] = self.position[2] + 1
    elseif ori == "south" then
        self.position[2] = self.position[2] - 1
    elseif ori == "west" then
        self.position[1] = self.position[1] + 1
    elseif ori == "east" then
        self.position[1] = self.position[1] - 1
    end
end

function RobotRep:up() self.position[3] = self.position[3] + 1 end
function RobotRep:down() self.position[3] = self.position[3] - 1 end

function RobotRep:turnLeft()
    local ori = self.orientation
    if ori == "north" then ori = "west"
    elseif ori == "west" then ori = "south"
    elseif ori == "south" then ori = "east"
    elseif ori == "east" then ori = "north"
    end

    self.orientation = ori
end

function RobotRep:turnRight()
    local ori = self.orientation
    if ori == "north" then ori = "east"
    elseif ori == "east" then ori = "south"
    elseif ori == "south" then ori = "west"
    elseif ori == "west" then ori = "north"
    end

    self.orientation = ori
end

function RobotRep:turnAround()
    local ori = self.orientation
    if ori == "north" then ori = "south"
    elseif ori == "east" then ori = "west"
    elseif ori == "south" then ori = "north"
    elseif ori == "west" then ori = "east"
    end

    self.orientation = ori
end

return RobotRep
