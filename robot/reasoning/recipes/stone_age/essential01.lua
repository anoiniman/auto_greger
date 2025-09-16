-- luacheck: globals HAS_WOOD_FARM HAS_MORTAR
local deep_copy = require("deep_copy")

local MetaDependency = require("reasoning.MetaRecipe.MetaDependency")
local MetaRecipe = require("reasoning.MetaRecipe")
-- local nav_obj = require("nav_module.nav_obj")
-- local gathering = require("reasoning.recipes.stone_age.gathering01")


local any_plank = {
    [1] = nil,
    [2] = "any:plank",
}
local any_log = {
    [1] = nil,
    [2] = "any:log",
}
local any_fence = {
    [1] = nil,
    [2] = "any:fence",
}

local clay_ball = {
    [1] = "Clay",
    [2] = "minecraft:clay_ball",
}
local bad_cotton = {
    [1] = "Cotton",
    [2] = "harvestcraft:cottonItem" ,
}
local good_cotton = {
    [1] = "Cotton",
    [2] = "Natura:barleyFood", -- crazy
}

local coke_brick_item = {
    [1] = "Coke Oven Brick",
    [2] = "dreamcraft:item.CokeOvenBrick",
}
local coke_brick_block = {
    [1] = "Coke Oven Brick",
    [2] = "Railcraft:machine.alpha",
}


local dictionary = {
    ["p"] = any_plank,
    ["l"] = any_log,
    ["ol"] = "Oak Wood",

    ["c"] = "Cobblestone",
    ["S"] = "Stone",

    ["g"] = "Gravel",
    ["f"] = "Flint",

    ["s"] = "Stick",
    ["M"] = "Flint Mortar",

    ["C"] = "Chest",
    ["Ct"] = "Crafting Table",
    ["Fu"] = "Furnace",

    ["¢"] = "Carpet",
    ["ma"] = "Wooden Mallet",
    ["fk"] = "Flint Knife",
    ["F"] = any_fence,

    ["cb"] = clay_ball,
    ["cd"] = "Clay Dust",
    ["scd"] = "Small Pile of Clay Dust",

    ["wp"] = "Wood Pulp",
    ["wcb"] = "Water Clay Bucket",

    ["_co"] = bad_cotton,
    ["co"] = good_cotton,
    ["P"] = "Paper",
    ["bp"] = "Blank Pattern",
    ["Ob"] = "Oak Barricade",

    ["str"] = "String",

    ["sa"] = "Sand",
    ["wfb"] = "Wooden Form (Brick)",
    ["cbi"] = coke_brick_item,
    ["Gr"] = "Grout",

    ["sb"] = "Seared Brick",
    ["Sb"] = "Seared Bricks",
    ["sch"] = "Seared Channel",
    ["Sst"] = "Seared Stone",
}

------ GATHER DEF -----------
local _, __r_ground_gather = dofile("/home/robot/reasoning/recipes/stone_age/gathering01.lua")
--local __r_ore_gather, _ = table.unpack(dofile("/home/robot/reasoning/recipes/stone_age/gathering_ore.lua"))
local __r_ore_gather, _ = table.unpack(require("reasoning.recipes.stone_age.gathering_ore"))

local __r_log
local __r_log01, _ = dofile("/home/robot/reasoning/recipes/stone_age/gathering_tree.lua")
-----------------------------

local output
local dep1, dep2, dep3, dep4

-- <Logs>
-- Didn't add sapling recipe, because its logs but with a different output, and I hope for the best

-- As you can see the dependencies of a building user are implicit
output = {lable = nil, name = "any:log"}
local __r_log02 = MetaRecipe:newBuildingUser(output, "oak_tree_farm", "raw_usage", nil, nil)

if HAS_WOOD_FARM then __r_log = __r_log02
else __r_log = __r_log01 end

-- </Logs>


-- <Stone>

local __r_cobblestone =  MetaRecipe:newEmptyRecipe("Cobblestone", true)

