--[[local deep_copy = require("deep_copy")
local comms = require("comms")--]]

-- replaced input multiplier, by a less hacky and safer quantity needed directive, it'll make resolution
-- of recipes harder to write, but it'll be written better
require("Task")

global enum DependencyType
    "Normal"
    "Optional"
end

global type MetaRecipe;
global interface MetaDependency
    inlying_recipe: MetaRecipe

    quantity_needed: integer
    dep_type: DependencyType
end

local record module end
function module.new<S is TaskState>(
    inlying_recipe: MetaRecipe<S>,
    quantity_needed: integer,
    dep_type: DependencyType
): MetaDependency
    local new: MetaDependency = {
        inlying_recipe = inlying_recipe,
        quantity_needed = quantity_needed,
        dep_type = dep_type
    }
    return new
end

function module.new_normal<S is TaskState>(inlying_recipe: MetaRecipe<S>, quantity_needed: integer): MetaDependency
    return module.new(inlying_recipe, quantity_needed, "Normal")
end

-- this selects 1 recipe to be utilised from a recipe defined has having multiple outputs
-- this is a massive hack, hopefully we'll improve this in the futre (TODO)
--[[function module.select_from_multiple(recipe: MetaRecipe, quantity_needed: integer, dep_type: DependencyType, index: integer)
    ----- HACKY SHIT ------
    local recipe_copy = deep_copy.copy(recipe, pairs)
    -- new_output.lable = recipe_copy.output.lable[index]
    -- new_output.name = recipe_copy.output.name[index]
    local new_output = deep_copy.copy(recipe_copy.output[index])
    recipe_copy.output = new_output

    return module.new(recipe_copy, multiplier, dep_type)
end--]]

return module
