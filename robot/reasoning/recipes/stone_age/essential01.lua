local deep_copy = require("deep_copy")

local MetaDependency = require("reasoning.MetaRecipe.MetaDependency")
local MetaRecipe = require("reasoning.MetaRecipe")
local nav_obj = require("nav_module.nav_obj")
-- local gathering = require("reasoning.recipes.stone_age.gathering01")

-- luacheck: globals HAS_WOOD_FARM

local any_plank = {
    [1] = nil,
    [2] = "any:plank",
}
local any_log = {
    [1] = nil,
    [2] = "any:log",
}

local dictionary = {
    p = any_plank,
    l = any_log,
    g = "Gravel",
    f = "Flint",
    s = "Stick",
}

------ GATHER DEF -----------
local _, __r_ground_gather = dofile("/home/robot/reasoning/recipes/stone_age/gathering01.lua")
--local __r_ore_gather, _ = table.unpack(dofile("/home/robot/reasoning/recipes/stone_age/gathering_ore.lua"))
local __r_ore_gather, _ = table.unpack(require("reasoning.recipes.stone_age.gathering_ore"))

local __r_log01, _ = dofile("/home/robot/reasoning/recipes/stone_age/gathering_tree.lua")
-----------------------------

local __c_flint01 = {
'g', 'g',  0 ,
 0 , 'g',  0 ,
 0 ,  0 ,  0
}
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
local __c_flint_pickaxe = {
'f', 'f', 'f',
 0 , 's',  0 ,
 0 , 's',  0
}

-- Further refactoring will be necessary

local output
local dep

-- As you can see the dependencies of a building user are implicit
output = {lable = nil, name = "any:log"}
local __r_log02 = MetaRecipe:newBuildingUser(output, "oak_tree_farm", "raw_usage", nil, nil)

---
dep = MetaDependency:selectFromMultiple(__r_ground_gather, 3, nil, 1)
local __r_flint01 = MetaRecipe:newCraftingTable("Flint", __c_flint01, dep, nil)

---
output = { lable = nil, name = "any:plank" }
if HAS_WOOD_FARM then dep = MetaDependency:new(__r_log02, 1, "Optional")
else dep = MetaDependency:new(__r_log01, 1, "Optional") end
local __r_plank01 = MetaRecipe:newCraftingTable(output, __c_plank01, dep, nil)

--
dep = MetaDependency:new(__r_plank01, 1)
local __r_stick01 = MetaRecipe:newCraftingTable("Stick", __c_stick01, dep, nil)

local stick_dep = MetaDependency:new(__r_stick01, 2)
local flint_dep = MetaDependency:new(__r_flint01, 3)
local deps = {stick_dep, flint_dep}

local flint_pickaxe = MetaRecipe:newCraftingTable("Flint Pickaxe", __c_flint01, deps, nil)

-- return {{flint, flint_pickaxe, stick}, dictionary}  -- this means that the only "public dependencies" are: flint, flint_pickaxe and stick
                                                       -- we won't be directly crafting anything else


-- thank god we don't have to deal with ore-processing lines and multipliers n shit

-- TODO, FOR NOW, and for now only it is fine to simple deep_copy __r_ore_gather to define different
-- gatherings for different ore subtypes, since we'll only care about 3:
-- cassiterite sand, iron_ore, and copper_ore.
--
-- But this is memory inneficient, when we'll need to gather more ore-types this is simple too inneficient!
local __r_iron_ore_gather = deep_copy.copy(__r_ore_gather)
local ore_dep = MetaDependency:new(__r_iron_ore_gather, 1)
ore_dep.inlying_recipe.output = { lable = "Brown Limonite", name = "gregtech:raw_ore"}
ore_dep.inlying_recipe.mechanism.output = { lable = "Brown Limonite", name = "gregtech:raw_ore"}

output = { lable = "Iron Ingot", name = "any:ingot" }
local __r_iron01 = MetaRecipe:newBuildingUser(output, "small_home", "raw_usage", ore_dep, nil)
--local iron_ingot_dep


local recipe_table = {
    __r_log02,
    __r_flint01,
    __r_plank01,
    __r_ore_gather,

    __r_iron01,
}
return {recipe_table, dictionary}
