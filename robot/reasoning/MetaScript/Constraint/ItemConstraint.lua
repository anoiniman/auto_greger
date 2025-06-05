local deep_copy = require("deep_copy")
local comms = require("comms")
local inv = require("inventory.inv_obj")

-- Possible filters = "strict", "loose", <!"gt_ore"!> (maybe not anymore)
-- perfect string match, imperfect match, item_name is actually a table
local ItemConstraint = {
    item_lable = nil,
    item_name = nil,
    filter = nil,

    set_count = nil
    reset_count = nil,

    internal = true, -- to be removed
    lock = {0}
}

function ItemConstraint:new(item_name, item_lable, set_count, reset_count, filter) -- maybe this internal thing will never be used
    local new = deep_copy.copy(self, pairs)
    new.set_count = set_count
    new.reset_count = reset_count
    new.filter = filter
    new.item_name = item_name
    new.item_lable = item_lable

    --new.internal = internal
    new.internal = true -- not that it matters much for now

    return new
end
function ItemConstraint:check(do_once) -- so this was easy?
    if not do_once and self.lock[1] == 2 then -- le reset switch :)
        self.lock[1] = 0
    end
    if self.lock[1] ~= 0 then return 0, nil end

    -- removed the how_many_internal thing, it is useful to dictate if we have to pick something up, but that
    -- is not the responsability of this code
    if inv.how_many_total(self.item_name, self.item_lable) < self.reset_count then
        return 1, {name = self.item_name, lable = self.item_lable}
    end
    return 0, nil
end

return ItemConstraint
