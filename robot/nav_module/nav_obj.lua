local module = {}

local interface = require("nav_module.nav_interface")
local chunk_move = require("nav_module.chunk_move")
local io = require("io")
local comms = require("comms")


-- Chunks are 16 by 16, roads includes they become 14 by 14, this is then sub devided into 4 - 7 by 7 sub-chunks
-- Builds (tm) will occupy marked sub-chunks inside a chunk instead of arbitrary rectangles, for ease of navigation
-- and they'll always be accessed through the "outside", this is to say, through the "road-blocks/lines"
-- if we want to get fancy, we can mark-down door locations and shit, so that we can have walls and enclosed buildigs etc

local QuadTypeEnum = {
    NULL = {},
    Hole_Home = {},
    Coke_Array = {},
    Storage_T_One = {},
} -- etc

-- make a convert rel to quad function somewhere
local MetaQuad = {x = 0, y = 0, QuadTypeEnum.NULL}
function MetaQuad:zeroed()
    local obj = {}

    setmetatable(obj, self)
    self.__index = self
    return obj
end


-- is_home basically means: is a part of the base
local MetaChunk = {x = 0, y = 0, is_home = false, MetaQuad:zeroed()}
--local MetaChunk = {}

function MetaChunk:zeroed()
    local obj = {}

    setmetatable(obj, self)
    self.__index = self
    return obj
end

--[[
local map_obj = {
    chunks = {MetaChunk:zeroed()},
    -- Maybe this table will grow in the future!     
}
--]]
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

end

return module
