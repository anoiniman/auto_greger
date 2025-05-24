local deep_copy = require("deep_copy")
local Module = {
    material = nil,
    item_name = nil, -- a base name such as "sword"
    item_level = nil,
}

function Module:new(item_name)
    local new = deep_copy.copy(self, pairs)
    new.material = "none"
    new.item_name = item_name
    new.item_level = -1

    return new
end

return Module
