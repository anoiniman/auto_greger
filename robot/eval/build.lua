local module = {}

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
    local what_quad = arguments[3]
    if tonumber(what_quad) == nil then
        print(comms.robot_send("error", "setup_build / do_build, malformed command, what_quad not number or nil"))
        return false
    end

    return true, what_chunk, what_quad
end

function module.mark_chunk(arguments)
    local x = tonumber(arguments[1])
    local z = tonumber(arguments[2])
    if tonumber(x) == nil or tonumber(z) == nil then
        print(comms.robot_send("error", "mark_chunk, malformed command, x or z not number or nil"))
        return nil
    end
    
    local what_chunk = {x, z}
    local as_what = arguments[3]
    if as_what == nil then
        print(comms.robot_send("error", "chunk as what is nil"))
        return nil
    end

    if map_obj.mark_chunk(what_chunk, as_what) then -- if we succeded
        return nil 
    else 
        print(comms.robot_send("error", "mark_chunk -- failed somewhere"))
        return nil
    end
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
    local result, what_chunk, what_quad = common_checks(arguments)
    if result == false then return nil end

    local result, status, coords, block_name = map_obj.do_build(what_chunk, what_quad)
    if result then
        if status == "continue" then
            error("todo - basic inventory management, aka, check if we have such a block")
            return {"navigate_rel", "and_build", coords, block_name}
        elseif status == "done" then
            return nil
        end
    else 
        print(comms.robot_send("error", "do_build -- failed somewhere"))
        return nil
    end
end

return module
