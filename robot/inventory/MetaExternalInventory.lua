-- You hook this up to anything you want to register as an external inventory
local deep_copy = require("deep_copy")
local comms = require("comms")

local MetaLedger = require("inventory.MetaLedger")
local inv = require("inventory.inv_obj")

-- as obvious, if it is an item inside a static storage it has no output
local MetaItem = {
    name = nil,
    lable = nil,
    permissive = false,

    output = nil
}
function MetaItem:new(name, lable, permissive, output)
    local new = deep_copy.copy(self, pairs)
    new.name = name
    new.lable = lable
    new.permissive = permissive
    new.output = output

    return new
end


local Module = {
    parent_build = nil,

    item_defs = nil,
    storage = false, -- compared to being a production inventory that consumes items
    long_term_storage = false, -- compared to being an inventory associated with this 1 specific building

    ledger = nil,
    symbol = nil,
    special_block_index = nil,
}

function Module:new(item_defs, parent, is_cache, symbol, index)
    if not is_cache and parent == nil then
        print(comms.robot_send("error", "MetaExtInventory, parent is nil"))
        print(comms.robot_send("stack", debug.traceback()))
    end

    local new = deep_copy.copy(self, pairs)
    new.item_defs = item_defs
    new.ledger = MetaLedger:new()
    new.parent = parent
    new.symbol = symbol,
    new.special_block_index = index,

    inv.register_ledger(new) -- important
    return new
end

function Module:getDistance()
    return self.parent:getDistToSpecial(self.symbol, self.special_block_index)
end

function Module:itemDefIter()
    local iteration = 0

    -- checks if it is not a plain def (aka, if item_defs is a table, not a just a raw item_def)
    if self.item_defs["permissive"] == nil then
        return function()
            iteration = iteration + 1
            if iteration > 1 then return nil end

            return self.item_defs
        end
    end

    return function()
        iteration = iteration + 1
        local item_def = self.item_defs[iteration]
        if item_def == nil then return nil end

        return iteration, item_def
    end
end


function Module:newLongTermStorage(item_defs, parent)
    local new = self:new(item_defs, parent)
    new.storage = true
    new.long_term_storage = true
    return new
end

-- this is where the robot dumps its inventory temporarily in order to work a building, basically a fat ledger
function Module:newSelfCache()
    local new = self:new(nil, nil, true)
    new.storage = true
    return new
end

function Module:newStorage(item_defs, parent, symbol, index)
    local new = self:new(item_defs, parent, symbol, index)
    new.storage = true
    return new
end

function Module:newMachine(item_defs, parent, symbol, index)
    local new = self:new(item_defs, parent, symbol, index)
    new.storage = false
    return new
end

return table.pack(Module, MetaItem)
