local ItemInfo = require("virtual.item.ItemInfo")

local Slot = {
    is_empty = true,
    item = nil,
}
function Slot:empty()
    return COPY(self)
end


local Inventory = {inner = {}}
function Inventory:new()
    local new = COPY(self)
    for i = 1, 32, 1 do
        new.inner[i] = Slot:empty()
    end
    return new
end
function Inventory:special(size)
    local new = COPY(self)

    for i = 1, size, 1 do
        new.inner[i] = Slot:empty()
    end

    return new
end

function Inventory:getSlot(slot_num)
    return self.inner[slot_num]
end

function Inventory:getSlotInfo(slot_num)
    return self.inner[slot_num].item
end

function Inventory:removeFromSlot(slot_num, count)
    local entry = self.inner[slot_num]
    if entry == nil then return 0 end
    if entry.is_empty then return 0 end

    local removed = count
    entry.item.size = entry.item.size - count
    if entry.item.size <= 0 then
        -- If count was bigger than actual slot size corrected the "removed" record
        removed = removed - entry.item.size

        entry.is_empty = true
        entry.item = ItemInfo:empty()
    end

    return removed
end

function Inventory:addToSlot(item_info, slot_num, count)
    local entry = self.inner[slot_num]
    if entry == nil then return 0 end
    if entry.is_empty then
        local new_item_info = ItemInfo:fromPartialTable(item_info)
        new_item_info.size = 0
        entry.item = new_item_info
        entry.is_empty = false
    end

    if not self:isItemSame(item_info, slot_num) then error("CHECK ITEMSAME BEFORE TRYING TO ADD TO SLOT STUPID BAKA") end

    local added = count
    entry.item.size = entry.item.size + count
    if entry.item.size > entry.item.maxSize then
        -- If count was bigger than actual slot size corrected the "added" record
        added = added - (entry.item.size - entry.item.maxSize)
        entry.item.size = entry.item.maxSize
    end

    return added
end

function Inventory:overwriteSlot(item_info, slot_num)
    local old_item = self.inner[slot_num].item
    self.inner[slot_num].item = item_info

    return old_item
end

-- As is obvious can only fit 1 stack at the time
function Inventory:addItem(item_info)
    local initial_size = item_info.size

    -- look for occurences of item in inventory
    for slot, entry in ipairs(self.inner) do
        if entry.is_empty then goto continue end
        if not self:isItemSame(entry.item, slot) then goto continue end

        local empty_space = entry.item.maxSize - entry.item.size
        local can_fit = empty_space - item_info.size

        if can_fit >= 0 then
            entry.item.size = entry.item.size + item_info.size
            item_info.size = 0
        else
            entry.item.size = entry.item.size + item_info.size + can_fit
            item_info.size = item_info.size - item_info.size - can_fit
        end

        if item_info.size == 0 then return true, 0 end
        ::continue::
    end

    -- As a last resort we put it in the first empty slot we find
    for _, entry in ipairs(self.inner) do
        if entry.is_empty then
            entry.is_empty = false
            entry.item = item_info
            return true, 0
        end
    end

    -- Else item could not be picked up
    local diff = initial_size - item_info.size
    return false, diff
end

function Inventory:getFirstItemInfo()
    for slot_num, entry in ipairs(self.inner) do
        if not entry.is_empty then
            return entry.item, slot_num
        end
    end

    return nil, nil
end

function Inventory:isItemSame(item_info, slot_num)
    local eitem = self.inner[slot_num].item
    return eitem:isSame(item_info)
end

function Inventory:isSlotEmpty(slot_num)
    return self.inner[slot_num].is_empty
end

return Inventory
