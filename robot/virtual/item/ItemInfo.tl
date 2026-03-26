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

function ItemInfo:empty(): ItemInfo
    local new = COPY(self) as ItemInfo
    new.parti = {
        damage = -1,
        size = 0,
    }
    new.uni = UniversalInfo:defaultUniversalInfo()
    return new
end

function ItemInfo:fromUniversal(uni: UniversalInfo): ItemInfo
    local new = self:empty()
    new.uni = uni
    return new
end

function ItemInfo:defaultItem(): ItemInfo
    local new = self:empty()
    new.uni = UniversalInfo:defaultUniversalInfo()
    return new
end

function ItemInfo:newInstance(): ItemInfo
    return self:fromUniversal(self.uni)
end

function ItemInfo:isSame(item_info: ItemInfo): boolean
    return self.uni:isSame(item_info.uni)
end

function ItemInfo:removeDurability(amount: integer)
    self.parti.damage = self.parti.damage + amount

    if self.parti.damage > self.uni.maxDamage then
        self.uni = UniversalInfo:defaultUniversalInfo()
    end
end

function ItemInfo:use()
    error("TODO!")
end

return ItemInfo
