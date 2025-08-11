-- Basically rel_move adapted to interfacing with door_ways in a simple manner
local module = {}

local robot = require("robot")

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

function module.be_an_elevator(target_height, complex_mode, wall_dir)
    if complex_mode == nil then
        complex_mode = false
    end
    if complex_mode then
        if nav.get_orientation ~= wall_dir then
            nav.change_orientation(wall_dir)
        end
        local is_wall, _ = robot.detect()
        if not is_wall then
            local result = inv.place_block("front", {"any:building", "any:grass"}, "name_table")
            print(comms.robot_send("warning", "Uh oh, be an elevator"))
        end
    end

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
