local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local MetaRecipe = require("reasoning.MetaRecipe")

local gravel_only, _ = require("reasoning.recipes.stone_age.gathering01")

local desc = "Debug 04 - Get gathering me boy"
local builder = MSBuilder:new_w_desc(desc)

local constraint = Constraint:newItemConstraint("Gravel", 32, nil)
local simple_goal = Goal:new(nil, constraint, 40, nil, false)
builder:addGoal(simple_goal)
builder:addRecipe(gravel_only)

local script = builder:build()

return script
