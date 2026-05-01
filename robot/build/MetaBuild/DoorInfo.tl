local comms = require("comms")
require("Position")


-- coords are chunk_rel, but are attached to quad, they need to be able to rotate with quad, if quad is rotatable
-- their "default" definition inside the build-source files should be assuming quad 2
local record helper end
local type C = CoordinateType

-- [1] = x, [2] = z, [3] = len
global type Door = Pos3D

function helper.new(): Door
    return {-1 as C.X, -1 as C.Z, -1 as C.Y}
end

function helper.doorX(door: Door, x: integer, len: integer) -- this assumes quad 2
    if x < 1 or x > 7 then error(comms.robot_send("fatal", "MetaDoorInfo:doorX, invariants broken!")) end

    door[1] = x
    door[3] = len

    door[2] = 0
end

function helper.doorZ(door: Door, z: integer, len: integer) -- this assumes quad 2
    if z < 1 or z > 7 then error(comms.robot_send("fatal", "MetaDoorInfo:doorZ, invariants broken!")) end

    door[2] = z
    door[3] = len

    door[1] = 0
end

function helper.mirror(door: Door, x_axis: boolean, z_axis: boolean)
    if z_axis then
        door[1] = door[1]
        door[2] = math.abs(15 - door[2])
    end
    if x_axis then
        door[1] = math.abs(15 - door[1])
        door[2] = door[2]
    end
end

return helper
