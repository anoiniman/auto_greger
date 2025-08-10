local deep_copy = require("deep_copy")
local comms = require("comms")
local inv = require("inventory.inv_obj")

-- This is basically an ItemConstraint but that will be treated differently by the resolution system etc etc.
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

-- set_count is a number smaller than reset_count, so it'll only start once something drops below for example 13,
-- but then it won't just lift the number up to 14, it'll go until the reset condition is met
function ItemConstraint:check(do_once) -- so this was easy?
    if self.lock[1] == 1 or self.lock[1] == 4 then
        return nil, nil -- Hold It
    end

    if self.lock[1] == 3 then
        if do_once then return 0, nil end -- This condition is "cleared", but there is nothing to do
        -- else set the lock back to 0, and allow the checks to go through unmolested
        self.lock[1] = 0
    end

    local items_in_inv = inv.how_many_total(self.item_lable, self.item_name)
    if self.lock[1] == 0 then
        if items_in_inv < self.set_count then -- we need to act
            return 1, {name = self.item_name, lable = self.item_lable}
        end -- else all good, keep hacking at it
        return 0, nil
    end
    if self.lock[1] == 2 then
        if items_in_inv < self.reset_count then
            return 1, {name = self.item_name, lable = self.item_lable}
        end -- else, we're finally done stocking back up!

        self.lock[1] = 3 -- CRITICAL
        return 0, nil
    end

    error(comms.send_unexpected(true))
end

return ItemConstraint
