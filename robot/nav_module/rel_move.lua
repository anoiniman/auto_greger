local nav = require("nav_module.nav_interface")
local comms = require("comms")

local math = require("math")

local function attempt_move(nav_obj, dir)
    if dir ~= nil then
        result = nav.real_move("free", dir, nav_obj)
        return result, data
    end
    return false, nil
end

local function attempt_surface_move(nav_obj, dir)
    if dir ~= nil then
        result, data = nav.real_move("surface", dir, nav_obj)
        return result, data
    end
    return false, nil
end

local goal_rel = {0,0,0} -- x,z,y
local navigation_setup = false

function module.setup_navigate_rel(x,z,y)
    goal_rel[1] = x
    goal_rel[2] = z
    goal_rel[3] = y
    navigation_setup = true
end

function module.navigate_rel(nav_obj)
    if not navigation_setup then
        print(comms.robot_send("error", "navigate_rel, navigation not setup"))
        return 1
    end

    local dir = nil
    local result = nil
    local data = nil

    -- attempt to move on the x axis, if not possible, attempt to move on the z axis, this won't solve mazes, but we won't need to
    ------ x axis
    local x_dif = nav_obj.rel[1] - goal_rel[1]
    if x_dif > 0 then dir = "west"
    elseif x_dif < 0 then dir = "east" end
    
    if dir ~= nil then
        result, data = attempt_move(nav_obj, dir)
    end
    if result then return 0 end

    ----- z axis
    local z_dif = nav_obj.rel[2] - goal_rel[2]
    if z_dif > 0 then dir = "north"
    elseif z_dif < 0 then dir = "south" end

    if dir ~= nil then
        result, data = attempt_move(nav_obj, dir)
    end
    if result then return 0 end

    ----- y axis
    local y_dif = nav_obj.rel[3] - goal_rel[3]
    if goal_rel[3] ~= -1 then
        if y_dif > 0 then dir = "down"
        elseif y_dif < 0 then dir = "up" end
    end

    if dir ~= nil then
        result, data = attempt_move(nav_obj, dir)
    end
    if result then return 0 end

    ----- wrap up
    if dir == nil then
        -- This means that we've arrived at the spot
        navigation_setup = false
        return -1
    end

    return 1, data -- couldn't move
end

local function sweep_z_axis(nav_obj)
    local dir = nil
    if sweep_start[2] == 0 then
        dir = "west"
    else
        dir = "east"
    end
    attempt_surface_move(nav_obj, dir)
end

local sweep_start = {0, 0, 0}
local sweep_end = {0, 0, 0}
local is_sweep = false
local move_to_start = false
-- height[1] = start height, height[2] = end height
function module.sweep(nav_obj, is_surface, height, do_dig)
    if not is_surface then error("todo, rel_move:sweep()") end

    if not is_sweep then
        is_sweep = true
        move_to_start = true
        if nav_obj.rel[1] > 6 then sweep_start[1] = 15
        else sweep_start[1] = 0 end

        if nav_obj.rel[2] > 6 then sweep_start[2] = 15
        else sweep_start[2] = 0 end
        
        if height ~= nil then
            sweep_start[3] = height[1]
            sweep_end[3] = height[2]
        else
            sweep_start[3] = -1
            sweep_end[3] = -1
        end

        sweep_end[1] = math.abs(16 - sweep_start[1])
        sweep_end[2] = math.abs(16 - sweep_start[2])
        return true -- true to continue
    end
    if move_to_start then
        if not navigation_setup then
            module.setup_navigate_rel(sweep_start[1], sweep_start[2], -1)
        end
        local result, data = module.navigate_rel(nav_obj)
        if result == 1 then
            print(comms.robot_send("error", "from: move_rel.sweep, navigate_rel returned err"))
            return false, data
        elseif result == -1 then
            move_to_start = false
        else
            return true
        end
    end

    local height_bool = sweep_start[3] == -1 or (nav_obj.rel[3] == sweep_end[3])
    if nav_obj.rel[1] == sweep_end[1] and nav_obj.rel[2] == sweep_end[2] and height_bool then
        is_sweep = false
        return false -- stop sweeping
    end

    local result = nil; local data = nil
    if sweep_start[1] == 0 then
        if nav_obj.rel[1] >= 15 then
            result, data = sweep_z_axis(nav_obj)
        else
            result, data = attempt_surface_move(nav_obj, "south")
        end
    elseif sweep_start[1] == 15  then
        if nav_obj.rel <= 0 then
            result, data = sweep_z_axis(nav_obj)
        else
            result, data = attempt_surface_move(nav_obj, "north")
        end
    end
    
    return result, data
end
