local module = {}

------- Sys Requires -------
local io = require("io")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local interface = require("nav_module.nav_interface")
local chunk_move = require("nav_module.chunk_move")

local MetaBuild = require("build.MetaBuild")
local MetaDoorInfo = require("build.MetaBuild.MetaDoorInfo")
local MetaQuad = require("nav_module.MetaQuad")
-- I am not really sure if this is important/necessary, but futre proofing I guess
local chunk_type = {
    Nil = {},
    Home = {},
    Mine = {} 
}

-- THIS IS A GREAT READ: https://poga.github.io/lua53-notes/table.html, I'll probably maximize array access through pre-allocation write-to-disc de-allocation
-- Speaking of reading: https://web.engr.oregonstate.edu/~erwig/papers/DeclScripting_SLE09.pdf is this peak chat?
-- and smart accessing of disc and remote stored data eventually, so I'll not use string indeces.
-- is_home basically means: is a part of the base
local MetaChunk = {
    c_type = chunk_type.Nil,
    height = -1,
    meta_quads = nil
}
function MetaChunk:new()
    return deep_copy.copy_table(self, pairs)
end

function MetaChunk:mark(c_type, height)
    local c_type = chunk_type[as_what]
    if c_type == nil then
        print(comms.robot_send("error", "module.mark_chunk invalid c_type")) 
        return false
    end
    if height < 0 or height > 255 then
        print(comms.robot_send("error", "module.mark_chunk invalid height")) 
        return false
    end

    self.c_type = c_type
    self.height = height

    return true
end

local function empty_quad_table()
    local quads = {MetaQuad:new(), MetaQuad:new(), MetaQuad:new(), MetaQuad:new()}
    return quads
end

function MetaChunk:quadChecks(what_quad_num, from_where)
    if what_quad_num > 4 or what_quad_num < 1 then
        print(comms.robot_send("error", "-- " .. from_where .. " --" .. "specified invalid quad_num: \"" .. tostring(what_quad_num) .. "\""))
        return false
    end
    if self.meta_quads == nil then self.meta_quads = empty_quad_table() end
    return true
end

function MetaChunk:addQuadCommon(what_quad_num, what_build)
    local this_quad = self.meta_quads[what_quad_num]
    local result = this_quad:setQuad(what_quad_num, what_build)

    if result == true then
        return true
    end
    print(comms.robot_send("error", "couldn't add build to quad"))
    return false
end

function MetaChunk:addQuad(what_quad_num, what_build)
    if not self:quadChecks(what_quad_num, "addQuad") then return false end
    if self.meta_quads[what_quad_num]:getNum() ~= 0 then 
        print(comms.robot_send("error", "trying to overwrite already defined quad, without specifing desire to overwrite!"))
    end
    self:addQuadCommon(what_quad_num, what_build)
end

function MetaChunk:replaceQuad(what_quad_num, what_build)
    if not self:quadChecks(what_quad_num, "replaceQuad") then return false end
    local this_quad = self.meta_quads[what_quad_num]
    if this_quad:getNum() ~= 0 and this_quad:isBuilt() then 
        print(comms.robot_send("error", "trying to overwrite already BUILT quad, UNIMPLEMENTED!"))
    end
    self:addQuadCommon(what_quad_num, what_build)
end

function MetaChunk:setupBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "setupBuild") then return false end

    local this_quad = self.meta_quads[what_quad_num]
    if this_quad.isBuilt() then
        print(comms.robot_send("error", "cannot prepare to build what is already built!"))
        return false
    end
    return this_quad:setupBuild()
end

function MetaChunk:doBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "setupBuild") then return false end

    local this_quad = self.meta_quads[what_quad_num]
    if this_quad.isBuilt() then
        print(comms.robot_send("error", "cannot build what is already built!"))
        return false
    end
    return this_quad:doBuild()
end

-->>-----------------------------------<<--

--local map_obj = {MetaChunk:zeroed()}
local map_obj = {{}}
local map_obj_offsets = {0,0}   -- offsets logical 0,0 in the array in order to translate it to "real" 0,0
                                -- what this means is that if set the "origin", the "map centre" of the robot
                                -- à posteriori then we don't need to re-alloc the array

local function gen_map_obj()
    local size = 30 -- generate 30x30 square of chunks
    for z = 1, size, 1 do
        for x = 1, size, 1 do
            map_obj[x][z] = MetaChunk:new()
        end
    end
end

local function chunk_exists(what_chunk)
    local x = what_chunk[1]; local z = what_chunk[2];
    local map_chunk = map_obj[x][z]
    if map_chunk == nil then
        print(comms.robot_send("error", "ungenerated chunk")) 
    end

    return map_chunk
end

function module.mark_chunk(what_chunk, as_what, at_height)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:mark(as_what, at_height)
end

function module.add_quad(what_chunk, what_quad, primitive_name)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:addQuad(what_quad, primitive_name)
end

function module.setup_build(what_chunk, what_quad)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:setupBuild(what_quad) -- pay attention to what are we returning
end

function module.do_build(what_chunk, what_quad)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:doBuild(what_quad) -- pay attention to what are we returning
end

return module
