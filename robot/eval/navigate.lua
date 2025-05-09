local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")

function module.navigate_chunk(arguments)
    local what_kind = arguments[1]
    if what_kind == nil then
        print(comms.robot_send("error", "navigate chunk, non-recognized \"what kind\""))
        return nil
    end
    local finished = nav.navigate_chunk(what_kind)
    if not finished then
        return {50, "navigate_chunk", what_kind}
    end
    return nil
end

function module.generate_chunks(arguments)
    local x = arguments[1]; local z = arguments[2]
    if x == nil or z == nil then
        print(comms.robot_send("debug", "generate chunks, no x, or z provided for offset, assuming {1,1}"))
        x = 0; z = 0
    end

    local offset = {x,z}
    map.gen_map_obj(offset)
    return nil
end

function module.navigate_rel(arguments)
    error("todo 01")
end

return module
