------- Sys Requires -------
local serialize = require("serialization")

------- Own Requires -------
local helper = require("__h_map_obj")
local comms = require("comms")
local deep_copy = require("deep_copy")

require("nav_module.__h_map_obj")
local interactive = require("interactive")
-- require("build.MetaBuild")

local record module end

-- THIS IS A GREAT READ: https://poga.github.io/lua53-notes/table.html,
-- I'll probably maximize array access through pre-allocation write-to-disc de-allocation

-- Speaking of reading: https://web.engr.oregonstate.edu/~erwig/papers/DeclScripting_SLE09.pdf is this peak chat?
-- and smart accessing of disc and remote stored data eventually, so I'll not use string indeces.
-- is_home basically means: is a part of the base

-- If I want to avoid eager initialising the chunks I'll have to disconnect array index from chunk coordinate,
-- We'll be using [x,z] -> map_map (lol) = {}; map_map[tostring(x) .. "," .. tostrong(z)] = chunk
-- maybe integer packing will be gooe enough?


local map_map: {integer : Chunk} = {}
local known_buildings: {string : {Build}} = {}
local map_areas = require("nav_module.map_area")
local area_table = map_areas.area_table
--[[local function get_chunk(coord: ChunkCoord): Chunk
    local packed = (coord[1] << 32) | coord[2]
    return map_map[packed]
end--]]
local macroexp get_chunk(coord: ChunkCoord): Chunk
    return map_map[(coord[1] << 32) | coord[2]]
end
local macroexp get_coords(): integer, integer
    return packed >> 32, packed & 0xFFFFFFFF
end


-- CHUNK:
--  x: integer
--  z: integer
--  tags: nil | {Tag} (?)
--  parent_area: nil | Area
--  builds: {Build}
-- //////

function module.new_chunk(coord: ChunkCoord): Chunk
    local new_chunk = {
        tags = nil,
        parent_area = nil,
        builds  = nil,
    }
    map_map[(coord[1] << 32) | coord[2]] = new_chunk
    return new_chunk
end

function module.add_tag(coord: ChunkCoord, str: ChunkTag)
    local chunk = get_chunk(coord)
    if chunk.tags == nil then chunk.tags = {} end
    for _, tag in ipairs(chunk.tags as {ChunkTag}) do
        if tag == str then return end     
    end
    table.insert(chunk.tags, str)
end

function module.try_remove_tag(coord: ChunkCoord, str: ChunkTags, ok_to_fail?: boolean): boolean
    local chunk = get_chunk(coord)

    if ok_to_fail is nil then ok_to_fail = false end
    local was_able_to_remove = false
    for index, tag in ipairs(chunk.tags) do
        if tag == str then
            chunk.tags[index] = nil
            was_able_to_remove = true
            break
        end
    end

    if not was_able_to_remove then
        if not ok_to_fail then
            print(comms.robot_send("warning", "Attempted to remove a mark that is not present: \"" .. str  .. "\""))
        end
        return false
    end
    return true
end

function module.check_marks(coord: ChunkCoord, str: ChunkTag): boolean
    local chunk = get_chunk(coord)
    if chunk.tags is nil then return false end
    for _, tag in ipairs(chunk.tags) do
        if tag == str then return true end
    end
    return false
end

function module.get_height(chunk: Chunk): integer
    if chunk.parent_area ~= nil then return chunk.parent_area.height end
    print(comms.robot_send("error", "MetaChunk:getHeight -- could not getHeight"))
    return nil as integer
end

function module.get_build_ref(coord: ChunkCoord, what_quad: integer): Build | nil
    local chunk = get_chunk(coord)
    local builds = chunk.builds
    if builds is {Build} then
        local build = builds[what_quad]
        if build == nil then return nil else return build end
    end
    return nil
end

function module.get_name(coord: ChunkCoord, quad: integer): string | nil
    local build = module.get_build_ref(coord, quad)
    if build is Build then return build.name end
    return nil
