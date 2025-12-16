local deep_copy = require("deep_copy");

local Slot = {is_empty = true, label = "", name = ""}
function Slot:empty()
    return COPY(self)
end

local Inventory = {inner = {}}
function Inventory:new()
    local new = COPY(self)
    for i = 1, 32, 1 do
        new.inner[i] = Slot:empty()
    end
    return new
end

local RobotRep = {}
function RobotRep:new()
    local new = COPY(self)

    new.equiped_tool = nil
    new.inventory = Inventory:new()
    new.position = {0, 0, 0}

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

return RobotRep
