-- luacheck: globals HAS_WOOD_FARM HAS_MORTAR
-- local deep_copy = require("deep_copy")

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

local dictionary = {
    ["p"] = any_plank,
    ["l"] = any_log,

    ["c"] = "Cobblestone",
    ["S"] = "Stone",

    ["g"] = "Gravel",
    ["f"] = "Flint",

    ["s"] = "Stick",
    ["M"] = "Flint Mortar",

    ["¢"] = "Carpet",
    ["ma"] = "Wooden Mallet",
    ["F"] = any_fence,

    ["cb"] = clay_ball,
    ["cd"] = "Clay Dust",
    ["scd"] = "Small Pile of Clay Dust",
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

local __r_cobblestone =  MetaRecipe:newEmptyRecipe("Cobblestone")

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
dep2 = MetaDependency:new(__r_flint_mortar, 1)
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

-- </Flint Tools>

-- <Furnace/Chest>
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

-- <>

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

dep1 = MetaDependency:new(__r_clay_ball01,  1)
dep2 = MetaDependency:new(__r_flint_mortar, 1)
local __r_small_clay_dust01 = MetaRecipe:newCraftingTable("Clay Dust", __c_small_clay_dust01, {dep1, dep2})

dep1 = MetaDependency:new(__r_small_clay_dust01, 4)
local __r_clay_dust01 = MetaRecipe:newCraftingTable("Clay Dust", __c_clay_dust01, dep1)

dep1 = MetaDependency:new(__r_clay_dust01, 5)
local __r_unfired_clay_bucket = MetaRecipe:newCraftingTable("Unfired Clay Bucket", __c_unfired_clay_bucket, dep1)

-- TODO -> fired clay bucket


-- </>


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

    __r_ore_gather,
    __r_ground_gather,
}
return {recipe_table, dictionary}