dep1 = MetaDependency:new(__r_cobblestone, 1)
local __r_stone01 = MetaRecipe:newBuildingUser("Stone", "small_home", "raw_usage", dep1)

-- </Stone>


-- <Flint>
local __r_flint
local __c_flint01 = {
'g', 'g',  0 ,
 0 , 'g',  0 ,
 0 ,  0 ,  0
}
dep1 = MetaDependency:selectFromMultiple(__r_ground_gather, 3, nil, 1)
local __r_flint01 = MetaRecipe:newCraftingTable("Flint", __c_flint01, dep1)

local __c_flint_mortar = {
 0 , 'f',  0 ,
'S', 'f', 'S',
'S', 'S', 'S'
}
dep1 = MetaDependency:new(__r_flint01, 2)
dep2 = MetaDependency:new(__r_stone01, 5)
local __r_flint_mortar = MetaRecipe:newCraftingTable("Flint Mortar", __c_flint_mortar, {dep1, dep2})

local __c_flint02 = {
'M', 'g',  0 ,
 0 ,  0 ,  0 ,
 0 ,  0 ,  0
}

dep1 = MetaDependency:selectFromMultiple(__r_ground_gather, 1, nil, 1)
dep2 = MetaDependency:new(__r_flint_mortar, 0.00001)
local __r_flint02 = MetaRecipe:newCraftingTable("Flint", __c_flint02, {dep1, dep2})

if HAS_MORTAR then __r_flint = __r_flint02 else __r_flint = __r_flint01 end

-- </Flint>

-- <Wood>
local __c_plank01 = {
 0,  'l',  0 ,
 0 ,  0 ,  0 ,
 0 ,  0 ,  0
}
local __c_stick01 = {
 0,  'p',  0 ,
 0 , 'p',  0 ,
 0 ,  0 ,  0
}

output = { lable = nil, name = "any:plank" }
dep1 = MetaDependency:new(__r_log, 1, "Optional")
local __r_plank01 = MetaRecipe:newCraftingTable(output, __c_plank01, dep1, nil)

dep1 = MetaDependency:new(__r_plank01, 1)
local __r_stick01 = MetaRecipe:newCraftingTable("Stick", __c_stick01, dep1, nil)

-- </Wood>

-- <Flint Tools>
local __c_flint_pickaxe = {
'f', 'f', 'f',
 0 , 's',  0 ,
 0 , 's',  0
}
local __c_flint_axe = {
'f', 'f',  0 ,
'f', 's',  0 ,
 0 , 's',  0
}
local __c_flint_hoe = {
'f', 'f',  0 ,
 0 , 's',  0 ,
 0 , 's',  0
}
local __c_flint_shovel = {
 0 , 'f',  0 ,
 0 , 's',  0 ,
 0 , 's',  0
}

-- Doubl check this and the other related recipe
local __c_flint_knife = {
 0 , 'f',  0 ,
 0 , 's',  0 ,
 0 ,  0 ,  0
}

dep1 = MetaDependency:new(__r_stick01, 2)
dep2 = MetaDependency:new(__r_flint, 3)

local shared = {dep1, dep2}
local __r_flint_pickaxe = MetaRecipe:newCraftingTable("Flint Pickaxe", __c_flint_pickaxe, shared, nil)
local __r_flint_axe = MetaRecipe:newCraftingTable("Flint Axe", __c_flint_axe, shared, nil)

