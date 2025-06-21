local deep_copy = require("deep_copy")

local Module = {
    from_inventory = nil,
    to_inventory = nil,

    
}

function Module:new(from_inventory, to_inventory)
    local new = deep_copy.copy(self, pairs)
    new.from_inventory = from_inventory
    new.to_inventory = to_inventory
    return new
end

function Module:navigate()

end


return Module
