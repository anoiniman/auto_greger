require("deep_copy")
local type UniversalInfo = require("virtual.item.UniversalInfo")

local interface ParticularInfo
    damage: integer
    size: integer
end

local record ItemInfo
    parti: ParticularInfo
    uni: UniversalInfo
end

local default_item_info <total>: ItemInfo = {
    parti = {
        damage = -1,
        size = 0,
    },

    uni = {
        maxDamage = -1,
        maxSize = 64,

        name = "default",
        label = "default",
        equipment_data = {
            e_type = "none",
            level = -1,
        },

        use = nil,
    }
}

function ItemInfo:empty(): ItemInfo
    return COPY(default_item_info) as ItemInfo
end

function ItemInfo:fromUniversal(uni: UniversalInfo): ItemInfo
    local new = self:empty()
    new.uni = uni
    return new
end

function ItemInfo:defaultItem(): ItemInfo
    local new = self:empty()
    new.uni.name = "minecraft:dirt"
    new.uni.label = "Dirt"
    return new
end

function ItemInfo:newInstance(): ItemInfo
    return self:fromUniversal(self.uni)
end

function ItemInfo:isSame(item_info: ItemInfo): boolean
    return self.uni.label == item_info.uni.label and self.uni.name == item_info.uni.name
end

function ItemInfo:removeDurability(amount: integer)
    self.parti.damage = self.parti.damage + amount

    if self.parti.damage > self.uni.maxDamage then
        self.uni = default_item_info.uni
    end
end

return ItemInfo
