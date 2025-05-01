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
    x = 0,
    y = 0,
    c_type = chunk_type.Nil,
    meta_quads = nil
}
function MetaChunk:zeroed()
    return deep_copy.copy_table(self, pairs)
end

function MetaChunk:mark(what_chunk, c_type)
    local c_type = chunk_type[as_what]
    if c_type == nil then print(comms.robot_send("error", "module.mark_chunk 01")) end

    local x = what_chunk[1]; local z = what_chunk[2];

    local map_chunk = map_obj[x][z]
    if map_chunk == nil then print(comms.robot_send("error", "ungenerated chunk")) end

    map_chunk.c_type = c_type
end

local function empty_quad_table()
    local quads = {MetaQuad:zeroed, MetaQuad:zeroed, MetaQuad:zeroed, MetaQuad:zeroed}
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
        print(comms.robot_send("error", "cannot build what is already built!"))
        return false
    end
    return this_quad:setupBuild()
end

--local map_obj = {MetaChunk:zeroed()}
local map_obj = {{}}
local map_obj_offsets = {0,0}   -- offsets logical 0,0 in the array in order to translate it to "real" 0,0
                                -- what this means is that if set the "origin", the "map centre" of the robot
                                -- à posteriori then we don't need to re-alloc the array

function gen_map_obj()
    local size = 30 -- generate 30x30 square of chunks
    for zindex, size, 1 do
        for xindex, size, 1 do
            map_obj[x][z] = MetaChunk:zeroed()
        end
    end
end

-----------------

-- The robot will understand chunk boundries as movement highways in between chunks
-- and focus inner-chunk movement inside it's own chunk

-- please centre the robot in the top left (north oriented map) of the "origin chunk" 
-- Moving north = -Z, moving east = +X

-- nav_obj will get passed around like your mother's cadaver at a George Bataille ritual reification fesitval
-- singleton btw, this is why there is no "nav_obj:new()" function
local nav_obj = {
    c_zero = {0,0} ,

    abs = {0,0} , -- (x,z)
    height = 0 ,
    rel = {0,0} , -- (x,z)
    chunk = {0,0} , -- (x,z)

    orientation = "north"
}

function module.set_chunk(x, z)
    nav_obj.chunk[1] = x
    nav_obj.chunk[2] = z
end

function module.set_absolute(x,z,y)
    nav_obj.abs[1] = x
    nav_obj.abs[2] = z
    nav_obj.height = y
end

function module.set_rel(x, z)
    nav_obj.rel[1] = x
    nav_obj.rel[2] = z
end

function module.set_orientation(orient)
    nav_obj.orientation = orient
end

function module.setup_navigate_chunk(what_chunk)
    local a, b = chunk_move.setup_navigate_chunk(what_chunk, nav_obj)
end

function module.navigate_chunk(what_kind)
    return chunk_move.navigate_chunk(what_kind, nav_obj)
end

function module.debug_move(dir, distance, forget)
    interface.debug_move(dir, distance, forget, nav_obj)
end

function module.mark_chunk(what_chunk, as_what)

end

function module.setup_navigate_rel(what_chunk)

end

function module.navigate_rel(clear)

end

function module.build_quad()

end

return module
