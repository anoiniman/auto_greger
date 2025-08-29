local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local main_line_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))

local desc = "Debug 08 - Might be the most important debg session of our life"
local builder = MSBuilder:new_w_desc(desc)
local constraint

local very_simple_storage = StructureDeclaration:new("sp_storeroom", 0, 0, 1)
constraint = Constraint:newBuildingConstraint(very_simple_storage, nil)
local storage_goal = Goal:new(nil, constraint, 40, "sp_storeroom_const", true)
builder:addGoal(storage_goal)

local small_home = StructureDeclaration:new("small_home", 0, 0, 1)
constraint = Constraint:newBuildingConstraint(small_home, nil)
local home_goal = Goal:new(storage_goal, constraint, 40, "s_home_const", true)
builder:addGoal(home_goal)

-- TIME TO TEST LOADOUTS (1st)
-- AND THEN TEST THE FURNACES,
-- AND THEN TEST OOS
--
-- AND THEN FINISH lava algorithm, and quarry algorithm
-- AND THEN.... DIE!

builder:setDictionary(dictionary)
builder:addMultipleRecipes(main_line_recipes)

constraint = Constraint:newItemConstraint(nil, "Iron Ingot", 16, 64, nil)
local iron_goal = Goal_new(home_goal, constraint, 50, "iron_const", false)
builder:addGoal(iron_goal)


local script = builder:build()

return script
