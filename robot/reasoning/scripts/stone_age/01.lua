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
-- TODO, actually programme in the meta inventories in simplified/storeroom
local __dec_simp_storeroom_n    =   StructureDeclaration:new("simplified/storeroom_north", 0, 0, 1)
local __dec_simp_storeroom_s    =   StructureDeclaration:new("simplified/storeroom_south", 0, 0, 1)

----------------------------------------
-- By using a mostly linear approach we make sure that our underdeveloped parallel system isn't
-- gonna be doing anything too stupid

---------------------------------------

-- FIRST "ERA" GOALS (Wood-Burning Era)

-- 01
constraint = Constraint:newBuildingConstraint(__dec_hole_home, nil)
local __g_hole_home01 = Goal:new(nil, constraint, 100, "__g_hole_home01", true)
builder:addGoal(__g_hole_home01)

-- 02a (small plank goal for fuel reasons)
constraint = Constraint:newItemConstraint("any:plank", nil, 8, 8, nil)
local __g_planks01 = Goal:new(__g_hole_home01, constraint, 80, "__g_planks01", false)
builder:addGoal(__g_planks01)

-- 02b
constraint = Constraint:newItemConstraint("any:log", nil, 8, 24, nil)
local __g_logs01 = Goal:new(__g_hole_home01, constraint, 96, "__g_logs01", false)
builder:addGoal(__g_logs01)

-- 03a
constraint = Constraint:newItemConstraint(nil, "Flint", 8, 24, nil) -- uhhh find a way for the gathering mechanism to get all
local __g_flint01 = Goal:new(__g_logs01, constraint, 60, "__g_flint01", false) -- (prob have to do that in recipe definition)
builder:addGoal(__g_flint01)

-- We prob need to add a guard that only alows one simultaneous gathering for now

-- 03b
constraint = Constraint:newItemConstraint(nil, "Flint Shovel", 1, 2, nil) -- hopefully 04a and 04b... can be cleared simultaneously?
local __g_f_shovel01 = Goal:new(__g_logs01, constraint, 75, "__g_f_shovel01", false)
builder:addGoal(__g_f_shovel01)

-- 03c (Do not use Axes until you've got ore, you'll struggle to have enough flint, shovels are ok-ish tho)

-- 04
constraint = Constraint:newBuildingConstraint(__dec_oak_tree_farm, nil)
local __g_oak_tree_farm01 = Goal:new(__g_f_axe01, constraint, 60, "__g_oak_tree_farm01", false)
builder:addGoal(__g_oak_tree_farm01)

-- 05a
constraint = Constraint:newItemConstraint("any:plank", nil, 32, 124, nil)
local __g_planks02 = Goal:new(__g_oak_tree_farm01, constraint, 62, "__g_planks02", false)
builder:addGoal(__g_planks02)

-- 05b
constraint = Constraint:newItemConstraint("any:log", nil, 32, 72, nil)
local __g_logs02 = Goal:new(__g_oak_tree_farm01, constraint, 60, "__g_logs02", false)
builder:addGoal(__g_logs02)

-- 06
constraint = Constraint:newBuildingConstraint(__dec_sp_storeroom, nil)
local __g_sp_storeroom01 = Goal:new(__g_logs02, constraint, 60, "__g_sp_storeroom01", false)
builder:addGoal(__g_sp_storeroom01)

-- 07
constraint = Constraint:newBuildingConstraint(__dec_coke_quad, nil)
local __g_coke_quad01 = Goal:new(__g_sp_storeroom01, constraint, 60, "__g_coke_quad01", false)
builder:addGoal(__g_coke_quad01)

-----------------------------------------
-- TODO, don't forget to finger the pie for the buildings! You didn't finger them last time!

-- Second Era (Charcoal Burning Era) <Aka, Mining Era, etc, and we actually start crafting axes n shit>

-- 01a (TODO -> Remove the flint tool constraints from the tree after we are able to use "good" tools,
-- remember to use a global variable I guess, so it does not accidentally 'unset' during weird interactions
-- when we do save/loads)
constraint = Constraint:newItemConstraint(nil, "Flint Pickaxe", 2, 3, nil)
local __g_f_pickaxe01 = Goal:new(__g_coke_quad01, constraint, 68, "__g_f_pickaxe01", false)
builder:addGoal(__g_f_pickaxe01)



builder:setDictionary(dictionary)
builder:addMultipleRecipes(debug_recipes)

local script = builder:build()

return script
