local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))

-- includes a charcoal recipe and a Oak Log recipe
local debug_recipes = require("reasoning.recipes.debug.01")

local desc = "Debug 05 - Big Impressive Test Challenges Hopelessness BIT-CH"
local builder = MSBuilder:new_w_desc(desc)
local constraint

-- remember to put needed materials in the robot's inventory and force_update the inventory
local oak_tree_farm = StructureDeclaration:new("oak_tree_farm", 0, 0, 3)
constraint = Constraint:newBuildingConstraint(oak_tree_farm, nil)
local oak_farm_goal = Goal:new(nil, constraint, 40, "oak_farm_const", true)

local coke_quad = StructureDeclaration:new("coke_quad", 0, 0, 1)
constraint = Constraint:newBuildingConstraint(coke_quad, nil)
local coke_quad_goal = Goal:new(oak_farm_goal, constraint, 40, "coke_quad_const", true)

constraint = Constraint:newItemConstraint("minecraft:coal", "Charcoal", 32, 156, nil)
local charcoal_goal = Goal:new(coke_quad_goal, constraint, 40, "charcoal_const", true)

local very_simple_storage = StructureDeclaration:new("sp_storeroom", 0, 0, 1)
constraint = Constraint:newBuildingConstraint(very_simple_storage, nil)
local storage_goal = Goal:new(nil, constraint, 40, "sp_storeroom_const", true)

builder:addGoal(storage_goal)

builder:addGoal(charcoal_goal)  -- because the goal resolution engine does not recurse, but rather simply checks if the deps
                                -- are satisfied, at least for now, we need to pub declare every goal
builder:addGoal(oak_farm_goal)
builder:addGoal(coke_quad_goal)

builder:addMultipleRecipes(debug_recipes)

local script = builder:build()

return script