end

function module.set_parent(coord: ChunkCoord, parent: Area)
    local chunk = get_chunk(coord)
    chunk.parent_area = parent
end

function module.get_doors(coord: ChunkCoord, quad: integer): {DoorInfo} | nil
    local build = module.get_build_ref(coord, quad)
    if build is nil then return nil end
    return (build as Build).doors
end

function module.insert_build(name: string, build_ref: Build)
    if known_buildings[name] == nil then known_buildings[name] = {} end
    local size = #known_buildings[name]
    known_buildings[name][size + 1] = build_ref
end

function known_buildings:insert(name, build_ref)
    if self[name] == nil then self[name] = {} end
    local size = #self[name]
    self[name][size + 1] = build_ref
end

module.all_builds = known_buildings

-->>-----------------------------------<<--
local type BSaveType = { {string, string, integer, integer, integer} }
local type CSaveType = { {integer, integer, {string}, string | nil}}
local function translate_chunk(chunk: Chunk, coords: ChunkCoord, build_table: {BSaveType}, chunks_table: {CSaveType})
    ------- BUILD TABLE --------
    local builds = chunk.builds
    if builds is {integer : Build} then
        -- bd_sub_table = {area_name, build_name, x, z, what_quad}
        for _, build in pairs(builds) do
            local sub_table = {
                chunk.parent_area.name,
                build.name,
                coords[1] as integer,
                coords[2] as integer,
            }
            table.insert(build_table, sub_table)
        end
    end

    ----- CHUNKS PROPER ------
    local sub_table = {
        math.floor(chunk.x),
        math.floor(chunk.z),
        chunk.marks,
        chunk.parent_area.name
    }
    local parent_area = chunk.parent_area
    if parent_area is NamedArea then
        sub_table[4] = parent_area.name
    end
    table.insert(chunks_proper, sub_table)
end

-- we need data to recreate builds, to recreate areas, and to recreate marks,
function module.get_data(): {{NamedArea}, BSaveType, CSaveType}
    -- bd_sub_table = {area_name, build_name, x, z, what_quad}
    local build_table: BSaveType = {}

    -- chunk_proper_sub_table = {x, z, {[marks]}, parent_area}
    local chunk_table: CSaveType  = {}

    for raw_coord, chunk in pairs(map_map) do
        translate_chunk(chunk, get_coords(raw_coord), build_table, chunk_table)
    end

    local big_table = {
        areas_table,
        chunks_table,
        build_table,
    }
    return big_table
end

-- TODO, change the way chunks are generated so that they are generated only after attempted
-- reinstantiation so that we might provide a different chunk offset, do soon!
function module.re_instantiate(big_table)
    -- module.gen_map_obj(HOME_CHUNK)

    -- First we "recreate" the areas
    areas_table = AreasTable:new()
    for _, raw_area in ipairs(big_table[1]) do
        local new_area = deep_copy.copy(NamedArea, pairs) -- makes sure we copy the functions over
        for name, value in pairs(raw_area) do
            new_area[name] = value
        end
        areas_table:addArea(new_area)
    end

    local chunks_proper = big_table[2]

    -- Then we reinstate the basic chunk_info
    -- chunk_proper_sub_table = {x, z, {[marks]}, height_override, roads_cleared}
    for _, chunk_info in ipairs(chunks_proper) do
        local x = math.floor(chunk_info[1])
        local z = math.floor(chunk_info[2])
        local chunk_ref = module.chunk_exists({x, z})
        if chunk_ref == nil then
            print(comms.robot_send("error", "failed to re-instantiate chunk: " .. x .. ", " .. z))
            goto continue
        end

        -- this is ok, because de-serialized data is dumped, so ownership is transfered
        chunk_ref.chunk.marks = chunk_info[3]
        chunk_ref.chunk.height_override = chunk_info[4]
        chunk_ref.chunk.roads_cleared = chunk_info[5]

        local area_name = chunk_info[6]
        local area = areas_table:getArea(area_name)
        if area == nil then
            print(comms.robot_send("error", "failure in re-adding parent when re-instaiting chunk" .. x .. ", " .. z))
            goto continue
        end
        chunk_ref.chunk.parent_area = area

        ::continue::
    end

    -- Finally we pretend to build everything that is built
    for _, tbl in ipairs(big_table[3]) do
        -- bd_sub_table = {area_name, build_name, x, z, what_quad}
        local result = module.pretend_build(tbl[1], tbl[2], {tbl[3], tbl[4]}, tbl[5])
        if result ~= 0 then print(comms.robot_send("error", "there was a failure in reinstating a building")) end
    end
