local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local MetaRecipe = require("reasoning.MetaRecipe")

local desc = "Debug 02 - I'm digging a hole, where the rain gets in...."
local builder = MSBuilder:new_w_desc(desc)

local hole_home = StructureDeclaration:new("hole_home", 0, 0, 2)
local constraint = Constraint:newBuildingConstraint(hole_home, nil)

local simple_goal = Goal:new(nil, constraint, nil, nil, 100)
builder:addGoal(simple_goal)

local script = builder:build()

return script
