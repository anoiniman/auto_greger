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
    
end

return module
