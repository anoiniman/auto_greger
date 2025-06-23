local module = {}
local MetaRecipe = require("reasoning.MetaRecipe")
local nav_obj = require("nav_module.nav_obj")
local sweep = require("complex_algorithms.sweep")

-- As you know very well, there are certain, specific, recipes that require oak logs rather than
-- any log, and others (more plentiful than the former) that function only with vanilla logs
-- but, for compatibility, we'll use oak_logs as our only vanilla logs
-- maybe spruce wood for charcoaling_wood, but in general prioritise oak logs
-- unless ya'know anything else is needed but hey.
local module.dictionary = { ol = "Oak Wood", g = "Gravel", f = "Flint", s = "Stick" }

local temp = nil
local algo_pass = nil

-- fing a way to include the 2 flint recipes, and only to the "better one" when a certain
-- milestone is passed
-- TODO: Add milestones to distinguish which recipe with the same output to use
temp = {
'g', 'g',  0 ,
 0 , 'g',  0 ,
 0 ,  0 ,  0
}
local flint = MetaRecipe:newCraftingTable("flint", temp)

temp = {
'f', 'f', 'f',
 0 , 's',  0 ,
 0 , 's',  0
}
-- Have it so both "full-names" and "dictionary-names" can be used in the "output" space/variable/slot
-- or maybe "output" name it is not necessary since, it is alredy identified by variable name inside
-- recipe collection, food for thought maaaaaan, swwwwweeeeeeettt riiiiideeeeee maaaaaann!
-- but since many "outputs" have different recipes that make them the namespace is already à priori
-- polluted????? FFFAAAAAAAAKKKKKK
local flint_pickaxe = MetaRecipe:newCraftingTable("flint_pickaxe", temp)
-- module[1] = flint; module[2] = flint_pickaxe


-- is setting the dependency really needed
local charcoal = MetaRecipe:newBuildingUser("Charcoal", "coke_quad")

return module
