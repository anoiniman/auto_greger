local robot = { }
local robot_rep

function robot.setRobotRep(robot_rep_)
    robot_rep = robot_rep_
end

function robot.name()
    return "Testy"
end

local function subDetect(dir)
    local block = robot_rep.world:getBlockRelSide(robot_rep, sides_api[dir])
    if block == nil then return true, "passable" end -- its probabily air

    return block.passable, block.meta_type
end

function robot.detect()
    return subDetect("front")
end

function robot.detectUp()
    return subDetect("up")
end

function robot.detectDown()
    return subDetect("down")
end

function robot.select(slot_num)
    local previous = robot_rep.selected_slot

    if slot_num == nil or slot_num > 32 or slot_num < 1 then return previous end
    robot_rep.selected_slot = slot_num
    return slot_num
end

function robot.inventorySize()
    return 32
end

function robot.count(slot_num)
    local info = robot_rep.inventory:getSlotInfo(slot_num)
    return info.size
end

function robot.space(slot_num)
    local info = robot_rep.inventory:getSlotInfo(slot_num)
    return info.maxSize - info.size
end

-- Start from here TODO
function robot.transferTo

return robot
