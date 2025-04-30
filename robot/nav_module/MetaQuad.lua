------- Sys Requires -------
local io = require("io")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local interface = require("nav_module.nav_interface")
local chunk_move = require("nav_module.chunk_move")

local MetaBuild = require("build.MetaBuild")
local MetaDoorInfo = require("build.MetaBuild.MetaDoorInfo")

-- make a convert rel to quad and back function somewhere
local MetaQuad = {
    quad = 0 -- if quad = 0 it is because we still haven't been neither "marked", nor "build"
    build = MetaBuild:zeroed() -- if build.isBuilt() returns false.....
    doors = {}
}
MetaQuad.__index = MetaQuad

function MetaQuad:zeroed()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function MetaQuad:getName()
    return build.getName()
end

function MetaQuad:getNum()
    return quad
end

function MetaQuad:isBuilt()
    return build.isBuilt()
end

local function MetaQuad:actualizeDoors() -- Transform the door definition into actual rel coordinates
    for index, door in ipairs(self.doors) do
        if quad == 1 then
            self.doors.mirror(true, false)
        elseif quad == 2 then
            --self.doors.mirror(false, false)
            -- do nothing
        elseif quad == 3 then
            self.doors.mirror(false, true)            
        elseif quad == 4 then
            self.doors.mirror(true, true)
        else
            print(comms.robot_send("error", "logical impossibility - MetaQuad:acutalizeDoors()"))
        end
    end
end

function require_build(name)
    local result = self.build.require(name)
    if result == false then return false end

    self.doors = deep_copy.copy_table(self.build.getDoors(), ipairs)
    self.actualizeDoors()
    return true
end

function MetaQuad:setQuad(quad, name)
    self.quad = quad
    self.require_build(name)
end

function MetaQuad:setupBuild()
    if self.isBuilt() then
        print(comms.robot_send("error", "remove build before trying to build over build (not Implemented yet tho)"))
        return false
    end
    -- Now we must rotate the build according to quad number, before creating the build structure
    self.build.rotatePrimitive(self.quad)
    self.build.setupBuild() 
    -- And then we must dump the primitive, to save memory

    return true
end

function MetaQuad:doBuild()
    if self.isBuilt() then
        print(comms.robot_send("error", "how did you trigger this error message 01?"))
    end
    
    self.build.doBuild()
end

return MetaQuad