end


local function get_door_info(what_chunk, what_quad)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then
        print(comms.robot_send("error", "map_obj, failed to get door info -- chunk doesn't exist"))
        return nil
    end

    return map_chunk:getDoors(what_quad)
end

-- When we first add a builing to a named area we should also add an order to clear the road at the specified
-- chunk at the specified height
-- NamedArea:new(name, colour, height, floor_block)
function module.create_named_area(name, colour, height, floor_block)
    local already_exists = false
    for _, area in ipairs(areas_table) do
        if area.name == name then
            already_exists = true
            break
        end
    end
    if already_exists then
        print(comms.robot_send("error", "Attempted to create area that already exits, name: " .. name))
        return false
    end

    local new_area = NamedArea:new(name, colour, height, floor_block)
    if new_area == nil then
        print(comms.robot_send("error", "failed creating named area in map_obj.create_named_area"))
        return false
    end

    local to_print = serialize.serialize(new_area, true)
    print(comms.robot_send("debug", "Created new named_area definition"))
    print(comms.robot_send("debug", to_print))
    --table.insert(areas_table, new_area)
    areas_table:addArea(new_area)
    return true
end

function module.chunk_exists(what_chunk)
    local x = what_chunk[1] + map_obj_offsets[1];
    local z = what_chunk[2] + map_obj_offsets[2];

    if map_obj[x] == nil or map_obj[x][z] == nil then
        local rx = what_chunk[1]
        local rz = what_chunk[2]
        print(comms.robot_send("error", string.format("ungenerated chunk: lxz: {%d, %d} || rxz: {%d, %d}", x, z, rx, rz)))
        return nil
    end
    return MetaChunk:new(map_obj[x][z])
end

function module.chunk_set_parent(what_chunk, what_area, height_override)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    what_area:addChunkToSelf(what_chunk)
    return map_chunk:setParent(what_area, height_override)
end

function module.chunk_set_parent_name(what_chunk, area_name, height_override)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    local what_area = areas_table:getArea(area_name)
    if what_area == nil then return false end

    what_area:addChunkToSelf(what_chunk)
    return map_chunk:setParent(what_area, height_override)
end

function module.get_height(what_chunk)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return -1 end

    return map_chunk:getHeight()
end

-- Make sure that any reference that you get to any chunk is not long-lived, I know that is a big
-- ask, but please please please please, always have that in attention, otherwise serialization
-- is fucked, and you create a massive footgun for youself in many ways!
--
function module.get_chunk(what_chunk) -- Evil function!
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return nil end -- changed from returning -1 to return nil, hopefully no problems I hope

    return map_chunk
end

function module.add_quad(what_chunk, what_quad, primitive_name)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:addQuad(what_quad, primitive_name, what_chunk)
end

function module.setup_build(what_chunk, what_quad)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:setupBuild(what_quad) -- pay attention to what are we returning
end

function module.do_build(what_chunk, what_quad)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    local result_bool, result_string, coords, symbol = map_chunk:doBuild(what_quad) -- pay attention to what are we returning
    if result_string == "done" then
        local primitive_name = map_chunk:getName(what_quad)
        if primitive_name == nil then error(comms.robot_send("fatal", "Impossible state, map_obj.do_build")) end
        known_buildings:insert(primitive_name, map_chunk:getBuildRef(what_quad), what_chunk)

        map_chunk:finalizeBuild(what_quad)
    end

    return result_bool, result_string, coords, symbol
