local module = {}

------- Sys Requires -------

------- Own Requires -------
local comms = require("comms") -- luacheck: ignore
local deep_copy = require("deep_copy")

local interface = require("nav_module.nav_interface")
local chunk_move = require("nav_module.chunk_move")
local rel_move = require("nav_module.rel_move")
local door_move = require("nav_module.door_move")
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
    return deep_copy.copy(nav_obj.chunk, ipairs) -- :)
end

function module.get_rel()
    return deep_copy.copy(nav_obj.rel, ipairs)
end

function module.get_height()
    return nav_obj.height
end


function module.set_chunk(x, z)
    nav_obj.chunk[1] = x
    nav_obj.chunk[2] = z
end

function module.set_height(height)
    nav_obj.height = height
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

function module.change_orientation(orient)
    return interface.c_orientation(orient, nav_obj)
end

function module.set_orientation(orient)
    nav_obj.orientation = orient
end

function module.is_setup_navigate_chunk()
    return chunk_move.is_setup
end

function module.setup_navigate_chunk(what_chunk)
    -- luacheck: ignore
    local a, b = chunk_move.setup_navigate_chunk(what_chunk, nav_obj)
end

function module.navigate_chunk(what_kind)
    return chunk_move.navigate_chunk(what_kind, nav_obj)
end

function module.debug_move(dir, distance, forget)
    return interface.debug_move(dir, distance, forget, nav_obj)
end

function module.setup_navigate_rel(what_coords)
    rel_move.setup_navigate_rel(what_coords[1], what_coords[2], what_coords[3])
end

function module.navigate_rel_opaque(what_coords)
    return rel_move.access_opaque(nav_obj, what_coords)
end

function module.navigate_rel()
    return rel_move.navigate_rel(nav_obj)
end

function module.is_setup_door_move()
    return door_move.is_setup()
end

function module.setup_door_move(door_table)
    return door_move.setup_move(door_table, module.get_rel())
end

function module.door_move()
    return door_move.do_move(module)
end

function module.is_sweep_setup()
    return rel_move.is_sweep_setup()
end

-- Future prep basically, doesn't to much
function module.setup_sweep()
    return rel_move.setup_sweep(nav_obj)
end

function module.sweep(is_surface)
    return rel_move.sweep(nav_obj, is_surface)
end


--temp
nav_obj.height = 69
nav_obj.orientation = "west"
nav_obj.abs[1] = -16
nav_obj.abs[2] = 0

nav_obj.rel[1] = 15
nav_obj.rel[2] = 0

nav_obj.chunk[1] = -2
nav_obj.chunk[2] = 0

return module
