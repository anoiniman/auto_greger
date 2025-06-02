local to_export = {}
local inward_facing = {}

---- Global Imports -----
--local math = require("math")
local robot = require("robot")
--local sides_api = require("sides")
local serialize = require("serialization") -- luacheck: ignore

---- Shared Imports -----
local comms = require("comms")

---- Local Imports ------
local strat = require("nav_module.nav_interface.strategies")

--local geolyzer = require("geolyzer_wrapper")
--local inv = require("inventory.inv_obj")


function inward_facing.update_pos(direction, nav_obj) -- assuming forward move
    local abs = nav_obj.abs
    local rel = nav_obj.rel

    local height = nav_obj.height

    if direction == "north" then
        abs[2] = abs[2] - 1
        rel[2] = rel[2] - 1
    elseif direction == "east" then
        abs[1] = abs[1] + 1
        rel[1] = rel[1] + 1
    elseif direction == "south" then
        abs[2] = abs[2] + 1
        rel[2] = rel[2] + 1
    elseif direction == "west" then
        abs[1] = abs[1] - 1
        rel[1] = rel[1] - 1
    elseif direction == "up" then
        height = height + 1
    elseif direction == "down" then
        height = height - 1
    else
        print(comms.robot_send("error", "update_pos, logical impossibility found"))
    end

    nav_obj.height = height
end

function inward_facing.un_convert_orientation(num_side)
    if num_side == 1 then
        return "down"
    elseif num_side == 2 then
        return "up"
    elseif num_side == 3 then
        return "north"
    elseif num_side == 4 then
        return "east"
    elseif num_side == 5 then
        return "south"
    elseif num_side == 6 then
        return "west"
    else
        print(comms.robot_send("error", "un_convert_orientation, logical impossibility"))
        return "error"
    end
end

-- NOT SIDES_API COMPATIBLE ANYMORE
function inward_facing.convert_orientation(orientation)
    if orientation == "north" then
        return 3
    elseif orientation == "east" then
        return 4
    elseif orientation == "south" then
        return 5
    elseif orientation == "west" then
        return 6
    else
        print(comms.robot_send("error", "convert_Orientation, Logical Impossibility found"))
        print(comms.robot_send("error", "orientation: " .. orientation))
        return -1
    end
end

function inward_facing.get_opposite_orientation(nav_obj)
    local orientation = nav_obj.orientation
    if orientation == "north" then
        return "south"
    elseif orientation == "east" then
        return "west"
    elseif orientation == "south" then
        return "north"
    elseif orientation == "west" then
        return "east"
    elseif orientation == "up" then
        return "down"
    elseif orientation == "down" then
        return "up"
    else
        print(comms.robot_send("error", "get_opposite_orientation, Logical Impossibility found"))
        print(comms.robot_send("error", "orientation: " .. orientation))
        return nil
    end
end

function inward_facing.change_orientation(goal, nav_obj)
    local orientation = nav_obj.orientation

    local numeric = inward_facing.convert_orientation(orientation) - 2 -- (alignement)
    local num_goal = inward_facing.convert_orientation(goal) - 2

    local difference = numeric - num_goal

    while numeric ~= num_goal do
        if difference > 0 then
            if numeric == 4 and num_goal == 1 then
                robot.turnRight()
                numeric = 1
            else
                robot.turnLeft()
                numeric = numeric - 1
            end
        else -- difference < 0
            if numeric == 1 and num_goal == 4 then
                robot.turnLeft()
                numeric = 4
            else
                robot.turnRight()
                numeric = numeric + 1
            end
        end
    end

    nav_obj.orientation = goal
end

function to_export.c_orientation(goal, nav_obj)
    return inward_facing.change_orientation(goal, nav_obj)
end


function inward_facing.base_move(direction, nav_obj) -- return result and error string
    local result
    local err

    if direction == "up" then
        result, err = robot.up()
    elseif direction == "down" then
        result, err = robot.down()
    else
        inward_facing.change_orientation(direction, nav_obj)
        result, err = robot.forward()
    end

    -- Translate result to boolean, since this is the standard we've been using in the rest of the programme
    if result ~= nil then inward_facing.update_pos(direction, nav_obj)
    else result = false end

    return result, err
end

local empty_table = {}
-- TODO -> better cave/hole detection so we don't lose ourselves underground
-- Returning true means move sucesseful
function inward_facing.real_move(strat_name, direction, nav_obj, extra_sauce)
    if extra_sauce == nil then extra_sauce = empty_table end -- nice hack!

    if nav_obj == nil then
        print(comms.robot_send("error", "No nav obj provided!"))
    end

    -- accept the direct injection without looking twice -- using this for other purposes is UB :>
    -- ('other' is defined as: not executing a movement strategy)
    if type(strat_name) == "function" then
        return strat_name(direction, nav_obj, extra_sauce)
    end

    local what_strat
    if strat_name == "surface" then
        what_strat = strat.surface
    elseif strat_name == "free" then
        what_strat = strat.free
    else
        print(comms.robot_send("error", "real_move: \"" .. strat_name .. "\" unimplemented"))
        return false, nil
    end

    return what_strat(inward_facing, direction, nav_obj, extra_sauce)
end

-- for now forget argument remais for compatibility, but needs to be refactored in the future
function to_export.debug_move(dir, distance, forget, nav_obj)
    local any_error = false
    for i = 1, distance, 1 do
        local issa_ok = inward_facing.real_move("free", dir, nav_obj)
        if not issa_ok then
            any_error = true
        end
    end
    return any_error
end

function to_export.r_move(a,b,c,d)
    return inward_facing.real_move(a,b,c,d)
end


return to_export
