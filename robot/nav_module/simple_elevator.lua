-- Basically rel_move adapted to interfacing with door_ways in a simple manner
local module = {}

local comms = require("comms")
local inv = require("inventory.inv_obj")
local nav = require("nav_module.nav_obj")

local function do_move(diff)
    local result, err

    if diff > 0 then
        result, err = nav.debug_move("up", 1)
    elseif diff < 0 then
        result, err = nav.debug_move("down", 1)
    else
        print(comms.robot_send("warning", "attempted to be_an_elevator with no height diff?"))
        return false, nil
    end
    return result, err
end

local entity_watch = 0

function module.be_an_elevator(target_height)
    local cur_height = nav.get_rel()
    local diff = target_height - cur_height

    local result, err = do_move(diff)
    if result then
        entity_watch = 0
        return true
    end

    -- This prob can be fixed with auto block placing but I'm too lazy for now TODO
    if err == "impossible" then return false
    elseif err == "block" then
        return inv.blind_swing_down()
    else
        entity_watch = entity_watch + 1
    end
end

return module
