local module = {}
local MetaRecipe = require("reasoning.MetaRecipe")

local module.dictionary = { g = "gravel", f = "flint", s = "stick" }
local temp = nil

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


return module
