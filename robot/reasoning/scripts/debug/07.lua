local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local debug_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))

local desc = "Debug 07 - Le final-er frontier"
local builder = MSBuilder:new_w_desc(desc)
local constraint

-- constraint = Constraint:newItemConstraint(nil, "Raw Chalcopyrite Ore", 32, 64, nil)
constraint = Constraint:newItemConstraint(nil, "Raw Magnetite Ore", 32, 64, nil)
local raw_c_ore = Goal:new(nil, constraint, 66, "raw_c_ore", false)

builder:setDictionary(dictionary)
builder:addMultipleRecipes(debug_recipes)

builder:addGoal(raw_c_ore)

local script = builder:build()

return script
