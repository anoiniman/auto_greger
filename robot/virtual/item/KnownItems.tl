local UniversalInfo = require("virtual.item.UniversalInfo")
local record KnownItems
    known_items: {UniversalInfo} 
    getByLabel: function (KnownItems, string): UniversalInfo | nil
    getByItemInfo: function (KnownItems, UniversalInfo): UniversalInfo | nil
end
KnownItems.known_items = {}

function KnownItems:register(new: UniversalInfo)
    local found_item = self:getByItemInfo(new)
    if not (found_item is nil) then return end
    table.insert(self.known_items, new)
end

function KnownItems:getByLabel(label: string): UniversalInfo | nil
    for _, item_info in ipairs(self.known_items) do
        if item_info.label == label then return item_info end
    end

    return nil
end

function KnownItems:getByItemInfo(i_item_info: UniversalInfo): UniversalInfo | nil
    for _, item_info in ipairs(self.known_items) do
        if item_info:isSame(i_item_info) then return item_info end
    end
    return nil
end


return KnownItems
