local deep_copy = require("deep_copy")
local comms = require("comms")

local MetaDependency = {
    dep_type = nil,
    dep_id = nil,
}
local function MetaDependency:new(dep_type, dep_id)
    local new = deep_copy.copy(self, pairs)
    new.dep_type = dep_type
    new.dep_id = dep_id
    return new
end

return MetaDependency
