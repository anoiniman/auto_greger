-- For now, (but we'll need to improve this for the stone age to even work, as is obvious)
-- we simply take wood from a predefined slot and shovel it into the generator, but hey
-- baby steps
local module = {}

local inv = require("inventory.inv_obj")
local robot = require("robot")

local component = require("component")
local gen = component.getPrimary("generator")
local inv_controller = component.getPrimary("inventory_controller")


function module.prepare_exit()
    gen.remove(gen.count())
    inv.maybe_something_added_to_inv()
end

local cur_lable, cur_name

-- very temporary code
function module.keep_alive()
    local fuel_count = gen.count()
    if fuel_count > 24 then
        return
    end

    -- TODO (ATTENTION) In the early game we'll need to burn logs and shit, so add a flag to
    -- switch "any:fuel" to "any:plank" (it is free to turn logs into planks)
    local fuel_slot = inv.find_largest_slot(nil, "any:fuel")
    local slot_info = inv_controller.getStackInInternalSlot(fuel_slot)
    cur_lable = slot_info.label; cur_name = slot_info.name;

    robot.select(fuel_slot)
    gen.insert(64 - fuel_count)

    robot.select(1)
end

return module
