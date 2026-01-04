local component = require("component")
local robot = require("virtual.robot")

local interface = {}

function interface.init(robot_rep)
    component.setRobotRep(robot_rep) 
    robot.setRobotRep(robot_rep)
end

return interface
