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
    quad = 0, -- if quad = 0 it is because we still haven't been neither "marked", nor "build"
    build = MetaBuild:new(), -- if build.isBuilt() returns false.....
    doors = nil
}
function MetaQuad:new()
    return deep_copy.copy_table(self, pairs)
end

function MetaQuad:getName()
    return self.build:getName()
end

function MetaQuad:getNum()
    return self.quad
end

function MetaQuad:getBuild()
    return self.build
end

function MetaQuad:getDoors()
    return self.doors
end

function MetaQuad:isInit()
    return self.quad ~= 0
end

function MetaQuad:isBuilt()
    return self.build:isBuilt()
end

function MetaQuad:actualizeDoors() -- Transform the door definition into actual rel coordinates
    if self.doors == nil then
        print(comms.robot_send("error", "tried to actualizeDoors without having any doors!?"))
        return
    end

    local quad = self.quad
    for index, door in ipairs(self.doors) do
        if quad == 1 then
            door:mirror(true, false)
        elseif quad == 2 then
            --door.mirror(false, false)
            -- do nothing
        elseif quad == 3 then
            door:mirror(false, true)            
        elseif quad == 4 then
            door:mirror(true, true)
        else
            print(comms.robot_send("error", "logical impossibility - MetaQuad:acutalizeDoors()"))
        end
    end
end

function MetaQuad:requireBuild(name)
    local result = self.build:require(name)
    if result == false then return false end

    self.doors = deep_copy.copy(self.build:getDoors(), pairs)
    self:actualizeDoors()
    return true
end

function MetaQuad:setQuad(quad_num, name)
    self.quad = quad_num
    return self:requireBuild(name)
end

function MetaQuad:setupBuild(chunk_height)
    if self:isBuilt() then
        print(comms.robot_send("error", "remove build before trying to build over build (not Implemented yet tho)"))
        return false
    end
    if self.quad == 0 then
        print(comms.robot_send("error", "you have to initialize the quad first with set_quad you dum dum"))
        return false
    end
    -- Now we must rotate and translate the build in rel chunk space according to quad number, before creating the build structure
    if  not self.build:rotateAndTranslatePrimitive(self.quad, chunk_height)
        or not self.build:setupBuild() -- Build the data-structures from the rotated primitive
    then
        self.build = MetaBuild:new() -- better reset just for in case
        return false
    end
    self.build:dumpPrimitive() -- And then we must dump the primitive, to save memory
    return true
end

function MetaQuad:doBuild()
    if self:isBuilt() then
        print(comms.robot_send("error", "how did you trigger this error message 01?"))
        return false
    end
    
    return self.build:doBuild()
end

return MetaQuad
