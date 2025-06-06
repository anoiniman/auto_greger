local deep_copy = require("deep_copy")
local comms = require("comms")

-- this whole ""class"" might be kinda useless since recipes in themselves already carry enough information about
-- themselves such that they might be added (as_ref) as a dependency of another recipe
local MetaDependency = {
    dep_type = nil,
    dep_id = nil, -- 
}
function MetaDependency:new(dep_type, dep_id)
    local new = deep_copy.copy(self, pairs)
    new.dep_type = dep_type
    new.dep_id = dep_id
    return new
end

function MetaDependency:newItemDependency(name, lable)

end

return MetaDependency
