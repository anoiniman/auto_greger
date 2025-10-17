-- luacheck: globals WHAT_LOADOUT FUEL_TYPE HAS_WOOD_FARM HAS_MORTAR DO_SCRIPT_RELOAD
local comms = require("comms")
local MSBuilder, Goal, Constraint, StructureDeclaration = table.unpack(require("reasoning.MetaScript"))
-- local essential_recipes, dictionary = table.unpack(require("reasoning.recipes.stone_age.essential01"))
local essential_recipes, dictionary = table.unpack(dofile("/home/robot/reasoning/recipes/stone_age/essential01.lua"))

local desc = "GOD IS IN HIS HEAVEN! ALL IS WELL! WITH THE WORLD!"
local builder = MSBuilder:new_w_desc(desc)
local constraint

-------- STRUCTURE DECLARATIONS ---------
local __dec_hole_home           =   StructureDeclaration:new("hole_home", 0, 0, 1)
local __dec_small_home          =   StructureDeclaration:new("small_home", 0, 0, 1)
local __dec_coke_quad           =   StructureDeclaration:new("coke_quad", 0, 0, 1)
local __dec_oak_tree_farm       =   StructureDeclaration:new("oak_tree_farm", 0, 0, 1)
-- local __dec_spruce_tree_farm    =   StructureDeclaration:new("spruce_tree_farm", 0, 0, 1) -- TODO, fix the farm itself :)
local __dec_sp_storeroom        =   StructureDeclaration:new("sp_storeroom", 0, 0, 1)
local __dec_tk_smeltery         =   StructureDeclaration:new("tk_smeltery", 0, 0, 1)

local __dec_small_oak_farm     =   StructureDeclaration:new("small_oak_farm", 0, 0, 1)

