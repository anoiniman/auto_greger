require("prelude")
local comms = require("comms")
require("deep_copy")
require("Position")
require("build.MetaBuild.__h_init")
require("nav_module.DirectionEnum")
require("nav_module.__h_map_obj")
require("nav_module.chunk_coord")

local type C = CoordinateType

-- The robot will understand chunk boundries as movement highways in between chunks
-- and focus inner-chunk movement inside it's own chunk

-- please centre the robot in the top left (north oriented map) of the "origin chunk"
-- Moving north = -Z, moving east = +X

-- singleton btw, this is why there is no "nav_obj:new()" function
local record module end
local interface NavObj
    c_zero: Pos2D

    abs: Pos2D
    height: integer

    cur_building: Build | nil
    orientation: DirectionEnum
end

local nav_obj: NavObj = {
    c_zero = {0, 0},

    abs = {0, 0},
    height = 0,

    cur_building = nil,
    orientation = "north"
}

function module.get_obj(): nav_obj
    return nav_obj
end

function module.print_nav_obj()
    local print_buffer = {"\n"}
    for k, v in pairs(nav_obj as {string : any}) do
        if k == "cur_building" then
            local name = (v as Build).name
            local str = string.format("%s = %s\n", tostring(k), name)
            table.insert(print_buffer, str)
            goto continue
        end

        if type(v) == "table" then
            local str = string.format("%s = (%s, %s)\n", tostring(k), tostring((v as {integer})[1]), tostring((v as {integer})[2]))
            table.insert(print_buffer, str)
            goto continue
        elseif type(v) ~= "number" and type(v) ~= "string" then goto continue end

        local str = string.format("%s = (%s)\n", tostring(k), tostring(v))
        table.insert(print_buffer, str)
        ::continue::
    end

    local final_str = table.concat(print_buffer)
    print(comms.robot_send("info", final_str))
end

local type BDInfo = {
    ChunkCoord,
    integer
}

local type SaveData = {
    Pos2D,
    Pos2D,
    integer,
    DirectionEnum,
    BDInfo | string
}

-- (the locks are what comes to mind, I don't think there is any other long-term state in there)
function module.get_data(): SaveData
    local bd_info: BDInfo | string = "nil"
    local cur_building = nav_obj.cur_building
    if cur_building is Build then
        bd_info = {cur_building.chunk, cur_building.quad}
    end

    local big_table = {
        nav_obj.c_zero,
        nav_obj.abs,
        nav_obj.height,

        nav_obj.orientation,
        bd_info
    }
    return big_table
end

function module.re_instantiate(big_table_: {any}, map: FakeMap)
    local big_table: SaveData = big_table_ as SaveData

    local bd_info_ = big_table[5]
    local bd_ref: Build | nil = nil
    if bd_info_ ~= nil and bd_info_ ~= "nil" then
        local bd_info: BDInfo = bd_info_ as BDInfo
        bd_ref = map.get_build(bd_info[1], bd_info[2])
    end

    nav_obj = {
        c_zero = big_table[1],

        abs = big_table[2],
        height = big_table[3],

        orientation = big_table[4],
        cur_building = bd_ref,
    }
end

function module.get_cur_building(): Build
    return nav_obj.cur_building
end

function module.set_cur_building(new: Build)
    nav_obj.cur_building = new
end

function module.get_chunk(): ChunkCoord
    local chunk_coord = {math.floor(nav_obj.abs[1] as integer / 16), math.floor(nav_obj.abs[2] as integer / 16)}
    return chunk_coord
end

function module.get_abs(): Pos2D
    return COPY(nav_obj.abs, ipairs)
end

function module.get_rel(): Pos2D
    local rel = {(nav_obj.abs[1] as integer % 16) as C.X, (nav_obj.abs[2] as integer % 16) as C.Z}
    return rel
end

function module.get_height(): integer
    return nav_obj.height
end

function module.get_orientation(): DirectionEnum
    return nav_obj.orientation
end

function module.set_height(height: integer)
    nav_obj.height = height
end

function module.set_pos(x: integer, z: integer, y?: integer)
    if y ~= nil then nav_obj.height = y end

    nav_obj.abs[1] = x
    nav_obj.abs[2] = z
end

function module.set_orientation(orient: DirectionEnum)
    nav_obj.orientation = orient
end

--temp, you know what, I'll keep you as a default, what could go wrong
module.set_pos(-16, 0, 69)
nav_obj.orientation = "west"
nav_obj.abs[1] = -16
nav_obj.abs[2] = 0

if V_ENV then
    local test_interface = require("virtual.tests")
    test_interface:registerObject(nav_obj, "nav_obj", nil)
end

return module
