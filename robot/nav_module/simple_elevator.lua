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

function module.be_an_elevator(target_height, complex_mode, wall_dir, force_tool)
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
            if not result then print(comms.robot_send("warning", "Uh oh, be an elevator")) end
        end
    end

    local cur_height = nav.get_height()
    local diff = target_height - cur_height

    local result, err = do_move(diff)
    if result then
        entity_watch = 0
        return true
    end

    -- This prob can be fixed with auto block placing but I'm too lazy for now TODO
    if err == "impossible" then return false
    elseif err == "block" then
        if force_tool == nil then
            return inv.blind_swing_down()
        else
            local result = inv.equip_tool(force_tool, 0)
            if not result then return false end

            local result, _ = robot.swingDown()
            inv.maybe_something_added_to_inv()
            return result
        end
    else
        entity_watch = entity_watch + 1
        return true
    end
end

return module
