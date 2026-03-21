local ItemInfo = require("virtual.item.ItemInfo")
local record KnownItems
    known_items: {ItemInfo} 
    getByLabel: function (KnownItems, string): ItemInfo | nil
    getByItemInfo: function (KnownItems, ItemInfo): ItemInfo | nil
end

function KnownItems:register(new: ItemInfo)
    local found_item = self:getByItemInfo(new)
    if not (found_item is nil) then return end
    table.insert(self.known_items, new)
end

function KnownItems:getByLabel(label: string): ItemInfo | nil
    for _, item_info in ipairs(self.known_items) do
        if item_info.uni.label == label then return item_info:newInstance() end
    end

    return nil
end

function KnownItems:getByItemInfo(i_item_info: ItemInfo): ItemInfo | nil
    for _, item_info in ipairs(self.known_items) do
        if item_info:isSame(i_item_info) then return item_info:newInstance() end
    end
    return nil
end


return KnownItems
