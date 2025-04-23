local module = {}
local sym = require("sym_import")

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local nav = require("nav_module.nav_obj")

function module.navigate(arguments)
    local what_kind = arguments[1]
    if what_kind == nil then
        print(comms.robot_send("error", "navigate chunk, non-recognized \"what kind\""))
        return nil
    end
    local finished = nav.navigate_chunk(what_kind)
    if not finished then
        return {50, command, what_kind}
    end
end

