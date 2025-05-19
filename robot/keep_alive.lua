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
    local count = gen.count()
    -- for now we assume we only have logs as fuel, otherwise errors will ensue
    if count < 60 then
        local prev_select = robot.select()
        robot.select(2)
        gen.insert(64 - count)
        robot.select(prev_select)
    end
end


return module
