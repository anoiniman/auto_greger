local module = {}

local serialize = require("serialization") -- luacheck: ignore
local comms = require("comms")

local map_obj = require("nav_module.map_obj")

local function common_checks(arguments)
    local x = tonumber(arguments[1])
    local z = tonumber(arguments[2])
    if tonumber(x) == nil or tonumber(z) == nil then
        print(comms.robot_send("error", "setup_build, malformed command, x or z not number or nil"))
        return false
    end

    local what_chunk = {x, z}
    local what_quad = tonumber(arguments[3])
    if what_quad == nil then
        print(comms.robot_send("error", "setup_build / do_build, malformed command, what_quad not number or nil"))
        return false
    end

    return true, what_chunk, what_quad
end


function module.add_quad(arguments)
    local result, what_chunk, what_quad = common_checks(arguments)
    if result == false then
        --print(comms.robot_send("debug", "failed to find chunk to add quad"))
        return nil
    end

    local primitive_name = arguments[4]
    if primitive_name == nil then
        print(comms.robot_send("error, load_primitive_at, no primitive name provided"))
        return nil
    end

    map_obj.add_quad(what_chunk, what_quad, primitive_name)
    return nil
end

function module.setup_build(arguments)
    local result, what_chunk, what_quad = common_checks(arguments)
    if result == false then return nil end

    if map_obj.setup_build(what_chunk, what_quad) then -- if we succeded
        return nil -- don't auto_start building have setting-up
    else
        print(comms.robot_send("error", "setup_build -- failed somewhere"))
        return nil
    end
end

function module.do_build(arguments)
    error(comms.robot_send("fatal", "No longer supported to do manual builds"))

    local result, what_chunk, what_quad = common_checks(arguments)
    if result == false then return nil end

    -- luacheck: ignore result, no unused
    local result, status, coords, block_name = map_obj.do_build(what_chunk, what_quad)
    if result then
        if status == "continue" then
            --
        elseif status == "done" then
            --return nil
        end
    else
        print(comms.robot_send("error", "do_build -- failed somewhere"))
        return nil
    end
end



function module.start_auto_build(arguments)
    if arguments[1].door_move_done == nil then
        error(comms.robot_send("fatal", "start_auto_build: this is not the right struct!"))
    end

    return map_obj.start_auto_build(arguments[1])
end

function module.use_build(arguments)
    local build = arguments[1]
    local flag = arguments[2]

    local index = arguments[3]
    local quantity_goal = arguments[4]
    local prio = arguments[5]
    local lock = arguments[6]

    return build:useBuilding(module.use_build, flag, index, quantity_goal, prio, lock)
end

return module
