-- You hook this up to anything you want to register as an external inventory
local deep_copy = require("deep_copy")
local MetaLedger = require("inventory.MetaLedger")

-- as obvious, if it is an item inside a static storage it has no output
local MetaItem = {
    name = nil,
    lable = nil,
    permissive = false,

    output = nil
}
function MetaItem:new(name, lable, permissive, output)
    local new = deep_copy(self, pairs)
    new.name = name
    new.lable = lable
    new.permissive = permissive
    new.output = output

    return new
end


local Module = {
    item_defs = nil,
    storage = true, -- compared to being a production inventory that consumes items

    ledger = nil,
    rel_location = nil -- access location
}

function Module:new(item_defs)
    local new = deep_copy(self, pairs)
    new.item_defs = item_defs
    new.ledger = MetaLedger:new()
    return new
end

function Module:newStorage(item_defs)
    local new = self:new(item_defs)
    return new
end

function Module:newMachine(item_defs)
    local new = self:new(item_defs)
    new.storage = false
    return new
end

return table.pack(Module, MetaItem)
