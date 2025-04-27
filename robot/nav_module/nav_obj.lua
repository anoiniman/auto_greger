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
-- and smart accessing of disc and remote stored data eventually, so I'll not use string indeces.
-- is_home basically means: is a part of the base
local MetaChunk = {
    x = 0,
    y = 0,
    c_type = chunk_type.Nil,
    meta_quads = {MetaQuad:zeroed()}
}
MetaChunk.__index = MetaChunk

function MetaChunk:zeroed()
    local obj = {}

    setmetatable(obj, self)
    return obj
end

function MetaChunk

local map_obj = {MetaChunk:zeroed()}

-----------------

-- The robot will understand chunk boundries as movement highways in between chunks
-- and focus inner-chunk movement inside it's own chunk

-- please centre the robot in the top left (north oriented map) of the "origin chunk" 
-- Moving north = -Z, moving east = +X

-- nav_obj will get passed around like your mother's cadaver at a George Bataille ritual reification fesitval
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
    --print(comms.robot_send("debug", "c_nearest_side: " .. a .. " || " .. "r_nearest_side: " .. b))
    --io.read()
end

function module.navigate_chunk(what_kind)
    --print("navigate chunk nav_obj")
    --io.read()
    return chunk_move.navigate_chunk(what_kind, nav_obj)
end

function module.debug_move(dir, distance, forget)
    interface.debug_move(dir, distance, forget, nav_obj)
end

function module.mark_chunk(what_chunk, as_what)
    if chunk_type[as_what] == nil then error("module.mark_chunk 01") end
    if 
end

function module.rel_move(clear)

end

function module.build_quad()

end

return module