end

-- This might be a bitch to update if we change the way we do builds posteriorly,
-- I hope not, at least not so soon
function module.pretend_build(area_name, build_name, what_chunk, what_quad) -- I think this is all
    -- Checks if build is already built and returns early
    local chunk_quads = module.get_chunk(what_chunk).chunk.meta_quads
    if chunk_quads ~= nil then
        for _, quad in ipairs(chunk_quads) do
            local build = quad:getBuild()

            if build == nil then goto continue end
            if build.name == build_name and quad:getNum() == what_quad then return 0 end
            ::continue::
        end
    end

    local area = areas_table:getArea(area_name)
    if area == nil then return 1 end

    module.chunk_set_parent(what_chunk, area, nil) -- nil = no override

    local chunk = module.chunk_exists(what_chunk)
    if chunk == nil then return 2 end
    if not module.add_quad(what_chunk, what_quad, build_name) then return 3 end
    if not module.setup_build(what_chunk, what_quad) then return 4 end

    known_buildings:insert(build_name, chunk:getBuildRef(what_quad), what_chunk) -- important lol
    if not chunk:finalizeBuild(what_quad) then return 5 end

    return 0
end


function module.get_area(name)
    return areas_table:getArea(name)
end

function module.add_mark_to_chunk(what_chunk, str)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:addMark(str)
end

function module.try_remove_mark_from_chunk(what_chunk, str, can_fail)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:tryRemoveMark(str, can_fail)
end


function module.force_set_build(nav, what_chunk, what_quad)
    local map_chunk = module.chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    -- I think that when a chunk has never "experienced" a building in it before, it will not have a meta_quads
    -- field so we need to check for that in order to avoid unfortunate crashes
    local meta_quads = map_chunk.chunk.meta_quads
    if meta_quads == nil then return false end

    local quad = meta_quads[what_quad]
    if quad == nil then return false end

    if not quad:isBuilt() then return false end
    nav.set_cur_building(quad:getBuild())

    return true
end

-- module.gen_map_obj(nil)
function module.load_preset()
    -- module.gen_map_obj(HOME_CHUNK)

    -- temp
    --[[local name = "home"
    if areas_table:getArea("home") == nil then
        module.create_named_area("home", "green", 69, "Dirt")
    end--]]

    -- perm
    if areas_table:getArea("gather") == nil then
        module.create_named_area("gather", "green", 69, "Dirt")
    end
    if areas_table:getArea("gather_tree") == nil then
        module.create_named_area("gather_tree", "green", 69, "Dirt")
    end
    -- /perm

    --[[local what_chunk = {-2,0}
    module.get_chunk(what_chunk).chunk.roads_cleared = true

    -- I think this is being erased by the loading process :P
    what_chunk[2] = -1
    module.get_chunk(what_chunk).chunk.roads_cleared = true


    local chunk = {-2, 0}
    module.pretend_build("home", "coke_quad", chunk, 1)
    module.pretend_build("home", "oak_tree_farm", chunk, 3)
    module.pretend_build("home", "sp_storeroom", what_chunk, 1)
    module.pretend_build("home", "small_home", what_chunk, 4)--]]
end

if V_ENV then
function module.virtual_preset()
    module.gen_map_obj(HOME_CHUNK)

    local name = "home"
    if areas_table:getArea("home") == nil then
        module.create_named_area("home", "green", 4, "Dirt")
    end
end
end

-- more temp
--[[
module.create_named_area("gather", "green", 69, "dirt")
local area = areas_table:getArea("gather")
area:addChunkToSelf(what_chunk)
module.chunk_set_parent(what_chunk, area, nil)
--]]

-- x and z are still fine here, even after assigning to area

return module
