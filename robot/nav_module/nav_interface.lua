local module = {}

--local math = require("math")
local robot = require("robot")
--local sides_api = require("sides")
local serialize = require("serialization")-- luacheck: ignore

local comms = require("comms")

local geolyzer = require("geolyzer_wrapper")
local inv = require("inventory.inv_obj")

local function update_pos(direction, nav_obj) -- assuming forward move
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

local function un_convert_orientation(num_side)
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
local function convert_orientation(orientation)
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

local function change_orientation(goal, nav_obj)
    local orientation = nav_obj.orientation

    local numeric = convert_orientation(orientation) - 2 -- (alignement)
    local num_goal = convert_orientation(goal) - 2

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

function module.c_orientation(goal, nav_obj)
    return change_orientation(goal, nav_obj)
end


local function base_move(direction, nav_obj) -- return result and error string
    local result
    local err

    if direction == "up" then
        result, err = robot.up()
    elseif direction == "down" then
        result, err = robot.down()
    else
        change_orientation(direction, nav_obj)
        result, err = robot.forward()
    end

    if result ~= nil then update_pos(direction, nav_obj) end
    return result, err
end

local empty_table = {}
-- TODO -> better cave/hole detection so we don't lose ourselves underground
-- Returning true means move sucesseful
local function real_move(what_kind, direction, nav_obj, extra_sauce)
    if extra_sauce == nil then extra_sauce = empty_table end -- nice hack!

    if nav_obj == nil then
        print(comms.robot_send("error", "No nav obj provided!"))
    end

    -- WE NO LONGER AUTO-CHOP TREES
    if what_kind == "surface" then
        local result, err = base_move(direction, nav_obj)
        --print("post base_move")
        if err ~= nil and err == "impossible move" then
            -- for know we just panic, maybe one day we'll add better AI
            print(comms.robot_send("error", "real_move: we just IMPOSSIBLE MOVED OURSELVES"))
            return false, "impossible"
        elseif err ~= nil and err ~= "impossible move" then -- TODO check that is not an entity
            if extra_sauce[1] ~= "no_auto_up" then
                return real_move("free", "up", nav_obj) -- This is the case for a non tree terrain feature
            end
            local obstacle = geolyzer.simple_return()
            return false, obstacle
        end
        -- Only AFTER (not before) we've been succeseful do we try to move down
        local can_move, block_type = robot.detectDown()
        if block_type == "air" or block_type == "liquid" then
            --print("look for air")
            robot.down()
            update_pos("down", nav_obj)
            return true, nil
        end

        return true, nil
    elseif what_kind == "free" then
        --print("free move")
        local result, err = base_move(direction, nav_obj)
        if result == nil then
            print(comms.robot_send("debug", "real_move: \"" .. what_kind .. "\" || error: \"" .. err .. "\""))
            if err == "entity" then
                inv.equip_tool("sword")
                robot.swing()
                return false, "swong"
            elseif err ~= "impossible move" then
                return false, err
            elseif err == "impossible move" then
                return false, "impossible"
            end
        end
        return true, nil
    else
        print(comms.robot_send("error", "real_move: \"" .. what_kind .. "\" unimplemented"))
        return false, nil
    end
    error("unreachable code at nav_interface.real_move")
end

-- for now forget argument remais for compatibility, but needs to be refactored in the future
function module.debug_move(dir, distance, forget, nav_obj)
    local any_error = false
    for i = 1, distance, 1 do
        local issa_ok = real_move("free", dir, nav_obj)
        if not issa_ok then
            any_error = true
        end
    end
    return any_error
end

function module.r_move(a,b,c)
    return real_move(a,b,c)
end


return module
