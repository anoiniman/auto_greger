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

    cur_building = nil,
    orientation = "north"
}

function module.print_nav_obj()
    local print_buffer = {"\n"}
    for k, v in pairs(nav_obj) do
        if k == "cur_building" then
            local name = v.name
            local str = string.format("%s = %s\n", tostring(k), name)
            table.insert(print_buffer, str)
            goto continue
        end

        if type(v) == "table" then
            local str = string.format("%s = (%s, %s)\n", tostring(k), tostring(v[1]), tostring(v[2]))
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

-- (the locks are what comes to mind, I don't think there is any other long-term state in there)
function module.get_data(map)
    local bd_info = "nil"
    if nav_obj.cur_building ~= nil then
        local bd_chunk = nav_obj.cur_building.what_chunk
        local door_info = nav_obj.cur_building.doors

        local bd_quad = nil
        for _, quad in ipairs(map.get_chunk(bd_chunk).chunk.meta_quads) do
            if door_info == quad:getDoors() then -- checks for refs matching, witch should be the case
                bd_quad = quad
                break
            end
        end
        if bd_quad == nil then
            print(comms.robot_send("error",
                "This should no happen, if the building is valid then we should be \z
                                    able to find the quad this way"
            ))
            bd_info = "nil"
        else
            bd_info = {bd_chunk, bd_quad.quad}
        end
    end

    local big_table = {
        nav_obj.c_zero,
        nav_obj.abs,
        nav_obj.height,
        nav_obj.rel,
        nav_obj.chunk,

        nav_obj.orientation,
        bd_info
    }
    return big_table
end

function module.re_instantiate(big_table, map)
    local bd_info = big_table[7]
    local bd_ref = nil
    if bd_info ~= nil and bd_info ~= "nil" then
        local chunk_ref = map.get_chunk(bd_info[1])
        bd_ref = chunk_ref.chunk.meta_quads[bd_info[2]].build
    end

    nav_obj = {
        c_zero = big_table[1],

        abs = big_table[2], -- (x,z)
        height = big_table[3],
        rel = big_table[4], -- (x,z)
        chunk = big_table[5], -- (x,z)

        cur_building = bd_ref,
        orientation = big_table[6]
    }
end

function module.get_cur_building()
    return nav_obj.cur_building
end

function module.set_cur_building(new)
    nav_obj.cur_building = new
end

function module.get_chunk()
    return deep_copy.copy(nav_obj.chunk, ipairs) -- :)
end

function module.get_abs()
    return deep_copy.copy(nav_obj.abs, ipairs) -- :)
end

function module.get_rel()
    return deep_copy.copy(nav_obj.rel, ipairs)
end

function module.get_height()
    return nav_obj.height
end

function module.get_orientation()
    return nav_obj.orientation
end

function module.set_chunk(x, z)
    nav_obj.chunk[1] = x
    nav_obj.chunk[2] = z
end

function module.set_height(height)
    nav_obj.height = height
end

function module.set_pos_auto(x, z, y)
    if y ~= nil then nav_obj.height = y end

    nav_obj.abs[1] = x
    nav_obj.abs[2] = z

    nav_obj.rel[1] = x % 16
    nav_obj.rel[2] = z % 16

    nav_obj.chunk[1] = math.floor(x / 16)
    nav_obj.chunk[2] = math.floor(z / 16)
end

function module.set_rel(x, z)
    nav_obj.rel[1] = x
    nav_obj.rel[2] = z
end

function module.change_orientation(orient)
    return interface.c_orientation(orient, nav_obj)
end

function module.get_opposite_orientation()
    return interface.get_opposite_orientation(nav_obj)
end

function module.rotate_right()
    return interface.rotate_right(nav_obj)
end

function module.set_orientation(orient)
    nav_obj.orientation = orient
end

function module.is_in_chunk(target_chunk)
    return chunk_move.quick_check(nav_obj, target_chunk)
end

function module.is_setup_navigate_chunk()
    return chunk_move.is_setup()
end

function module.setup_navigate_chunk(what_chunk)
    chunk_move.setup_navigate_chunk(what_chunk, nav_obj)
end

function module.navigate_chunk(what_kind)
    return chunk_move.navigate_chunk(what_kind, nav_obj)
end

function module.force_reset_navigate_chunk()
    chunk_move.reset()
end


-- This is debug_move, but useful for surface navigation
function module.surface_move(dir)
    return interface.r_move("surface", dir, nav_obj, EMPTY_TABLE)
end

function module.debug_move(dir, distance, forget)
    return interface.debug_move(dir, distance, forget, nav_obj)
end

function module.force_forward()
    return interface.debug_move(nav_obj.orientation, 1, nil, nav_obj)
end

function module.is_setup_navigate_rel()
    return rel_move.is_setup()
end

function module.setup_navigate_rel(what_coords)
    rel_move.setup_navigate_rel(what_coords[1], what_coords[2], what_coords[3])
end

function module.navigate_rel_opaque(what_coords)
    return rel_move.access_opaque(nav_obj, what_coords)
end

function module.navigate_rel(extra_sauce)
    return rel_move.navigate_rel(nav_obj, extra_sauce)
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
