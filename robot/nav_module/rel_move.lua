local nav = require("nav_module.nav_interface")
local math = require("math")

local goal_rel = {0,0,0} -- x,z,y

function module.setup_navigate_rel(x,z,y)
    goal_rel[1] = x
    goal_rel[2] = z
    goal_rel[3] = y
end

local function attempt_move(nav_obj, dir)
    local result = nil
    if dir ~= nil then
        result = nav.real_move("free", dir, nav_obj)
        return result
    end
end

function module.navigate_rel(nav_obj)
    local dir = nil
    -- attempt to move on the x axis, if not possible, attempt to move on the z axis, this won't solve mazes, but we won't need to
    local x_dif = nav_obj.rel[1] - goal_rel[1]
    if x_dif > 0 then dir = "west"
    elseif x_dif < 0 then dir = "east" end
    
    if attempt_move(nav_obj, dir) then return true end

    local z_dif = nav_obj.rel[2] - goal_rel[2]
    if z_dif > 0 then dir = "north"
    elseif z_dif < 0 then dir = "south" end

    if attempt_move(nav_obj, dir) then return true end

    local y_dif = nav_obj.rel[2] - goal_rel[2]
    if y_dif > 0 then dir = "down"
    elseif y_dif < 0 then dir = "up" end

    if attempt_move(nav_obj, dir) then return true end

    return false -- couldn't move
end

