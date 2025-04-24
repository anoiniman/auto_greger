local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local nav = require("nav_module.nav_obj")

function module.navigate(arguments)
    local what_kind = arguments[1]
    if what_kind == nil or tonumber(what_kind) ~= nil then
        print(comms.robot_send("info", "navigate chunk, what_kind unspecified, so assuming"))
        table.insert(arguments, 1, "surface")
    end

    if arguments[2] == nil or arguments[3] == nil then
        print(comms.robot_send("error", "navigate chunk, bad goal-chunk coordinates"))
    end
    local what_chunk = {arguments[1], arguments[2]}
    
    local finished = nav.navigate_chunk(what_chunk)
    if not finished then
        return {50, "navigate_chunk", what_chunk}
    end
    return nil
end

return module
