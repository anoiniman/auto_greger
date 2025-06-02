local module = {}
local comms = require("comms")
local map_obj = require("nav_module.map_obj")

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

function module.chunk_add_mark(arguments)
    local x = tonumber(arguments[1])
    local z = tonumber(arguments[2])
    if tonumber(x) == nil or tonumber(z) == nil then
        print(comms.robot_send("error", "chunk_mark -- malformed command, x or z not number or nil"))
        return nil
    end

    local what_chunk = {x, z}
    local as_what = arguments[3]
    if as_what == nil then
        print(comms.robot_send("error", "chunk_mark -- chunk as what is nil"))
        return nil
    elseif as_what ~= "surface_depleted" then -- expand list as necessary
        print(comms.robot_send("error", "chunk_mark -- chunk as what is invalid"))
        return nil
    end

    if not map_obj.add_mark_to_chunk(what_chunk, as_what) then
        print(comms.robot_send("error", "chunk_mark -- failed in the final step"))
    end
end

function module.chunk_remove_mark(arguments)
    local x = tonumber(arguments[1])
    local z = tonumber(arguments[2])
    if tonumber(x) == nil or tonumber(z) == nil then
        print(comms.robot_send("error", "chunk_mark -- malformed command, x or z not number or nil"))
        return nil
    end

    local what_chunk = {x, z}
    local remove_what = arguments[3]
    if remove_what == nil then
        print(comms.robot_send("error", "chunk_mark -- chunk remove what is nil"))
        return nil
    elseif remove_what ~= "surface_depleted" then -- expand list as necessary
        print(comms.robot_send("error", "chunk_mark -- chunk remove what is invalid"))
        return nil
    end

    if not map_obj.try_remove_mark_from_chunk(what_chunk, remove_what, false) then
        print(comms.robot_send("error", "chunk_remove_mark -- failed in the final step"))
    end
end


return module
