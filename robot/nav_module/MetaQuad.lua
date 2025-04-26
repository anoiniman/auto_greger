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
    quad = 0
    build = MetaBuild:zeroed()
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

function MetaQuad:requireBuild(name)
    self.build.require(name)
    self.doors = deep_copy.copy_table(table, ipairs)
end

function MetaQuad:build(name)

end

return MetaQuad
