local deep_copy = require("deep_copy")
local comms = require("comms")

local MetaDependency = {
    inlying_recipe = nil,
    input_multiplier = 1,   -- how many of more input do you need for 1 output, for example:
                            -- 1x flint-pickaxe needs x3 flint and x2 sticks, in the
                            -- flitn dependency set multiplier to 3/1 = 3
    dep_type = "Normal",
}
function MetaDependency:new(recipe, multiplier, dep_type)
    local new = deep_copy.copy(self, pairs)
    if recipe == nil then
        error(comms.robot_send("fatal", "MetaDependency:new, no recipe?"))
    end
    if dep_type ~= nil then new.dep_type = dep_type end

    new.inlying_recipe = recipe
    new.input_multiplier = multiplier
    return new
end

return MetaDependency