dep2 = MetaDependency:new(__r_flint, 2)
local __r_flint_hoe = MetaRecipe:newCraftingTable("Flint Hoe", __c_flint_hoe, {dep1, dep2})
-- local __r_flint_sword = MetaRecipe:newCraftingTable("Flint Sword

dep2 = MetaDependency:new(__r_flint, 1)
local __r_flint_shovel = MetaRecipe:newCraftingTable("Flint Shovel", __c_flint_shovel, {dep1, dep2}, nil)

dep1 = MetaDependency:new(__r_stick01, 1)
local __r_flint_knife = MetaRecipe:newCraftingTable("Flint Knife", __c_flint_knife, {dep1, dep2})

-- </Flint Tools>

-- <Furnace/Chest>

local __c_crafting_table01 = {
'f', 'f',  0 ,
'l', 'l',  0 ,
 0 ,  0 ,  0 ,
}

local __c_furnace01 = {
'c', 'c', 'c',
'f', 'f', 'f',
'c', 'c', 'c',
}
local __c_chest01 = {
'l', 'p', 'l',
'p', 'f', 'p',
'l', 'p', 'l',
}

dep1 = MetaDependency:new(__r_log, 2)
dep2 = MetaDependency:new(__r_flint, 2)
local __r_crafting_table01 = MetaRecipe:newCraftingTable("Crafting Table", __c_crafting_table01, {dep1, dep2})

dep1 = MetaDependency:new(__r_cobblestone, 6)
dep2 = MetaDependency:new(__r_flint, 3)
local __r_furnace01 = MetaRecipe:newCraftingTable("Furnace", __c_furnace01, {dep1, dep2})

dep1 = MetaDependency:new(__r_flint, 1)
dep2 = MetaDependency:new(__r_plank01, 4)
dep3 = MetaDependency:new(__r_log, 4)
local __r_chest01 = MetaRecipe:newCraftingTable("Chest", __c_chest01, {dep1, dep2, dep3})

-- </Furnace/Chest>

-- <Mallet>
local __c_mallet01 = {
'p', 'p',  0 ,
'p', 'p', 's',
'p', 'p',  0 ,
}

dep1 = MetaDependency:new(__r_plank01, 6)
dep2 = MetaDependency:new(__r_stick01, 1)
local __r_mallet01 = MetaRecipe:newCraftingTable("Wooden Mallet", __c_mallet01, {dep1, dep2})


-- </Mallet>

-- <Bed>

local __c_fence01 = {
's', 'p', 's',
's', 'p', 's',
's', 'p', 's',
}

local __c_carpet01 = {
'w', 'w',  0 ,
 0 ,  0 ,  0 ,
 0 ,  0 ,  0 ,
}

local __c_bed01 = {
'¢', '¢', '¢',
'p', 'p', 'p',
'F', 'ma','F',
}

dep1 = MetaDependency:new(__r_stick01, 6)
dep2 = MetaDependency:new(__r_plank01, 3)
local __r_fence01 = MetaRecipe:newCraftingTable(any_fence, __c_fence01, {dep1, dep2})

local __r_wool01 = MetaRecipe:newEmptyRecipe("Wool")

dep1 = MetaDependency:new(__r_wool01, 2)
local __r_carpet01 = MetaRecipe:newCraftingTable("Carpet", __c_carpet01, dep1)

dep1 = MetaDependency:new(__r_carpet01, 3)
dep2 = MetaDependency:new(__r_plank01, 3)
dep3 = MetaDependency:new(__r_fence01, 2)
dep4 = MetaDependency:new(__r_mallet01, 1)
local __r_bed01 = MetaRecipe:newCraftingTable("Bed", __c_bed01, {dep1, dep2, dep3, dep4})

-- </Bed>

-- <Clay Bucket>

-- correct ratios if necessary!
local __c_small_clay_dust01 = {
'M', 'cb',  0 ,
 0 ,  0 ,  0 ,
 0 ,  0 ,  0 ,
}

local __c_clay_dust01 = {
'scd', 'scd',  0 ,
'scd', 'scd',  0 ,
 0 ,  0 ,  0 ,
}

local __c_unfired_clay_bucket = {
 0 ,  0 ,  0 ,
'cd',  0 , 'cd',
'cd', 'cd','cd',
}

--[[local __r_clay_ball01 = deep_copy.copy(__r_ground_gather)
__r_clay_ball01.output = {lable = "Clay", name = "minecraft:clay_ball" }--]]

dep1 = MetaDependency:selectFromMultiple(__r_ground_gather, 3, nil, 3)
dep2 = MetaDependency:new(__r_flint_mortar, 0.00001)
local __r_small_clay_dust01 = MetaRecipe:newCraftingTable("Small Pile of Clay Dust", __c_small_clay_dust01, {dep1, dep2})

dep1 = MetaDependency:new(__r_small_clay_dust01, 4)
local __r_clay_dust01 = MetaRecipe:newCraftingTable("Clay Dust", __c_clay_dust01, dep1)

dep1 = MetaDependency:new(__r_clay_dust01, 5)
local __r_unfired_clay_bucket = MetaRecipe:newCraftingTable("Unfired Clay Bucket", __c_unfired_clay_bucket, dep1)

dep1 = MetaDependency:new(__r_unfired_clay_bucket, 1)
local __r_fired_clay_bucket = MetaRecipe:newBuildingUser("Fired Clay Bucket", "small_home", "raw_usage", dep1)

-- </Clay Bucket>

-- <Paper>

local __c_woodpulp01 = {
'M', 'l',  0 ,
 0 ,  0 ,  0 ,
 0 ,  0 ,  0 ,
}

local __c_paper01 = {
'wp', 'wp', 'wp',
'wp', 'wcb', 'wp',
'wp', 'wp', 'wp',
}

-- f this shit I'll just manually gather the water because f me alright?
local __r_water_clay_bucket = MetaRecipe:newEmptyRecipe("Water Clay Bucket", true)

dep1 = MetaDependency:new(__r_flint_mortar, 0.00001)
dep2 = MetaDependency:new(__r_log, 1)
local __r_wood_pulp01 = MetaRecipe:newCraftingTable("Wood Pulp", __c_woodpulp01, {dep1, dep2})

-- adjust multipliers if needed
dep1 = MetaDependency:new(__r_water_clay_bucket, 0.5)
dep2 = MetaDependency:new(__r_wood_pulp01, 4)
local __r_paper01 = MetaRecipe:newCraftingTable("Paper", __c_paper01, {dep1, dep2})

-- </Paper>

-- <Pattern n'shit>

local __c_good_cotton = {
 0 ,  0 ,  0 ,
'_co', '_co', 0,
 0 ,  0 ,  0 ,
}

local __c_string01 = {
 0 ,  0 ,  0 ,
'co', 'co','co' ,
 0 ,  0 ,  0 ,
}

local __r_bad_cotton = MetaRecipe:newEmptyRecipe(bad_cotton, true)

dep1 = MetaDependency:new(__r_bad_cotton, 2)
local __r_cotton01 = MetaRecipe:newCraftingTable(good_cotton, __c_good_cotton, dep1)

dep1 = MetaDependency:new(__r_cotton01, 3)
local __r_string01 = MetaRecipe:newCraftingTable("String", __c_string01, dep1)


local __c_blankpattern = {
'P', 'P',  0 ,
'P', 'P',  0 ,
 0 ,  0 ,  0 ,
}

dep1 = MetaDependency:new(__r_paper01, 4)
local __r_blankpattern = MetaRecipe:newCraftingTable("Blank Pattern", __c_blankpattern, dep1)

-- </Pattern>

-- <Tinkers Quest>

local __c_oak_barricade = {
 0 , 'ol',  0  ,
'ol','str','ol',
 0 , 'ol' ,  0 ,
}

local __c_pattern_chest = {
's', 'bp', 's' ,
's', 'C' , 's' ,
 0 , 'ma' ,  0 ,
}

local __c_tool_station = {
's', 'bp', 's' ,
's', 'Ct', 's' ,
 0 , 'ma' ,  0 ,
}

local __c_stencil_table = {
's', 'bp', 's' ,
'F', 's' , 'F',
 0 , 'ma' ,  0 ,
}

local __c_part_builder = {
's', 'bp', 's' ,
'Ob','s' ,'Ob',
 0 , 'ma' ,  0 ,
}

dep1 = MetaDependency:new(__r_log, 4)
dep2 = MetaDependency:new(__r_string01, 1)
local __r_oak_barricade = MetaRecipe:newCraftingTable("Oak Barricade", __c_oak_barricade, {dep1, dep2})

dep1 = MetaDependency:new(__r_stick01, 3)
dep2 = MetaDependency:new(__r_blankpattern, 1)
dep3 = MetaDependency:new(__r_oak_barricade, 2)
dep4 = MetaDependency:new(__r_mallet01, 1)
local __r_part_builder = MetaRecipe:newCraftingTable("Part Builder", __c_part_builder, {dep1, dep2, dep3, dep4})

dep3 = MetaDependency:new(__r_fence01, 2)
local __r_stencil_table = MetaRecipe:newCraftingTable("Stencil Table", __c_stencil_table, {dep1, dep2, dep3, dep4})

dep1 = MetaDependency:new(__r_stick01, 4)
-- dep2 = MetaDependency:new(__
dep3 = MetaDependency:new(__r_crafting_table01, 1)
local __r_tool_station = MetaRecipe:newCraftingTable("Tool Station", __c_tool_station, {dep1, dep2, dep3, dep4})

dep3 = MetaDependency:new(__r_chest01, 1)
local __r_pattern_chest = MetaRecipe:newCraftingTable("Pattern Chest", __c_pattern_chest, {dep1, dep2, dep3, dep4})

-- </Tinkers Quest>

-- <I'm bricked up, and so on>

local __c_wooden_brick_form = {
'bp',  0 ,  0 ,
'fk',  0 ,  0 ,
 0 ,  0 ,  0 ,
}

local __c_unfired_coke_brick = {
'cb', 'cb', 'cb',
'sa', 'wfb','sa',
'sa', 'sa', 'sa',
}

local __c_coke_brick_block = {
'cbi', 'cbi',  0 ,
'cbi', 'cbi',  0 ,
 0 ,  0 ,  0 ,
}

dep1 = MetaDependency:new(__r_blankpattern, 1)
dep2 = MetaDependency:new(__r_flint_knife, 1)
local __r_wooden_brick_form = MetaRecipe:newCraftingTable("Wooden Form (Brick)", __c_wooden_brick_form, {dep1, dep2})


-- Hopefully this works, I know this kinds of recipes are a bit buggy, but holy these dependency definitions :sob:
dep1 = MetaDependency:selectFromMultiple(__r_ground_gather, 3/3, nil, 3) -- clay
dep2 = MetaDependency:selectFromMultiple(__r_ground_gather, 5/3, nil, 2) -- sand
dep3 = MetaDependency:new(__r_wooden_brick_form, 0.000001)
local __d_wooden_brick_form = dep3
local __r_unfired_coke_brick = MetaRecipe:newCraftingTable("Unfired Coke Oven Brick", __c_unfired_coke_brick, {dep1, dep2, dep3})

dep1 = MetaDependency:new(__r_unfired_coke_brick, 1)
local __r_coke_brick_item = MetaRecipe:newBuildingUser(coke_brick_item, "small_home", "raw_usage", dep1)

dep1 = MetaDependency:new(__r_coke_brick_item, 4)
local __r_coke_brick_block = MetaRecipe:newCraftingTable(coke_brick_block, __c_coke_brick_block, dep1)

-- </I'm bricked up, and so on>

-- <Charcoal>

dep1 = MetaDependency:new(__r_log, 1)
local __r_charcoal = MetaRecipe:newBuildingUser("Charcoal", "coke_quad", "raw_usage", dep1)

-- This definition for any_fuel is temporary as is obvious :)
local __r_any_fuel = MetaRecipe:newBuildingUser({[1] = nil, [2] = "any:fuel" }, "coke_quad", "raw_usage", dep1)
-- </Charcoal>


-- <Smeltery Basics>

local __c_grout01 = {
'g', 'g', 'g',
'cb', 'wcb','cb',
'sa', 'sa', 'sa',
}
local __c_unfired_seared_brick = {
'Gr', 'Gr', 'Gr',
'Gr', 'wfb','Gr',
'Gr', 'Gr', 'Gr',
}
local __c_seared_bricks = {
'sb', 'sb', 'sb',
'sb', 'wcb','sb',
'sb', 'sb', 'sb',
}


-- todo: add, not just multiplier, but also "min" to the dependencies, yup, shouldn't be too hard and it'll save us from some headaches
-- I'll actually hold-off on that since the crafting logic seems to handle it well enough, the problem is just logistical, aka
-- we might not have enough in the inventory to complete a minimum craft, if that happens all we need to do is add some extra goal constraints
-- aka: not worth it for now, I'll fix it later
dep1 = MetaDependency:selectFromMultiple(__r_ground_gather, 3/4, nil, 1) -- gravel
dep2 = MetaDependency:selectFromMultiple(__r_ground_gather, 3/4, nil, 2) -- sand
dep3 = MetaDependency:new(__r_water_clay_bucket, 1/4)
local __r_grout01 = MetaRecipe:newCraftingTable("Grout", __c_grout01, {dep1, dep2, dep3})

dep1 = __d_wooden_brick_form
dep2 = MetaDependency:new(__r_grout01, 8)
local __r_unfired_seared_brick = MetaRecipe:newCraftingTable("Unfired Seared Brick", __c_unfired_seared_brick, {dep1, dep2})

dep1 = MetaDependency:new(__r_unfired_seared_brick, 1)
local __r_seared_brick = MetaRecipe:newBuildingUser("Seared Brick", "small_home", "raw_usage", dep1)

dep1 = MetaDependency:new(__r_seared_brick, 8/2)
dep2 = MetaDependency:new(__r_water_clay_bucket, 1/2)
local __r_seared_bricks = MetaRecipe:newCraftingTable("Seared Bricks", __c_seared_bricks, {dep1, dep2})


-- </Smeltery Basics>

-- <Smeltery de-facto>

local __c_seared_faucet = {
 0 ,    0 ,  0 ,
'sb',   0 , 'sb',
'sb', 'sb', 'sb',
}

local __c_casting_channel = {
'sb',   0 , 'sb',
'sb',   0 , 'sb',
'sb', 'sb', 'sb',
}

local __c_casting_table = {
'sb',   0 , 'sb',
'Sb', 'Sst','Sb',
'Sb',   0 , 'Sb',
}

local __c_casting_basin = {
'Sb',   0 , 'Sb',
'Sb',   0 , 'Sb',
'Sb', 'Sb', 'Sb',
}

local __c_smeltery_drain = {
'sb', 'sb', 'sb',
'sb', 'sch','sb',
'sb', 'sb', 'sb',
}

local __c_seared_tank = {
'Sb', 'sb', 'Sb',
'sb',   0 , 'sb',
'Sb', 'sb', 'Sb',
}

local __c_smeltery_controller = {
'Sb', 'sb', 'Sb',
'sb', 'Fu', 'sb',
'Sb', 'sb', 'Sb',
}

local dep1 = MetaDependency:new(__r_seared_brick, 4)
local dep2 = MetaDependency:new(__r_seared_bricks, 4)
local dep3 = MetaDependency:new(__r_furnace01, 1)
local __r_smeltery_controller = MetaRecipe:newCraftingTable("Smeltery Controller", __c_smeltery_controller, {dep1, dep2, dep3})

local __r_seared_tank = MetaRecipe:newCraftingTable("Seared Tank", __c_seared_tank, {dep1, dep2})

dep1 = MetaDependency:new(__r_seared_brick, 7)
local __r_casting_channel = MetaRecipe:newCraftingTable("Casting Channel", __c_casting_channel, dep1)

dep1 = MetaDependency:new(__r_seared_brick, 5)
local __r_seared_faucet = MetaRecipe:newCraftingTable("Seared Faucet", __c_seared_faucet, dep1)

dep1 = MetaDependency:new(__r_seared_brick, 8)
dep2 = MetaDependency:new(__r_casting_channel, 1)
local __r_smeltery_drain = MetaRecipe:newCraftingTable("Smeltery Drain", __c_smeltery_drain, {dep1, dep2})

dep1 = MetaDependency:new(__r_seared_bricks, 7)
local __r_casting_basin = MetaRecipe:newCraftingTable("Casting Basin", __c_casting_basin, dep1)

local __r_seared_stone = MetaRecipe:newEmptyRecipe("Seared Stone", true)

dep1 = MetaDependency:new(__r_seared_brick, 2)
dep2 = MetaDependency:new(__r_seared_bricks, 4)
dep3 = MetaDependency:new(__r_seared_stone, 1)
local __r_casting_table = MetaRecipe:newCraftingTable("Casting Table", __c_casting_table, {dep1, dep2, dep3})

-- </Smeltery de-facto>

-- <Ingots>

-- One day we'll have better handling of overlapping recipes, for now we'll only use chalcopyrite
local output = { lable = "Raw Chalcopyrite Ore", name = "gregtech:raw_ore"}
local __r_copper_ore = MetaRecipe:newEmptyRecipe("nil")
__r_copper_ore.inlying_recipe.output = output
__r_copper_ore.inlying_recipe.mechanism.output = deep_copy.copy(output)

dep1 = MetaDependency:new(__r_copper_ore, 1)
local __r_copper_ingot = MetaRecipe:newBuildingUser("Copper Ingot", "small_home", "raw_usage", dep1)


local output = { lable = "Raw Cassiterite Sand Ore", name = "gregtech:raw_ore"}
local __r_tin_ore = MetaRecipe:newEmptyRecipe("nil")
__r_tin_ore.inlying_recipe.output = output
__r_tin_ore.inlying_recipe.mechanism.output = deep_copy.copy(output)

dep1 = MetaDependency:new(__r_tin_ore, 0.5)
local __r_tin_ingot = MetaRecipe:newBuildingUser("Tin Ingot", "small_home", "raw_usage", dep1)

local output = { lable = "Raw Brown Limonite Ore", name = "gregtech:raw_ore"}
local __r_iron_ore = MetaRecipe:newEmptyRecipe("nil")
__r_iron_ore.inlying_recipe.output = output
__r_iron_ore.inlying_recipe.mechanism.output = deep_copy.copy(output)

dep1 = MetaDependency:new(__r_iron_ore, 0.5)
local __r_iron_ingot = MetaRecipe:newBuildingUser("Iron Ingot", "small_home", "raw_usage", dep1)

-- </Ingots>


local recipe_table = {
    __r_flint,
    __r_flint_mortar,

    __r_log,
    __r_plank01,
    __r_stick01,

    __r_flint_pickaxe,
    __r_flint_axe,
    __r_flint_shovel,
    __r_flint_hoe,

    __r_furnace01,
    __r_chest01,
    __r_bed01,

    __r_mallet01,
    __r_fired_clay_bucket,
    __r_paper01,
    -- __r_water_clay_bucket,

    __r_part_builder,
    __r_stencil_table,
    __r_tool_station,
    __r_pattern_chest,

    __r_wooden_brick_form,
    __r_coke_brick_item,
    __r_coke_brick_block,

    __r_charcoal,
    __r_any_fuel,

    --
    __r_seared_brick,
    __r_seared_bricks,
    __r_seared_stone,
    __r_seared_faucet,
    __r_seared_tank,

    __r_casting_channel,
    __r_casting_basin,
    __r_casting_table,

    __r_smeltery_controller,
    __r_smeltery_drain,
    --

    __r_copper_ingot,
    __r_tin_ingot,
    __r_bronze_ingot,
    __r_iron_ingot,

    __r_ore_gather,
    __r_ground_gather,
}
return {recipe_table, dictionary}
