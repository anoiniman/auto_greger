require("deep_copy")
local ItemInfo = {
    damage = -1,
    maxDamage = -1,
    size = 0,
    maxSize = 64,

    name = "nil",
    label = "nil",
    equipment_data = {
        type = "none",
        level = -1,
    },

    use = nil,
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

function ItemInfo:defaultBlock()
    local new = COPY(self)
    new.name = "minecraft:dirt"
    new.lable = "Dirt"
    return new
end

function ItemInfo:isSame(item_info)
    return self.label == item_info.label and self.name == item_info.name
end

function ItemInfo:removeDurability(amount)
    self.damage = self.damage + amount

    if self.damage > self.maxDamage then
        local empty = ItemInfo:empty()
        for key, value in pairs(empty) do
            self[key] = value
        end
    end
end

return ItemInfo
