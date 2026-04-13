------- Sys Requires -------
--local io = require("io")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local build_helper = require("build.MetaBuild")

local record helper end

-- make a convert rel to quad and back function somewhere
-- we need to review if we still want to use doors like this or no. My idea is: no.
global interface Quad
    quad: integer,
    build: Build | nil,
    doors: {Door} | nil,
end

function helper.new()
    return {
        quad = 0,
    }
end

function helper.get_name(quad: Quad): string
    return build_helper.get_name(quad.build)
end

function helper.get_num(quad: Quad): integer
    return quad.quad
end

function helper.get_build(quad: Quad): Build
    return quad.build
end

function helper.get_doors(quad: Quad): {Door}
    return quad.doors
end

function helper.is_init(quad: Quad)
    return quad.quad ~= 0
end

function helper:is_built(quad: Quad): boolean
    return build_helper.is_built(quad.build)
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
        elseif quad == 2 then -- luacheck: ignore
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

function MetaQuad:requireBuild(name, what_chunk)
    local result = self.build:require(name, what_chunk)
    if result == false then return false end

    self.doors = deep_copy.copy(self.build:getPrimitiveDoors(), pairs)
    self:actualizeDoors()
    return true
end

function MetaQuad:setQuad(quad_num, name, what_chunk)
    self.quad = quad_num
    return self:requireBuild(name, what_chunk)
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
    if not self.build:setupBuild(self.quad, chunk_height) then
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

function MetaQuad:finalizeBuild()
    return self.build:finalizeBuild(self.doors)
end

return MetaQuad
