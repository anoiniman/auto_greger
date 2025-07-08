local deep_copy = require("deep_copy")
local comms = require("comms")

local MetaDependency = require("reasoning.MetaRecipe.MetaDependency")
local MetaRecipe = require("reasoning.MetaRecipe")

local ToolInfo = {
    tool_type = "",
    tool_level = -1,
    inner_dep = nil,
}
function ToolInfo:new(dep, t_type, level)
    local new = deep_copy.copy(self, pairs)
    if dep == nil or t_type == nil or level == nil then error(comms.robot_send("fatal", "You are stupid")) end


    new.tool_type = t_type
    new.tool_level = level
    new.inner_dep = dep
    return new
end


local essential_recipes, _ = dofile("/home/robot/reasoning/recipes/stone_age/essential01.lua")
local dictionary = {
    s = "Stick",
    f = "Flint",
}

local flint = essential_recipes[1]
local stick = essential_recipes[3]

-- Make it so it knows how and when to upgrade tools TODO (one day)
local temp = {
 0 , 'f',  0 ,
 0 , 's',  0 ,
 0 , 's',  0
}

local stick_dep = MetaDependency:new(stick, 2)
local flint_dep = MetaDependency:new(flint, 1)

local deps = {flint_dep, stick_dep}
local test_shovel = MetaRecipe:newCraftingTable("Flint Shovel", temp, deps, nil)


return {{ToolInfo:new(test_shovel, "shovel", 1)}, dictionary}
