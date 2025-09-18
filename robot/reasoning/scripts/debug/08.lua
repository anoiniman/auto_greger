local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local main_line_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))
local comms = require("comms")


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

local hole_home = StructureDeclaration:new("hole_home", 0, 0, 1)
constraint = Constraint:newBuildingConstraint(hole_home)
local hole_goal = Goal:new(home_goal, constraint, 40, "h_home_const", true)
builder:addGoal(hole_goal)

-- WARNING (TODO) we're getting a cant find recipe "nil", "nil" from this point onwards so yeah
local quest01_table = {
    Constraint:newQuestObj("Dirt", "minecraft:generic", 8),
    Constraint:newQuestObj(nil, "Iron Ingot", 32),
}

local function test()
    print(comms.robot_send("info", "Get in THERE!!!!!!!!!!!!!!!"))
end

constraint = Constraint:newQuestConstraint(quest01_table)
local quest_goal = Goal:new(hole_goal, constraint, 50, "quest_const", true, test)
builder:addGoal(quest_goal)


-- constraint = Constraint:newItemConstraint("any:ingot", "Iron Ingot", 16, 64, nil)
-- local iron_goal = Goal:new(quest_goal, constraint, 50, "iron_const", false, test)
-- builder:addGoal(iron_goal)


local script = builder:build()

return script
