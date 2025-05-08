local reason_obj = {}

local deep_copy = require("deep_copy")

local MetaRecipe = require("reasoning.MetaRecipe")
local MSBuilder, Goal, Requirement = require("reasoning.MetaScript")

-- Have the recipes be dynamically loaded-unloaded with doFile, rather than required
-- because, you, know there are a lot of recipes, do the same for scripts
local scripts = {}
local recipes = {}

local cur_script = nil

function reason_obj.reason()

end

return reason_obj
