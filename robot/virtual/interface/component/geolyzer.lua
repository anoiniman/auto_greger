local sides_api = require("sides")

local geolyzer = { }
local robot_rep

function geolyzer.setRobotRep(robot_rep_)
    robot_rep = robot_rep_
end

air_ginfo = {
    color = 6666666,
    hardness = 0,
    harvestLevel = 0,
    harvestTool = "nil",
    metadata = 0,
    name = "minecraft:air",
}
-- I don't know what "options" option is supposed to do, but here it is in the parametres
function geolyzer.analyze(side, _options)
    local block = robot_rep.world:getBlockRelSide(sides_api[side])
    if block == nil then return air_ginfo end

    local ginfo = block.ginfo
    return ginfo
end

function geolyzer.canSeeSky()
    local pos = robot_rep.position

    local x, z, _ = robot_rep:getPosition()
    for y = pos[3], 12, 1 do
        local block = robot_rep.world:getBlockAbs(x, z, y)
        if block == nil then goto continue end
        if not block.passable then return false end

        ::continue::
    end

    return true
end

function geolyzer.isSunVisible()
    return geolyzer.canSeeSky()
end

return geolyzer
