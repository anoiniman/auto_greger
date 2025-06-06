local module = {}
local MetaRecipe = require("reasoning.MetaRecipe")
local nav_obj = require("nav_module.nav_obj")
local sweep = require("complex_algorithms.sweep")

-- As you know very well, there are certain, specific, recipes that require oak logs rather than
-- any log, and others (more plentiful than the former) that function only with vanilla logs
-- but, for compatibility, we'll use oak_logs as our only vanilla logs
-- maybe spruce wood for charcoaling_wood, but in general prioritise oak logs
-- unless ya'know anything else is needed but hey.
local temp = nil
local algo_pass = nil

local tree_build = MetaRecipe:newBuildingUser("Oak Log", "oak_tree_farm", "no_store", nil, nil) -- no dep for testing
local charcoal = MetaRecipe:newBuildingUser("Charcoal", "coke_quad", "raw_usage", nil, tree_build)

return charcoal
