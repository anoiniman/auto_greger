local deep_copy = require("deep_copy")
local bucket_functions, item_buckets = table.unpack(require("inventory.item_buckets"))

local Module = {ledger_proper = nil, special_ledger = nil}
function Module:new()
    local new = deep_copy(self, pairs)
    local new_ledger = {}
    for _, bucket in ipairs(item_buckets) do
        new_ledger[bucket] = {}
    end

    new.ledger_proper = new_ledger

    return new
end

function Module:add_or_create(name, lable, quantity)
    --if string.find(name, "gt.metaitem") then -- the question of meta-items is complex and I gave it thought
    local bucket, is_special = bucket_functions.identify(name, lable)
    if is_special ~= nil then
        self:special_add_or_create(lable)
        return
    end

    local entry_quantity = self.ledger_proper[bucket][lable]
    if entry_quantity == nil then
        self.ledger_proper[bucket][lable] = quantity
        return
    end
    self.ledger_proper[bucket][lable] = entry_quantity + quantity
end

function Module:special_add_or_create(lable) -- specials are probably non-stackable, right? Maybe not
    -- TODO
    error("TODO, MetaLedger")
end

return Module
