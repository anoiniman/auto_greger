local deep_copy = require("deep_copy")
local comms = require("comms")

local ItemConstraint = require("reasoning.MetaScript.Constraint.ItemConstraint")
local BuildingConstraint = require("reasoning.MetaScript.Constraint.BuildingConstraint")

-- AKA, some sub-condition/way to alter the constraint condition, such that when met
-- the force or the constraint is slackened, might be unimplemented for now
local Slacking = {}

-- Constraints define what a goal should try and do to achieve it self,
-- they are recursable, so if you ask for item "x", and it needs building "y",
-- and building "y" needs item "z" it will do z->y->x successefully.....
-- hopefully
local Constraint = { const_type = nil, const_obj = nil, slacking = nil }
function Constraint:new() return deep_copy.copy(self, pairs) end
function Constraint:newItemConstraint(item_name, item_lable, total_count, slacking)
    local new = self:new()
    new.const_type = "item"
    new.const_obj = ItemConstraint:new(item_name, item_lable, total_count)
    new.slacking = slacking or nil
    return new
end

function Constraint:newBuildingConstraint(structures, centre, slacking)
    if structures == nil then
        print(comms.robot_send("error", "Constraint:newBC, structures is nil!"))
    elseif structures[1] == nil then
        print(comms.robot_send("debug", "Constraint:newBC, strucutres is not table of structures, attempting quick-fix!"))
        structures = {structures}
    end

    local new = self:new()
    new.const_type = "building"
    new.const_obj = BuildingConstraint:new(structures, centre)
    new.slacking = slacking or nil
    return new
end

function Constraint:check(do_once)
    local index, name = self.const_obj:check(do_once)

    return index, name
end

function Constraint:returnType()
    return self.const_type
end

function Constraint:step(index, name, priority) -- useful only for Building Constraints
    if self.const_type ~= "building" then
        error(comms.robot_send("fatal", "Constraint:step used for non building"))
    end
    return self.const_obj:step(index, name, priority)
end

return Constraint
