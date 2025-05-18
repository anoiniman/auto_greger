local module = {}

local serialize = require("serialization")
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

function module.create_named_area(arguments)
    local name = arguments[1]
    local colour = arguments[2]
    local height = tonumber(arguments[3])
    local floor_block = arguments[4]

    if name == nil or colour == nil or height == nil or floor_block == nil then
        print(comms.robot_send("error", "create_named_area, malformed command"))
        return nil
    end
    map_obj.create_named_area(name, colour, height, floor_block)
end

function module.chunk_set_parent(arguments)
    local x = tonumber(arguments[1])
    local z = tonumber(arguments[2])
    if tonumber(x) == nil or tonumber(z) == nil then
        print(comms.robot_send("error", "chunk_set_parent -- malformed command, x or z not number or nil"))
        return nil
    end

    local what_chunk = {x, z}
    local as_what = arguments[3]
    if as_what == nil then
        print(comms.robot_send("error", "chunk_set_parent -- chunk as what is nil"))
        return nil
    end

    local at_what_height = tonumber(arguments[4])
    if at_what_height == nil then
        print(comms.robot_send("debug", "chunk_set_parent -- no height provided or NaN -- assuming no-override"))
    end

    if map_obj.chunk_set_parent(what_chunk, as_what, at_what_height) then -- if we succeded
        return nil
    else
        print(comms.robot_send("error", "chunk_set_parent -- failed somewhere"))
        return nil
    end
end

function module.add_quad(arguments)
    local result, what_chunk, what_quad = common_checks(arguments)
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
    local result, what_chunk, what_quad = common_checks(arguments)
    if result == false then return nil end

    local result, status, coords, block_name = map_obj.do_build(what_chunk, what_quad)
    if result then
        if status == "continue" then
            error("todo - this is still not supported")
            --error("todo - basic inventory management, aka, check if we have such a block")
            --return {80, eval., "and_build", coords, block_name}
        elseif status == "done" then
            -- TODO: de-allocate down the unneeded build-files
            return nil
        end
    else
        print(comms.robot_send("error", "do_build -- failed somewhere"))
        return nil
    end
end

function module.start_auto_build(arguments)
    -- local arguments = {what_chunk, to_build.quadrant, name, step, self.lock, id, prio}
    -- prio is not passed into function :) (on purpose)
    --local serial = serialize.serialize(arguments, true)
    --print(comms.robot_send("debug", "start auto build arguments: " .. serial))
    return map_obj.start_auto_build(arguments[1], arguments[2], arguments[3], arguments[4], arguments[5], arguments[6], arguments)
end

return module
