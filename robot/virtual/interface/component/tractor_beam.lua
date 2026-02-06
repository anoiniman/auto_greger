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

function tractor_beam.suck()
    print("tried to suck")
    local x, z, y = robot_rep:getPosition()

    local rad = 5
    for yindex = y - rad, y + rad, 1 do
    for zindex = z - rad, z + rad, 1 do
    for xindex = x - rad, x + rad, 1 do
        local block = robot_rep.world:getBlockAbs(xindex, zindex, yindex)
        if block == nil then goto skip end

        local item = block:pickUpOneItemStack()
        if item ~= nil then
            print("Sucked: " .. item.label)
            if not robot_rep:suckItem(item) then
                block:dropOneItemStaack(item)
            end
            return true -- early return to copy actual behaviour of this
        end

        ::skip::
    end
    end
    end

    return false
end


return tractor_beam
