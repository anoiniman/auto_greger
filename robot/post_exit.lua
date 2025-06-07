-- Things to do after exit is called
local keep_alive = require("keep_alive")
local comms = require("comms")
local map = require("nav_module.map_obj")

local serialize = require("serialization")
local filesystem = require("filesystem")

local module = {}

-- This will be where we do the saving the state things
function module.exit()
    keep_alive.prepare_exit()
end

--function module.save
function module.save_builds()
    if not filesystem.isDirectory("/home/robot/save_state") then
        filesystem.makeDirectory("/home/robot/save_state")
    end
    local copy_with_no_funcs = deep_copy.copy_no_functions(map.all_builds) -- hopefully our RAM can take it :)
    local serial = serialize.serialize(copy_with_no_funcs, false)

    -- unbuffered because I want 0 problems!
    if filesystem.exists("/home/robot/save_state/build.save") then
        filesystem.remove("/home/robot/save_state/build.save")
    end
    local stream = filesystem.open("/home/robot/save_state/build.save", "w")
    if stream == nil then error(comms.robot_send("fatal", "aaaaaaaa")) end

    stream:write(serial)
    stream:close()
end

return module
