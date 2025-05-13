local module = {}

------- Sys Requires -------
local io = require("io")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local interface = require("nav_module.nav_interface")
local chunk_move = require("nav_module.chunk_move")
local rel_move = require("nav_module.rel_move")

local MetaBuild = require("build.MetaBuild")
local MetaDoorInfo = require("build.MetaBuild.MetaDoorInfo")
local MetaQuad = require("nav_module.MetaQuad")
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

function module.get_chunk()
    return deep_copy.copy(chunk, ipairs) -- :)
end

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

function module.is_setup_navigate_chunk()
    return chunk_move.is_setup
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


function module.setup_navigate_rel(what_coords)
    rel_move.setup_navigate_rel(what_coords[1], what_coords[2], what_coords[3])
end

function module.navigate_rel()
    return rel_move.navigate_rel(nav_obj)
end

return module
