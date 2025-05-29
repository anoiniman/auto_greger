local deep_copy = require("deep_copy")
local comms = require("comms")
local inv = require("inventory.inv_obj")

-- Possible filters = "strict", "loose", <!"gt_ore"!> (maybe not anymore)
-- perfect string match, imperfect match, item_name is actually a table
local ItemConstraint = {item_name = nil, total_count = nil, filter = nil, internal = true, lock = {0}}
function ItemConstraint:new(item_name, total_count, filter) -- maybe this internal thing will never be used
    local new = deep_copy.copy(self, pairs)
    new.item_name = item_name
    new.total_count = total_count
    new.filter = filter
    --new.internal = internal
    new.internal = true -- not that it matters much for now

    return new
end
function ItemConstraint:check(do_once) -- so this was easy?
    if not do_once and self.lock[1] == 2 then -- le reset switch :)
        self.lock[1] = 0
    end
    if self.lock[1] ~= 0 then return 0, nil end

    if self.internal then
        if inv.how_many_internal(self.item_name.name, self.item_name.lable) < self.total_count then
            return 1, self.item_name
        end
    else
        -- TODO
        error(comms.robot_send("fatal", "ItemConstraint:check() -> internal == false -- not implemented!"))
    end

    return 0, nil
end

return ItemConstraint
