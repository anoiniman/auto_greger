local module = {}
local MetaRecipe = require("reasoning.MetaRecipe")
local nav_obj = require("nav_module.nav_obj")
local sweep = require("complex_algorithms.sweep")

-- As you know very well, there are certain, specific, recipes that require oak logs rather than
-- any log, and others (more plentiful than the former) that function only with vanilla logs
-- but, for compatibility, we'll use oak_logs as our only vanilla logs
-- maybe spruce wood for charcoaling_wood, but in general prioritise oak logs
-- unless ya'know anything else is needed but hey.
local module.dictionary = { ol = "oak_log", g = "gravel", f = "flint", s = "stick" }

local temp = nil
local algo_pass = nil


-- If tool level is 0 then it means it may also be broken by hand
local oak_log = MetaRecipe:newGathering("oak_log", "axe", 0, log_algo, algo_pass)


-- change_state at first will be a chunk table {0, 0}
local function grav_algo(state, change_state, nav_obj) -- nav_obj will be algo_pass[1]
    local what_chunk = change_state[1] -- or -- local what_chunk = change_state?
    local result, data = sweep(what_chunk) -- very much temporary
    if result == false then
        if data ~= nil then -- probably means that we've run into an obstacle
            -- TODO stuff with this obstacle data 
        else
            print(comms.robot_send("error", "grav_algo ran into unrecoverable error in navigation"))
            return false -- error
        end
    end
    -- TODO Now we need to check if there is anything of interest below us and stuff


    return true
end

algo_pass[1] = nav_obj -- nav_obj is passed by reference, as should be obvious
local gravel = MetaRecipe:newGathering("gravel", "shovel", 0, grav_algo, algo_pass)

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
