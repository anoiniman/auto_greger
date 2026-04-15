local deep_copy = require("deep_copy")
local comms = require("comms")
local inv = require("inventory.inv_obj")

-- Possible filters = "strict", "loose", <!"gt_ore"!> (maybe not anymore)
-- perfect string match, imperfect match, item_name is actually a table
global interface ItemConstraint is Constraint
where self.const_type == "item"

    item: ItemDefinition

    set_count: integer
    reset_count: integer

    lock: LockState
end

function module.new(item: ItemDefinition, set_count: integer, reset_count: integer, do_once: boolean): ItemConstraint
    return {
        const_type = "item",
        do_once = do_once,

        item = item,

        set_count = set_count,
        reset_count = reset_count,

        lock = "Free"
    }
end

local type ItemConstRetObj = ItemDefinition
-- set_count is a number smaller than reset_count, so it'll only start once something drops below for example 13,
-- but then it won't just lift the number up to 14, it'll go until the reset condition is met
function ItemConstraint:check(): ConstReturn<ItemConstRetObj>
    local macroexp ret_done() return { ret_type = "Done", ret_obj = nil } end

    if self.lock == "Block-Working" or self.lock == "Wait" then
        return { ret_type = "Block", ret_obj = nil }
    end

    if self.lock == "Done" then
        if self.do_once then return ret_done() end
        self.lock = "Free"
    end

    local items_in_inv = inv.how_many_total(self.item)
    if self.lock == "Free" then
        if items_in_inv < self.set_count then -- we need to act
            return { ret_type = "Available", ret_obj = self.item }
        end
        self.lock = "Done"
        return ret_done()
    end
    if self.lock == "Block-Recheck" then
        if items_in_inv < self.reset_count then
            return { ret_type = "Available", ret_obj = self.item }
        end -- else, we're finally done stocking back up!
        self.lock = "Done"
        return ret_done()
    end

    error(comms.send_unexpected(true))
end

return ItemConstraint
