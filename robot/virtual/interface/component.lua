local RobotRep = require("RobotRep")
local event = require("event")

local Tunnel = {}
--[[local mm_core = {
    "localAddr",
    "remoteAddr",
    6969,
    255,
}
event.addToList("modem_message", mm_core)--]]
function Tunnel.send() -- should be enough since we print either way
    return
end


local component_list = {
    inventory_controller = nil,
    crafting = nil,
    tractor_beam = nil,
    geolyzer = nil,
    generator = nil,

    tunnel = Tunnel,
}

local component = {}

function component.getPrimary(name)
    return component_list[name]
end

return component