-- TODO, actually programme in the meta inventories in simplified/storeroom (we're not going to use simplified store-room)
-- local __dec_simp_storeroom_n    =   StructureDeclaration:new("simplified/storeroom_north", 0, 0, 1)
-- local __dec_simp_storeroom_s    =   StructureDeclaration:new("simplified/storeroom_south", 0, 0, 1)

----------------------------------------
-- By using a mostly linear approach we make sure that our underdeveloped parallel system isn't
-- gonna be doing anything too stupid, mostly related with task interrupts and mishandled state-bleeds

---------------------------------------

-- FIRST "ERA" GOALS (Pre-Furnace Era)

-- 01a
constraint = Constraint:newBuildingConstraint(__dec_hole_home, nil)
local __g_hole_home01 = Goal:new(nil, constraint, 100, "__g_hole_home01", true)
builder:addGoal(__g_hole_home01)

-- Q1
local __q_firstnight = { Constraint:newQuestObj("Dirt", "any:grass", 8) }
constraint = Constraint:newQuestConstraint(__q_firstnight)
local __g_firstnight = Goal:new(__g_hole_home01, constraint, 98, "__g_firstnight", true)
builder:addGoal(__g_firstnight)


-- We prob need to add a guard that only alows one simultaneous gathering for now

local function __f_planks01 () FUEL_TYPE = "wood" end

-- 02a (small plank goal for fuel reasons)
constraint = Constraint:newItemConstraint("any:sapling", "Oak Sapling", 4, 4)
local __g_sapling01 = Goal:new(__g_hole_home01, constraint, 30, "__g_sapling01", true)
builder:addGoal(__g_sapling01)

local function __f_small_oak_farm01 () HAS_WOOD_FARM = 1; DO_SCRIPT_RELOAD = true end
constraint = Constraint:newBuildingConstraint(__dec_small_oak_farm)
local __g_small_oak_farm01 = Goal:new(__g_sapling01, constraint, 90, "__g_small_oak_farm01", false, __f_small_oak_farm01)
builder:addGoal(__g_small_oak_farm01)

constraint = Constraint:newItemConstraint("any:plank", nil, 16, 64, nil)
local __g_planks01 = Goal:new(__g_small_oak_farm01, constraint, 80, "__g_planks01", false, __f_planks01)
builder:addGoal(__g_planks01)

-- 02b
constraint = Constraint:newItemConstraint("any:log", nil, 8, 24, nil)
local __g_logs01 = Goal:new(__g_planks01, constraint, 82, "__g_logs01", false)
builder:addGoal(__g_logs01)

--[[constraint = Constraint:newItemConstraint("any:sapling", nil, 0, 22, nil)
local __g_sapling01 = Goal:new(__g_logs01, constraint, 30, "__g_sapling01", true)
builder:addGoal(__g_sapling01)--]]

-----------------------------------------
-- Second Era (Preparing for charcoal)

-- 01 (for some reason this failed to execute?)
local function __f_oak_tree_farm01 () HAS_WOOD_FARM = 2; DO_SCRIPT_RELOAD = true end
constraint = Constraint:newBuildingConstraint(__dec_oak_tree_farm, nil)
local __g_oak_tree_farm01 = Goal:new(__g_small_oak_farm01, constraint, 60, "__g_oak_tree_farm01", false, __f_oak_tree_farm01)
builder:addGoal(__g_oak_tree_farm01)

--[[constraint = Constraint:newBuildingConstraint({__dec_oak_tree_farm, __dec_oak_tree_farm}, nil)
local __g_oak_tree_farm02 = Goal:new(__g_oak_tree_farm01, constraint, 60, "__g_oak_tree_farm02", false)
builder:addGoal(__g_oak_tree_farm02)--]]


-- 02a
constraint = Constraint:newItemConstraint("any:plank", nil, 32, 124, nil)
local __g_planks02 = Goal:new(__g_oak_tree_farm01, constraint, 82, "__g_planks02", false)
builder:addGoal(__g_planks02)

-- 02b
constraint = Constraint:newItemConstraint("any:log", nil, 32, 72, nil)
local __g_logs02 = Goal:new({__g_oak_tree_farm01, __g_planks02}, constraint, 82, "__g_logs02", false)
builder:addGoal(__g_logs02)

-- 03a
constraint = Constraint:newItemConstraint("minecraft:generic", "Gravel", 18, 72, nil) -- uhhh find a way for the gathering mechanism to get all
local __g_gravel01 = Goal:new(__g_logs02, constraint, 60, "__g_gravel01", false) -- (prob have to do that in recipe definition)
builder:addGoal(__g_gravel01)

-- Q2a
local __q_sticks_n_stones = { Constraint:newQuestObj("Gravel", nil, 9), Constraint:newQuestObj(nil, "any:log", 7)}
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

local __q_sharpness_over_five = { Constraint:newQuestObj("Flint Sword", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_sharpness_over_five)
local __g_sharpness_over_five = Goal:new(__g_tools, constraint, 90, "__g_sharpness_over_five", true)
builder:addGoal(__g_sharpness_over_five)


-- 04
constraint = Constraint:newItemConstraint(nil, "Cobblestone", 4, 64, nil)
local __g_cobblestone01 = Goal:new({__g_logs02, __g_sharpness_over_five}, constraint, 10, "__g_cobblestone01", false)
builder:addGoal(__g_cobblestone01)

-- Q2b
local __q_get_that_stone = { Constraint:newQuestObj("Cobblestone", nil, 64) }
constraint = Constraint:newQuestConstraint(__q_get_that_stone)
local __g_get_that_stone = Goal:new(__g_cobblestone01, constraint, 60, "__g_get_that_stone", true)
builder:addGoal(__g_get_that_stone)

local __q_fire_fire = { Constraint:newQuestObj("Furnace", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_fire_fire)
local __g_fire_fire = Goal:new(__g_get_that_stone, constraint, 60, "__g_fire_fire", true)
builder:addGoal(__g_fire_fire)

local __q_storage_for_days = { Constraint:newQuestObj("Chest", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_storage_for_days)
local __g_storage_for_days = Goal:new(__g_fire_fire, constraint, 45, "__g_storage_for_days", true)
builder:addGoal(__g_storage_for_days)


local function __f_smallhome01 () WHAT_LOADOUT = "first" end

-- 05 (Should be able to craft the furnaces and chests by herself :))
constraint = Constraint:newBuildingConstraint(__dec_small_home, nil)
local __g_smallhome01 = Goal:new({__g_logs02, __g_cobblestone01, __g_storage_for_days}, constraint, 40, "__g_smallhome01", true, __f_smallhome01)
builder:addGoal(__g_smallhome01)

-----------------------------------------
-- Third Era (Charcoal Burning Era) <Aka, Mining Era, etc, and we actually start crafting axes n shit>

-- We finish the pre-stone age quests and early stone-age quests before going on the coke adventure, as obvious
-- Q3
local __q_soft_mallet_adv = { Constraint:newQuestObj("Wooden Mallet", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_soft_mallet_adv)
local __g_soft_mallet_adv = Goal:new(__g_smallhome01, constraint, 40, "__g_soft_mallet_adv", true)
builder:addGoal(__g_soft_mallet_adv)


--[[local __q_fluffy_and_red = { Constraint:newQuestObj("Wool", nil, 6) }
constraint = Constraint:newQuestConstraint(__q_fluffy_and_red)
local __g_fluffy_and_red = Goal:new(__g_soft_mallet_adv, constraint, 30, "__g_fluffy_and_red", true)
builder:addGoal(__g_fluffy_and_red)

local __q_so_tired_must_sleep = { Constraint:newQuestObj("Bed", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_so_tired_must_sleep)
local __g_so_tired_must_sleep = Goal:new(__g_fluffy_and_red, constraint, 90, "__g_so_tired_must_sleep", true)
builder:addGoal(__g_so_tired_must_sleep)--]]


-- Q4 (Stone age starts now)
local __q_basic_processing = { Constraint:newQuestObj("Stone", nil, 25) }
constraint = Constraint:newQuestConstraint(__q_basic_processing)
local __g_basic_processing = Goal:new(__g_soft_mallet_adv, constraint, 40, "__g_basic_processing", true)
builder:addGoal(__g_basic_processing)


local __q_macerator0_1 = { Constraint:newQuestObj("Flint Mortar", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_macerator0_1)
local __g_macerator0_1 = Goal:new(__g_basic_processing, constraint, 40, "__g_macerator0_1", true)
builder:addGoal(__g_macerator0_1)


-- 01
local max_mortar = 3
local function __f_mortar01 () HAS_MORTAR = true; DO_SCRIPT_RELOAD = true end

constraint = Constraint:newItemConstraint(nil, "Flint Mortar", 1, max_mortar)
local __g_mortar01 = Goal:new(__g_macerator0_1, constraint, 80, "__g_mortar01", false, __f_mortar01)
builder:addGoal(__g_mortar01)

constraint = Constraint:newItemConstraint(nil, "Flint", math.floor(max_mortar * 2 * 1.1), math.ceil(max_mortar * 2 * 1.5))
local __g_flint01 = Goal:new(__g_mortar01, constraint, 64, "__g_flint01", false)
builder:addGoal(__g_flint01)


-- Q5 (Stone-Age Gathering Quests)
local __q_gravel_gathering = { Constraint:newQuestObj("Gravel", nil, 128) }
constraint = Constraint:newQuestConstraint(__q_gravel_gathering)
local __g_gravel_gathering = Goal:new(__g_flint01, constraint, 40, "__g_gravel_gathering", true)
builder:addGoal(__g_gravel_gathering)

local __q_sand_gathering = { Constraint:newQuestObj("Sand", nil, 128) }
constraint = Constraint:newQuestConstraint(__q_sand_gathering)
local __g_sand_gathering = Goal:new(__g_gravel_gathering, constraint, 40, "__g_sand_gathering", true)
builder:addGoal(__g_sand_gathering)

local __q_clay_gathering = { Constraint:newQuestObj("Clay", nil, 128) }
constraint = Constraint:newQuestConstraint(__q_clay_gathering)
local __g_clay_gathering = Goal:new(__g_sand_gathering, constraint, 40, "__g_clay_gathering", true)
builder:addGoal(__g_clay_gathering)

-- Q6 Building towards the coke oven
local __q_something_to_carry_l = { Constraint:newQuestObj("Fired Clay Bucket", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_something_to_carry_l)
local __g_something_to_carry_l = Goal:new(__g_clay_gathering, constraint, 40, "__g_something_to_carry_l", true)
builder:addGoal(__g_something_to_carry_l)

local __q_book_parts = { Constraint:newQuestObj("Paper", nil, 16) }
constraint = Constraint:newQuestConstraint(__q_book_parts)
local __g_book_parts = Goal:new(__g_something_to_carry_l, constraint, 40, "__g_book_parts", true)
builder:addGoal(__g_book_parts)

local __q_tinker_time = {
    Constraint:newQuestObj("Part Builder", nil, 1),
    Constraint:newQuestObj("Stencil Table", nil, 1),
    Constraint:newQuestObj("Tool Station", nil, 1),
    Constraint:newQuestObj("Pattern Chest", nil, 1),
}
constraint = Constraint:newQuestConstraint(__q_tinker_time)
local __g_tinker_time = Goal:new(__g_book_parts, constraint, 40, "__g_tinker_time", true)
builder:addGoal(__g_tinker_time)

-- careful not to request more than 1 wooden form at the time because of recipe restrictions
local __q_forming_press = { Constraint:newQuestObj("Wooden Form (Brick)", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_forming_press)
local __g_forming_press = Goal:new(__g_tinker_time, constraint, 40, "__g_forming_press", true)
builder:addGoal(__g_forming_press)

-- local __q_another_brick = { Constraint:newQuestObj("Coke Oven Brick", "dreamcraft:item.CokeOvenBrick", 104) }
local __q_another_brick = { Constraint:newQuestObj("Coke Oven Brick", "Railcraft:machine.alpha", 104) }
constraint = Constraint:newQuestConstraint(__q_another_brick)
local __g_another_brick = Goal:new(__g_forming_press, constraint, 40, "__g_another_brick", true)
builder:addGoal(__g_another_brick)


-- 02a
constraint = Constraint:newBuildingConstraint({__dec_coke_quad, __dec_coke_quad}, nil)
local __g_coke_quad01 = Goal:new(__g_another_brick, constraint, 60, "__g_coke_quad01", true)
builder:addGoal(__g_coke_quad01)


local __q_finally_some = { Constraint:newQuestObj("Charcoal", nil, 4) }
constraint = Constraint:newQuestConstraint(__q_finally_some)
local __g_finally_some = Goal:new(__g_coke_quad01, constraint, 40, "__g_finally_some", true)
builder:addGoal(__g_finally_some)

local function __f_charcoal01 () FUEL_TYPE = "loose_coal"; WHAT_LOADOUT = "second" end
constraint = Constraint:newItemConstraint(nil, "Charcoal", 32, 128, nil)
local __g_charcoal01 = Goal:new(__g_finally_some, constraint, 88, "__g_charcoal01", false, __f_charcoal01)
builder:addGoal(__g_charcoal01)

constraint = Constraint:newItemConstraint(nil, "Charcoal", 129, 512, nil)
local __g_charcoal02 = Goal:new(__g_charcoal01, constraint, 87, "__g_charcoal02", false)
builder:addGoal(__g_charcoal02)

-----------------------------------------
-- Fourth Era (Aura Farming Era)

-- 01
constraint = Constraint:newBuildingConstraint(__dec_sp_storeroom, nil)
local __g_sp_storeroom01 = Goal:new(__g_coke_quad01, constraint, 60, "__g_sp_storeroom01", false)
builder:addGoal(__g_sp_storeroom01)

-- Q
--[[
local __q_you_are_not_prepared01 = {
    Constraint:newQuestObj("Seared Bricks", nil, 28),
    Constraint:newQuestObj("Smeltery Controller", nil, 1),
    Constraint:newQuestObj("Seared Tank", nil, 1),

    Constraint:newQuestObj("Casting Channel", nil, 2),
    Constraint:newQuestObj("Seared Faucet", nil, 2),
}

local __q_you_are_not_prepared02 = {

    Constraint:newQuestObj("Smeltery Drain", nil, 2),
    Constraint:newQuestObj("Casting Basin", nil, 1),
}

local __q_you_are_not_prepared03 = {
    Constraint:newQuestObj("Seared Stone", nil, 1),
    Constraint:newQuestObj("Casting Table", nil, 1),
}

constraint = Constraint:newQuestConstraint(__q_you_are_not_prepared01)
local __g_you_are_not_prepared01 = Goal:new(__g_sp_storeroom01, constraint, 40, "__g_you_are_not_prepared01", true)
builder:addGoal(__g_you_are_not_prepared01)

constraint = Constraint:newQuestConstraint(__q_you_are_not_prepared02)
local __g_you_are_not_prepared02 = Goal:new(__g_you_are_not_prepared01, constraint, 40, "__g_you_are_not_prepared02", true)
builder:addGoal(__g_you_are_not_prepared02)


-- 02
local function __f_tk_smeltery () print(comms.robot_send("info", "TK DONE; Remember to now do the thing manual like")) end
constraint = Constraint:newBuildingConstraint(__dec_tk_smeltery, nil)
local __g_tk_smeltery = Goal:new(__g_you_are_not_prepared02, constraint, 40, "__g_tk_smeltery", true, __f_tk_smeltery)
builder:addGoal(__g_tk_smeltery)

constraint = Constraint:newQuestConstraint(__q_you_are_not_prepared03)
local __g_you_are_not_prepared03 = Goal:new(__g_tk_smeltery, constraint, 40, "__g_you_are_not_prepared03", true)
builder:addGoal(__g_you_are_not_prepared03)
--]]

-- 03
local function __f_f_pickaxe01 () WHAT_LOADOUT = "third" end
constraint = Constraint:newItemConstraint(nil, "Flint Pickaxe", 2, 3, nil)
--local __g_f_pickaxe01 = Goal:new(__g_you_are_not_prepared03, constraint, 68, "__g_f_pickaxe01", false, __f_f_pickaxe01)
local __g_f_pickaxe01 = Goal:new(__g_sp_storeroom01, constraint, 68, "__g_f_pickaxe01", false, __f_f_pickaxe01)
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
constraint = Constraint:newItemConstraint(nil, "Bronze Ingot", 12, 12, nil)
local __g_bronze01 = Goal:new({__g_chalco01, __g_cassit01}, constraint, 40, "__g_bronze", true)
builder:addGoal(__g_bronze01)


-- Q5 Aura Farming Quest completions
local __q_copper = { Constraint:newQuestObj("Copper Ingot", nil, 48) }
constraint = Constraint:newQuestConstraint(__q_copper)
local __g_copper = Goal:new(__g_bronze01, constraint, 40, "__g_copper", true)
builder:addGoal(__g_copper)

local __q_tin = { Constraint:newQuestObj("Tin Ingot", nil, 16) }
constraint = Constraint:newQuestConstraint(__q_tin)
local __g_tin = Goal:new(__g_copper, constraint, 40, "__g_tin", true)
builder:addGoal(__g_tin)

local __q_making_bronze = { Constraint:newQuestObj("Bronze Ingot", nil, 32) }
constraint = Constraint:newQuestConstraint(__q_making_bronze)
local __g_making_bronze = Goal:new({__g_tin, __g_copper}, constraint, 40, "__g_making_bronze", true)
builder:addGoal(__g_making_bronze)

local __q_upgrade_2_0 = { Constraint:newQuestObj("Cobblestone", nil, 256) }
constraint = Constraint:newQuestConstraint(__q_upgrade_2_0)
local __g_upgrade_2_0 = Goal:new(__g_making_bronze, constraint, 40, "__g_upgrade_2_0", true)
builder:addGoal(__g_upgrade_2_0)

local __q_getting_iron = { Constraint:newQuestObj("Iron Ingot", nil, 72) }
constraint = Constraint:newQuestConstraint(__q_getting_iron)
local __g_getting_iron = Goal:new(__g_upgrade_2_0, constraint, 40, "__g_getting_iron", true)
builder:addGoal(__g_getting_iron)


local __q_important_tools = {
    Constraint:newQuestObj("Iron Hammer", nil, 1),
    Constraint:newQuestObj("Iron Wrench", nil, 1),
    Constraint:newQuestObj("Iron File", nil, 1),
    Constraint:newQuestObj("Iron Screwdriver", nil, 1),
    Constraint:newQuestObj("Iron Saw", nil, 1),
}
constraint = Constraint:newQuestConstraint(__q_important_tools)
local __g_important_tools = Goal:new(__g_getting_iron, constraint, 40, "__g_important_tools", true)
builder:addGoal(__g_important_tools)


local __q_you_shall_proceed = { Constraint:newQuestObj("Small Coal Boiler", nil, 1) }
constraint = Constraint:newQuestConstraint(__q_you_shall_proceed)
local __g_you_shall_proceed = Goal:new(__g_important_tools, constraint, 40, "__g_you_shall_proceed", true)
builder:addGoal(__g_you_shall_proceed)

builder:setDictionary(dictionary)
builder:addMultipleRecipes(essential_recipes)

local script = builder:build()

return script
