local deep_copy = require("deep_copy")
local MetaRecipe = require("reasoning.MetaRecipe")

local MetaScript = {}
function MetaScript:new() return deep_copy.copy(self, pairs) end

-- Possible filters = "strict", "loose", "gt_ore"
-- perfect string match, imperfect match, item_name is actually a table
local ItemConstraint = {item_name = nil, total_count = nil, filter = nil}
function ItemConstraint:new(item_name, total_count, filter) 
    local new = deep_copy.copy(self, pairs)
    new.item_name = item_name
    new.total_count = total_count
    new.filter = filter
end

local BuildingConstraint = nil

-- AKA, some sub-condition/way to alter the constraint condition, such that when met
-- the force or the constraint is slackened, might be unimplemented for now
local Slacking = {}

local Constraint = { const_type = nil, const_obj = nil, slacking = nil }
function Constraint:new() return deep_copy.copy(self, pairs) end
function Constraint:newItemConstraint(item_name, total_count)
    local new = self:new()
    new.const_type = "item_constraint"
    new.const_obj = ItemConstraint:new(item_name, total_count)
end

-- constraints are immaterial, inputs are material
local Goal = {constraints = {}, recipe = nil priority = 0}
function Goal:new() return deep_copy.copy(self, pairs) end



local MSBuilder = {base_script = MetaScript:new()}
function MSBuilder:new() return deep_copy.copy(self, pairs) end

function MSBuilder:addGoal(goal)

end

return MSBuilder, Goal, Constraint
