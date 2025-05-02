local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local nav = require("nav_module.nav_obj")

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

function module.navigate_rel(arguments)
    error("todo 01")
end

return module
