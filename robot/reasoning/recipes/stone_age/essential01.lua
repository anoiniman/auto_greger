local module = {}
local MetaRecipe = require("reasoning.MetaRecipe")

local module.dictionary = { g = "gravel", f = "flint", s = "stick" }
local temp = nil

-- change_state at first will be a chunk table {0, 0}
local function grav_algo(state, change_state, nav_obj)
    if state == nil then
        state = {}
        nav_obj.prepare_sweep(what_chunk)
        state[1] = "prepare_sweep"
        return state
    end

    return state
end

local gravel = MetaRecipe:newGathering("gravel", "shovel", 0, nil, "gravel")

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

module[1] = flint; module[2] = flint_pickaxe


return module
