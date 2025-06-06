-- For now, (but we'll need to improve this for the stone age to even work, as is obvious)
-- we simply take wood from a predefined slot and shovel it into the generator, but hey
-- baby steps
local module = {}

local inv = require("inventory.inv_obj")
local robot = require("robot")

local component = require("component")
local gen = component.getPrimary("generator")

function module.prepare_exit()
    gen.remove(gen.count())
    inv.maybe_something_added_to_inv()
end

-- very temporary code
function module.keep_alive()
    local fuel_count = gen.count()
    if fuel_count > 60 then
        return
    end
    
    local fuel_defs = inv.special_slot_find_all("fuel", -1)
    for _, def in ipairs(slot_defs) do
        local slot_num = def.slot_number
        robot.select(slot_num)
        if robot.count() > 0 then
            gen.insert(64 - fuel_count) 
            break
        end
    end
    robot.select(1)
end

return module
