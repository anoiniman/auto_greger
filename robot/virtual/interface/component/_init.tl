-- local RobotRep = require("RobotRep")
-- local event = require("event")
local robot = require("robot")

local record tunnel end
--[[local mm_core = {
    "localAddr",
    "remoteAddr",
    6969,
    255,
}
event.addToList("modem_message", mm_core)--]]
function tunnel.send() -- should be enough since we print either way
    return
end


local inventory_controller = require("component.inventory_controller")
local crafting = require("component.crafting")
local tractor_beam = require("component.tractor_beam")
local geolyzer = require("component.geolyzer")
local generator = require("component.generator")

local component_list = {
    inventory_controller = inventory_controller,
    crafting = crafting,
    tractor_beam = tractor_beam,
    geolyzer = geolyzer,
    generator = generator,

    tunnel = tunnel,
}

local component = {}

-- Call this whenever a new robot_rep is loaded as the main robot_rep associated with currently
-- executed World
function component.setRobotRep(robot_rep)
    print("Setting robotRep")
    for name, module in pairs(component_list) do
        if module.setRobotRep ~= nil then
            print(name)
            module.setRobotRep(robot_rep)
        end
    end

    print("robot")
    robot.setRobotRep(robot_rep)
    print("Done")
end

function component.getPrimary(name)
    return component_list[name]
end

return component
