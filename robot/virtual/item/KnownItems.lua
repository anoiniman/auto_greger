local KnownItems = {known_items = {}}

function KnownItems:register(new)
    if self:getByItemInfo(new) ~= nil then return end
    table.insert(self.known_items, new)
end

function KnownItems:getByLabel(label)
    for _, item_info in ipairs(self.known_items) do
        if item_info.label == label then return COPY(item_info) end
    end

    return nil
end

function KnownItems:getByItemInfo(item_info)
    for _, item_info in ipairs(self.known_items) do
        if item_info:isSame(item_info) then return COPY(block) end
    end
    return nil
end


return KnownItems
