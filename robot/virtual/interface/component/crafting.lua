local crafting = { }

local robot_rep
function crafting.setRobotRep(robot_rep_)
    robot_rep = robot_rep_
end

function crafting.craft(count)
    count = count or 64
    robot_rep:craft(count)
end

return crafting
