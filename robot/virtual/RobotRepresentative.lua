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

local robot_rep = {} -- singleton
function robot_rep:reset()
    self.equiped_tool = nil
    self.inventory = Inventory:new()
    self.position = {0, 0, 0}
end

robot_rep:reset()
return robot_rep
