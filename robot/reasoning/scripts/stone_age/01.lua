local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
local debug_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))

local desc = "GOD IS IN HIS HEAVEN! ALL IS WELL! WITH THE WORLD!"
local builder = MSBuilder:new_w_desc(desc)
local constraint

-------- STRUCTURE DECLARATIONS ---------
local __dec_hole_home           =   StructureDeclaration:new("hole_home", 0, 0, 1)
local __dec_small_home          =   StructureDeclaration:new("small_home", 0, 0, 1)
local __dec_coke_quad           =   StructureDeclaration:new("coke_quad", 0, 0, 1)
local __dec_oak_tree_farm       =   StructureDeclaration:new("oak_tree_farm", 0, 0, 1)
local __dec_spruce_tree_farm    =   StructureDeclaration:new("spruce_tree_farm", 0, 0, 1) -- TODO, fix the farm itself :)
local __dec_sp_storeroom        =   StructureDeclaration:new("sp_storeroom", 0, 0, 1)
local __dec_tk_smeltery         =   StructureDeclaration:new("tk_smeltery", 0, 0, 1)

-- TODO, actually programme in the meta inventories in simplified/storeroom (we're not going to use simplified store-room)
local __dec_simp_storeroom_n    =   StructureDeclaration:new("simplified/storeroom_north", 0, 0, 1)
local __dec_simp_storeroom_s    =   StructureDeclaration:new("simplified/storeroom_south", 0, 0, 1)

----------------------------------------
-- By using a mostly linear approach we make sure that our underdeveloped parallel system isn't
-- gonna be doing anything too stupid, mostly related with task interrupts and mishandled state-bleeds

---------------------------------------

-- FIRST "ERA" GOALS (Pre-Furnace Era)

-- 01a
constraint = Constraint:newBuildingConstraint(__dec_hole_home, nil)
local __g_hole_home01 = Goal:new(nil, constraint, 100, "__g_hole_home01", true)
builder:addGoal(__g_hole_home01)

-- 01b
local __q_firstnight = { Constraint:newQuestObj("minecraft:generic", "Dirt", 8) }
constraint = Constraint:newQuestConstraint(__q_firstnight)
local __g_firstnight = Goal:new(__g_hole_home01, constraint, 98, "__g_firstnight", true)
builder:addGoal(__g_firstnight)


-- We prob need to add a guard that only alows one simultaneous gathering for now

-- 02a (small plank goal for fuel reasons)
-- This super small goal is fine since logs can be converted in-place to planks
constraint = Constraint:newItemConstraint("any:plank", nil, 8, 8, nil)
local __g_planks01 = Goal:new(__g_hole_home01, constraint, 80, "__g_planks01", false)
builder:addGoal(__g_planks01)

-- 02b
constraint = Constraint:newItemConstraint("any:log", nil, 8, 24, nil)
local __g_logs01 = Goal:new(__g_hole_home01, constraint, 90, "__g_logs01", false)
builder:addGoal(__g_logs01)

constraint = Constraint:newItemConstraint("any:sapling", nil, 0, 22, nil)
local __g_sapling01 = Goal:new(__g_logs01, constraint, 30, "__g_sapling01", true)

-----------------------------------------
-- Second Era (Preparing for charcoal)

-- 01
constraint = Constraint:newBuildingConstraint(__dec_oak_tree_farm, nil)
local __g_oak_tree_farm01 = Goal:new(__g_sapling01, constraint, 60, "__g_oak_tree_farm01", false)
builder:addGoal(__g_oak_tree_farm01)

-- 02a
constraint = Constraint:newItemConstraint("any:plank", nil, 32, 124, nil)
local __g_planks02 = Goal:new(__g_oak_tree_farm01, constraint, 62, "__g_planks02", false)
builder:addGoal(__g_planks02)

-- 02b
constraint = Constraint:newItemConstraint("any:log", nil, 32, 72, nil)
local __g_logs02 = Goal:new(__g_oak_tree_farm01, constraint, 60, "__g_logs02", false)
builder:addGoal(__g_logs02)

-- 03a
constraint = Constraint:newItemConstraint("minecraft:generic", "Gravel", 18, 72, nil) -- uhhh find a way for the gathering mechanism to get all
local __g_gravel01 = Goal:new(__g_logs01, constraint, 60, "__g_gravel01", false) -- (prob have to do that in recipe definition)
builder:addGoal(__g_gravel01)


-- 04
constraint = Constraint:newItemConstraint(nil, "Cobblestone", 52, 52, nil)
local __g_cobblestone01 = Goal:new(__g_logs02, constraint, 40, "__g_cobblestone01", false)
builder:addGoal(__g_cobblestone01)

-- 05 (Should be able to craft the furnaces and chests by herself :))
constraint = Constraint:newBuildingConstraint(__dec_small_home, nil)
local __g_smallhome01 = Goal:new({__g_logs02, __g_cobblestone01}, constraint, 40, "__g_smallhome01", false)
builder:addGoal(__g_smallhome01)

-----------------------------------------
-- Third Era (Charcoal Burning Era) <Aka, Mining Era, etc, and we actually start crafting axes n shit>

-- 01a (TODO -> Remove the flint tool constraint(s) from the tree after we are able to use "good" tools,
-- remember to use a global variable I guess, so it does not accidentally 'unset' during weird interactions
-- when we do save/loads)

constraint = Constraint:newBuildingConstraint(__dec_coke_quad, nil)
local __g_coke_quad01 = Goal:new(__g_sp_storeroom01, constraint, 60, "__g_coke_quad01", false)
builder:addGoal(__g_coke_quad01)

constraint = Constraint:newItemConstraint(nil, "Flint Pickaxe", 2, 3, nil)
local __g_f_pickaxe01 = Goal:new(__g_coke_quad01, constraint, 68, "__g_f_pickaxe01", false)
builder:addGoal(__g_f_pickaxe01)


-----------------------------------------
-- Fourth Era (Aura Farming Era)
constraint = Constraint:newBuildingConstraint(__dec_sp_storeroom, nil)
local __g_sp_storeroom01 = Goal:new(__g_logs02, constraint, 60, "__g_sp_storeroom01", false)
builder:addGoal(__g_sp_storeroom01)


builder:setDictionary(dictionary)
builder:addMultipleRecipes(debug_recipes)

local script = builder:build()

return script
