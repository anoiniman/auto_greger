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

local function __f_firstnight () FUEL_TYPE = "wood" end

-- Q1
local __q_firstnight = { Constraint:newQuestObj("minecraft:generic", "Dirt", 8) }
constraint = Constraint:newQuestConstraint(__q_firstnight)
local __g_firstnight = Goal:new(__g_hole_home01, constraint, 98, "__g_firstnight", true, __f_firstnight)
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
local function __f_oak_tree_farm01 () HAS_WOOD_FARM = true end
constraint = Constraint:newBuildingConstraint(__dec_oak_tree_farm, nil)
local __g_oak_tree_farm01 = Goal:new(__g_sapling01, constraint, 60, "__g_oak_tree_farm01", false, __f_oak_tree_farm01)
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

-- Q2a
local __q_sticks_n_stones = { Constraint:newQuestOb("Gravel", nil, 9), Constraint:newQuestObj(nil, "any:log", 7)}
constraint = Constraint:newQuestConstraint(__q_sticks_n_stones)
local __g_sticks_n_stones = Goal:new(__g_gravel01, constraint, 90, "__g_sticks_n_stones", true)
builder:addGoal(__g_sticks_n_stones)

local __q_where_flint = { Constraint:newQuestObj("Flint", nil, 3) }
constraint = Constraint:newQuestConstraint(__q_where_flint)
local __g_where_flint = Goal:new(__g_sticks_n_stones, constraint, 90, "__q_where_flint", true)
builder:addGoal(__g_where_flint)

local __q_tools = {
    Constraint:newQuestObj("Flint Shovel", nil, 1),
    Constraint:newQuestObj("Flint Pickaxe", nil, 1),
    Constraint:newQuestObj("Flint Axe", nil, 1),
    Constraint:newQuestObj("Flint Hoe", nil, 1),
}
constraint = Constraint:newQuestConstraint(__q_tools)
local __g_tools = Goal:new(__g_where_flint, constraint, 90, "__g_tools", true)
builder:addGoal(__g_tools)


-- 04
constraint = Constraint:newItemConstraint(nil, "Cobblestone", 4, 64, nil)
local __g_cobblestone01 = Goal:new(__g_logs02, constraint, 10, "__g_cobblestone01", false)
builder:addGoal(__g_cobblestone01)

-- Q2b
local __q_get_that_stone = { Constraint:newQuestObj("Cobblestone", nil, 64) }
constraint = Constraint:newQuestConstraint(__q_get_that_stone)
local __g_get_that_stone = Goal:new(__g_cobblestone01, constraint, 60, "__g_get_that_stone", true)
builder:addGoal(__g_get_that_stone)

local __q_fire_fire = { Constraint:newQestObj("Furnace", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_fire_fire)
local __g_fire_fire = Goal:new(__g_get_that_stone, constraint, 60, "__g_fire_fire", true)
builder:addGoal(__g_fire_fire)


local function __f_smallhome01 () WHAT_LOADOUT = "first" end

-- 05 (Should be able to craft the furnaces and chests by herself :))
constraint = Constraint:newBuildingConstraint(__dec_small_home, nil)
local __g_smallhome01 = Goal:new({__g_logs02, __g_cobblestone01}, constraint, 40, "__g_smallhome01", false, __f_smallhome01)
builder:addGoal(__g_smallhome01)

-----------------------------------------
-- Third Era (Charcoal Burning Era) <Aka, Mining Era, etc, and we actually start crafting axes n shit>

-- We finish the pre-stone age quests and early stone-age quests before going on the coke adventure, as obvious
-- Q3 (TODO -> continue from here)
local __q_soft_mallet_adv = {
constraint =


-- 01a
constraint = Constraint:newBuildingConstraint(__dec_coke_quad, nil)
local __g_coke_quad01 = Goal:new(__g_smallhome01, constraint, 60, "__g_coke_quad01", true)
builder:addGoal(__g_coke_quad01)

local function __f_charcoal01 () FUEL_TYPE = "loose_coal" end

constraint = Constraint:newItemConstraint(nil, "Charcoal", 32, 128, nil)
local __g_charcoal01 = Goal:new(__g_coke_quad01, constraint, 40, "__g_charcoal01", false, __f_charcoal01)
builder:addGoal(__g_charcoal01)

constraint = Constraint:newItemConstraint(nil, "Charcoal", 129, 512, nil)
local __g_charcoal02 = Goal:new(__g_charcoal01, constraint, 40, "__g_charcoal01", false)
builder:addGoal(__g_charcoal02)

-----------------------------------------
-- Fourth Era (Aura Farming Era)

-- 01
constraint = Constraint:newBuildingConstraint(__dec_sp_storeroom, nil)
local __g_sp_storeroom01 = Goal:new(__g_coke_quad01, constraint, 60, "__g_sp_storeroom01", false)
builder:addGoal(__g_sp_storeroom01)

-- 02
constraint = Constraint:newBuildingConstraint(__dec_tk_smeltery, nil)
local __g_tk_smeltery = Goal:new(__g_sp_storeroom01, constraint, 40, "__g_tk_smeltery", false)
builder:addGoal(__g_tk_smeltery)

-- 03
local function __f_f_pickaxe01 () WHAT_LOADOUT = "second" end
constraint = Constraint:newItemConstraint(nil, "Flint Pickaxe", 2, 3, nil)
local __g_f_pickaxe01 = Goal:new(__g_tk_smeltery, constraint, 68, "__g_f_pickaxe01", false, __f_f_pickaxe01)
builder:addGoal(__g_f_pickaxe01)


-- 04a
constraint = Constraint:newItemConstraint(nil, "Raw Chalcopyrite Ore", 32, 156, nil)
local __g_chalco01 = Goal:new(__g_f_pickaxe01, constraint, 41, "__g_chalco01", false)
builder:addGoal(__g_chalco01)

-- 04b
constraint = Constraint:newItemConstraint(nil, "Raw Cassiterite Sand Ore", 16, 78, nil)
local __g_cassit01 = Goal:new(__g_chalco01, constraint, 40, "__g_cassit01", false)
builder:addGoal(__g_cassit01)

-- 05
constraint = Constraint:newItemConstraint(nil, "Bronze Ingot", 8, 32, nil)
local __g_bronze = Goal:new({__g_chalco01, __g_cassit01}, constraint, 40, "__g_bronze", false)
builder:addGoal(__g_bronze)


builder:setDictionary(dictionary)
builder:addMultipleRecipes(debug_recipes)

local script = builder:build()

return script
