local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local MetaRecipe = require("reasoning.MetaRecipe")

local desc = "Debug 04 - Get gathering me boy"
local builder = MSBuilder:new_w_desc(desc)

local dec_array = {}
dec_array[1] = StructureDeclaration:new("storeroom_north", 0, 0, 1)
dec_array[2] = StructureDeclaration:new("storeroom_north", 0, 0, 2)

dec_array[3] = StructureDeclaration:new("storeroom_south", 0, 0, 3)
dec_array[4] = StructureDeclaration:new("storeroom_south", 0, 0, 4)
local constraint = Constraint:newBuildingConstraint(dec_array, nil)

local simple_goal = Goal:new(nil, constraint, nil, nil, 100)
builder:addGoal(simple_goal)

local script = builder:build()

return script
