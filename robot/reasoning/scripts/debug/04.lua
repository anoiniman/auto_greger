local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local MetaRecipe = require("reasoning.MetaRecipe")

local desc = "Debug 04 - Get gathering me boy"
local builder = MSBuilder:new_w_desc(desc)

local constraint =

local simple_goal = Goal:new(nil, constraint, nil, nil, 100)
builder:addGoal(simple_goal)

local script = builder:build()

return script
