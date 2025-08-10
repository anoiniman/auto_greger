local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local debug_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))

local desc = "GOD IS IN HIS HEAVEN! ALL IS WELL! WITH THE WORLD!"
local builder = MSBuilder:new_w_desc(desc)
local constraint

-------- STRUCTURE DECLARATIONS ---------
-- It is a shame that quad numbers are fixed, but I really don't want to add anymore features
local __dec_hole_home           =   StructureDeclaration:new("hole_home", 0, 0, 1) -- we'll have a base dec with quad as 1,
local __dec_coke_quad           =   StructureDeclaration:new("coke_quad", 0, 0, 1) -- and then we just finger the pie manually
local __dec_oak_tree_farm       =   StructureDeclaration:new("oak_tree_farm", 0, 0, 1)
local __dec_spruce_tree_farm    =   StructureDeclaration:new("spruce_tree_farm", 0, 0, 1) -- TODO, fix the farm itself :)
local __dec_sp_storeroom        =   StructureDeclaration:new("sp_storeroom", 0, 0, 1)


constraint = Constraint:newItemConstraint(nil, "Flint Pickaxe", 1, 1, nil)
local f_pickaxe = Goal:new(nil, constraint, 66, "Flint Pickaxe", false)
builder:addGoal(f_pickaxe)


builder:setDictionary(dictionary)
builder:addMultipleRecipes(debug_recipes)

local script = builder:build()

return script
