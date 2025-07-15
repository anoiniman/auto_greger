local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local debug_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))

local desc = "Debug 06 - Le final frontier"
local builder = MSBuilder:new_w_desc(desc)
local constraint

constraint = Constraint:newItemConstraint(nil, "Flint Pickaxe", 1, 1, nil)
local f_pickaxe = Goal:new(nil, constraint, 66, "Flint Pickaxe", false)

builder:setDictionary(dictionary)
builder:addMultipleRecipes(debug_recipes)

builder:addGoal(f_pickaxe)

local script = builder:build()

return script
