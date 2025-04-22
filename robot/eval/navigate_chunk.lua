local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")
local nav = require("nav_module")
local geolyzer = require("geolyzer_wrapper")

function module.navigate(arguments)
    local what_kind = arguments[1]
    if what_kind == nil then
        print(comms.robot_send("error", "navigate chunk, non-recognized \"what kind\""))
        return nil
    end
    local finished = nav.navigate_chunk()
    if not finished then
        return {50, command, what_kind}
    end
end

