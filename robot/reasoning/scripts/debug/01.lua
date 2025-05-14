local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local MetaRecipe = require("reasoning.MetaRecipe")

local desc = "Debug 01 - Build me a coke oven, you brat!"
local builder = MSBuilder:new_w_desc(desc)

local coke_oven = StructureDeclaration:new("coke_quadrant", 0, 0, 1)
local constraint = Constraint:newBuildingConstraint(coke_oven, nil)

local simple_goal = Goal:new(nil, constraint, nil, nil, 100)
builder:addGoal(simple_goal)

local script = builder:build()

return script
