local deep_copy = require("deep_copy")
local comms = require("comms")
local inv = require("inventory.inv_obj")

-- Possible filters = "strict", "loose", <!"gt_ore"!> (maybe not anymore)
-- perfect string match, imperfect match, item_name is actually a table
local ItemConstraint = {
    item_lable = nil,
    item_name = nil,
    filter = nil,

    set_count = nil,
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
    -- le reset switch :)
    local items_in_inv = inv.how_many_total(self.item_lable, self.item_name)
    if not do_once and self.lock[1] == 2 then
        -- this is to say if we are doing something, and we still haven't broken through the reset (upper) limit
        -- then keep going, else only then reset back to 0 (back to simply seeking the set_count)
        if items_in_inv < self.reset_count then
            return 1, {name = self.item_name, lable = self.item_lable}
        end

        self.lock[1] = 0
    end
    if self.lock[1] == 1 or self.lock[1] == 3 then return nil, nil end -- Hold it
    if self.lock[1] == 2 then return 0, nil end -- Go On

    -- removed the how_many_internal thing, it is useful to dictate if we have to pick something up, but that
    -- is not the responsability of this code
    if items_in_inv < self.set_count then
        return 1, {name = self.item_name, lable = self.item_lable}
    end
    return 0, nil
end

return ItemConstraint
