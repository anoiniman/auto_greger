local MetaRecipe = require("reasoning.MetaRecipe")
local MetaDependency = require("reasoning.MetaRecipe.MetaDependency")

-- As you know very well, there are certain, specific, recipes that require oak logs rather than
-- any log, and others (more plentiful than the former) that function only with vanilla logs
-- but, for compatibility, we'll use oak_logs as our only vanilla logs
-- maybe spruce wood for charcoaling_wood, but in general prioritise oak logs
-- unless ya'know anything else is needed but hey.

-- "raw_usage", "no_store" are possible modes of operation

local tree_build = MetaRecipe:newBuildingUser("Oak Wood", "oak_tree_farm", "no_store", nil, nil) -- no dep for testing

local c_tree_build = MetaDependency:new(tree_build, 1) -- aka, it's 1 to 1
local output = {lable = "Charcoal", name = "minecraft:coal"}
local charcoal = MetaRecipe:newBuildingUser(output, "coke_quad", "no_store", nil, c_tree_build)

return {tree_build, charcoal}
