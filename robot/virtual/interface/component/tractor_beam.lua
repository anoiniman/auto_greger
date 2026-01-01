local tractor_beam = { }
local robot_rep

function tractor_beam.setRobotRep(robot_rep_)
    robot_rep = robot_rep_
end

-- Pulls from a 5 block radius centered on the robot
-- takes current robot position and then asks blocks in radius if they
-- contain (not in "inventory") but in "contain" any "droped" item "entities"
-- quotes on all these things because it i'll be a very rough "simulation"
-- of minecrafft entities are

function tractor_beam.suck(robot_rep)
    for yindex, 5, 1 do
    for zindex, 5, 1 do
    for xindex, 5, 1 do
        local block = robot_rep.world:getBlockAbs(xindex, zindex, yindex)
        local item = block:pickUpOneItem()
        if item ~= nil then
            if not robot_rep:suckItem(item) then
                block:dropOneItem(item)
            end
            return -- early return to copy actual behaviour of this
        end
    end
    end
end


return tractor_beam
