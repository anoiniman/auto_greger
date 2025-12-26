local deep_copy = require("deep_copy")
local ItemInfo = {
    damage = -1,
    maxDamage = -1,
    size = 0,
    maxSize = 64,

    name = "nil",
    label = "nil",
}

function ItemInfo:empty()
    return COPY(self) 
end

function ItemInfo:fromPartialTable(table)
    local new = COPY(self)
    for key, value in pairs(table) do
        new.key = value
    end
    return new
end

return ItemInfo
