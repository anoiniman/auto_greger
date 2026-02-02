local component = require("component")
local robot = require("virtual.robot")

local interface = {}

function interface.init(robot_rep)
    component.setRobotRep(robot_rep)
    robot.setRobotRep(robot_rep)

    -- TODO: have another function other than do_presets, something like do_resets() or wtver
    post_exit.do_presets()
end

return interface
