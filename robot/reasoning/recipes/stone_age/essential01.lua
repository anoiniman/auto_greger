local MetaDependency = require("reasoning.MetaRecipe.MetaDependency")
local MetaRecipe = require("reasoning.MetaRecipe")
local nav_obj = require("nav_module.nav_obj")
-- local gathering = require("reasoning.recipes.stone_age.gathering01")

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

local temp
local deps

-- gather recipes (gravel, all_gather)
local _, all_gather = dofile("/home/robot/reasoning/recipes/stone_age/gathering01.lua")

temp = {
'g', 'g',  0 ,
 0 , 'g',  0 ,
 0 ,  0 ,  0
}
local gravel_dep = MetaDependency:selectFromMultiple(all_gather, 3, nil, 1) -- index is hardcoded be mindful with changes
local flint = MetaRecipe:newCraftingTable("Flint", temp, gravel_dep, nil)

-- We'll have multiple wood dependencies, because of: "wood farming/wood gathering/oak farming/spruce farming"
-- So we'll have to eventually implement the OR dependency thing (TODO)

-- local wood1 = MetaRecipe:newGathering("Wood etc.
local output = {lable = nil, name = "any:log"}
local wood = MetaRecipe:newBuildingUser(output, "oak_tree_farm", "no_store", nil, nil)

temp = {
 0,  'l',  0 ,
 0 ,  0 ,  0 ,
 0 ,  0 ,  0
}
local wood_dep = MetaDependency:new(wood, 1)
output = {
    lable = nil,
    name = "any:plank"
}
local plank = MetaRecipe:newCraftingTable(output, temp, wood_dep, nil)


temp = {
 0,  'p',  0 ,
 0 , 'p',  0 ,
 0 ,  0 ,  0
}
local plank_dep = MetaDependency:new(plank, 2)
local stick = MetaRecipe:newCraftingTable("Stick", temp, plank_dep, nil)

temp = {
'f', 'f', 'f',
 0 , 's',  0 ,
 0 , 's',  0
}
local stick_dep = MetaDependency:new(flint, 3)
local flint_dep = MetaDependency:new(stick, 2)
deps = {stick_dep, flint_dep}

local flint_pickaxe = MetaRecipe:newCraftingTable("Flint Pickaxe", temp, deps, nil)

return {{flint, flint_pickaxe, stick}, dictionary} -- this means that the only "public dependencies" are: flint, flint_pickaxe and stick
