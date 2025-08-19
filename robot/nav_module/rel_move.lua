local module = {}

local comms = require("comms")
local deep_copy = require("deep_copy")

local nav = require("nav_module.nav_interface")


local function attempt_move(nav_obj, dir, extra_sauce)
    if dir ~= nil then
        local result, err = nav.r_move("free", dir, nav_obj, extra_sauce)
        return result, err
    end
    return false, nil
end

local function attempt_surface_move(nav_obj, dir, extra_sauce)
    if dir ~= nil then
        local result, data = nav.r_move("surface", dir, nav_obj, extra_sauce)
        return result, data
    end
    return false, nil
end

local singleton_goal_rel = {0,0,0} -- x,z,y
local navigation_setup = false

function module.is_setup()
    return navigation_setup
end

function module.setup_navigate_rel(x,z,y)
    singleton_goal_rel[1] = x
    singleton_goal_rel[2] = z
    singleton_goal_rel[3] = y
    navigation_setup = true
end

-- Attempts non-surface (aka - free) move by default
local function navigate_opaque(nav_obj, goal_rel, extra_sauce)
    local dir = nil
    local result = nil
    local data

    -- Safety check! Time to crash and burn --
    if nav_obj.rel[1] > 15 or nav_obj.rel[2] > 15 or nav_obj.rel[1] < 0 or nav_obj.rel[2] < 0 then
        print(comms.robot_send("error", "rel_move, INVARIANT BROKEN!"))
    end

    -- attempt to move on the x axis, if not possible, attempt to move on the z axis, if not possible etc.
    -- this won't solve mazes, but we won't need to

    ------ x axis
    local x_dif = nav_obj.rel[1] - goal_rel[1]
    if x_dif > 0 then dir = "west"
    elseif x_dif < 0 then dir = "east" end

    if dir ~= nil then
        result, data = attempt_move(nav_obj, dir, extra_sauce)
    end
    if result then return 0 end

    ----- z axis
    local z_dif = nav_obj.rel[2] - goal_rel[2]
    if z_dif > 0 then dir = "north"
    elseif z_dif < 0 then dir = "south" end

    if dir ~= nil then
        result, data = attempt_move(nav_obj, dir, extra_sauce)
    end
    if result then return 0 end

    ----- y axis
    local y_dif = nav_obj.height - goal_rel[3]
    if goal_rel[3] > -1 then
        if y_dif > 0 then dir = "down"
        elseif y_dif < 0 then dir = "up" end
    end

    if dir ~= nil then
        result, data = attempt_move(nav_obj, dir, extra_sauce)
    end
    if result then return 0 end

    return dir, data
end

function module.access_opaque(nav_obj, goal_rel, extra_sauce)
    return navigate_opaque(nav_obj, goal_rel, extra_sauce)
end

function module.navigate_rel(nav_obj, extra_sauce)
    if not navigation_setup then
        print(comms.robot_send("error", "navigate_rel, navigation not setup"))
        return 2
    end

    local result, data = navigate_opaque(nav_obj, singleton_goal_rel, extra_sauce)
    if result == nil then -- luacheck: ignore (hacky, I like it)
    elseif result == 0 then return 0 end

    local dir = result
    ----- wrap up
    if dir == nil then
        -- This means that we've arrived at the spot
        navigation_setup = false
        return -1
    end

    return 1, data -- couldn't move
end

local sweep_start = {0, 0, 0}
local sweep_end = {0, 0, 0}
local is_sweep = false
local move_to_start = false
local sweep_reverse = false

local function sweep_x_axis(nav_obj, move_func)
    local dir = nil -- luacheck: ignore
    if sweep_start[1] == 0 then
        dir = "east"
    else
        dir = "west"
    end
    -- local result, data = attempt_surface_move(nav_obj, dir)
    local result, data = move_func(nav_obj, dir)
    if result then return 0 end
    return 1, data
end

function module.is_sweep_setup()
    return is_sweep
end

-- interrupts, marks as finished, and returns/saves current state
-- We assume that we only interrupt AFTER we finish move_to_start
function module.interrupt_sweep(nav_obj)
    -- I think all we need to return is sweep_reverse and current position
    is_sweep = false
    move_to_start = true
    return deep_copy.copy(nav_obj.rel), sweep_reverse
end

-- TODO: turns out the z sweep_end is not equal to sweep_start, but rather in the other end, se if it's ok to do as such
-- rect_offset idea: to create smaller sweeps and shift them around, not for rn tho
function module.setup_sweep(nav_obj)
    is_sweep = true
    move_to_start = true

    if nav_obj.rel[1] > 6 then sweep_start[1] = 15
    else sweep_start[1] = 0 end

    if nav_obj.rel[2] > 6 then sweep_start[2] = 15
    else sweep_start[2] = 0 end

    sweep_reverse = (sweep_start[2] == 15) -- Important

    sweep_end[1] = math.abs(16 - sweep_start[1])
    -- FOR WHY WE COMMENTED THIS OUT, CHECK OUR DRAWING
    -- sweep_end[2] = math.abs(16 - sweep_start[2])

    sweep_end[2] = sweep_start[2]

    return true -- true to continue
end

-- Stand Alone, no need to setup, just remember to move to your "continue point" manually before sweeping
function module.resume_sweep(s_start, reverse)
    --[[if is_sweep then
        print(comms.robot_send("error", "Attempted to resume_sweep with is_sweep == true"))
        return false
    end--]]

    is_sweep = true
    move_to_start = false
    sweep_start = deep_copy.copy(s_start, pairs)
    sweep_reverse = reverse

    sweep_end[1] = math.abs(16 - sweep_start[1])
    sweep_end[2] = sweep_start[2]

    return true
end

function module.reverse_sweep()
    if not is_sweep then return false end

    sweep_reverse = not sweep_reverse

    -- just swapping some refs around so no problem
    local temp = sweep_start
    sweep_start = sweep_end
    sweep_end = temp
    return true
end

local where_x = -1
-- 1 for fail, -1 for end, 0 for continue
function module.sweep(nav_obj, is_surface)
    local move_func = attempt_surface_move
    if not is_surface then move_func = attempt_move end

    if not is_sweep then
        print(comms.robot_send("error", "sweep not setup"))
        return 1
    end

    if move_to_start then
        if not navigation_setup then
            module.setup_navigate_rel(sweep_start[1], sweep_start[2], -1)
        end

        local result, data = module.navigate_rel(nav_obj)

        if result == 1 then
            print(comms.robot_send("error", "from: move_rel.sweep, navigate_rel returned err"))
            return 1, data
        elseif result == -1 then
            move_to_start = false
        else
            return 0
        end
    end

    if nav_obj.rel[1] == sweep_end[1] and nav_obj.rel[2] == sweep_end[2] then
        is_sweep = false
        return -1 -- finished sweeping
    end

    local get_x_axis_bool = function() return (nav_obj.rel[2] > 15 and not sweep_reverse) or (nav_obj.rel[2] <= 0 and sweep_reverse) end
    local result = nil; local data = nil -- luacheck: ignore
    if get_x_axis_bool() then
        if where_x == -1 then where_x = nav_obj.rel[1] end

        -- ok, now the bug should be gone
        result, data = sweep_x_axis(nav_obj, move_func)
        if where_x ~= nav_obj.rel[1] then
            sweep_reverse = not sweep_reverse
            where_x = -1
        end
    else
        local dir
        if not sweep_reverse then dir = "south"
        else dir = "north" end
        result, data = move_func(nav_obj, dir)
    end

    if result then result = 0 end
    if not result then result = 1 end

    return result, data
end

return module
