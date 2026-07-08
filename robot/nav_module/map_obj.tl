require("deep_copy")
local comms = require("comms")

local map_areas = require("nav_module.map_area")
local area_helper = require("nav_module.Area")

require("nav_module.__h_map_obj")
local primitive_helper = require("build.MetaBuild.BuildPrimitive")
local build_helper = require("build.MetaBuild")

local item_helper = require("inventory.__h_Item")

local record module
    all_builds: {string : {Build}}
end

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
local area_table = map_areas.area_table
--[[local function get_chunk(coord: ChunkCoord): Chunk
    local packed = (coord[1] << 32) | coord[2]
    return map_map[packed]
end--]]
local function get_chunk(coord: ChunkCoord): Chunk
    return map_map[(coord[1] << 32) | coord[2]]
end
local function get_coords(packed: integer): integer, integer
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

function module.try_remove_tag(coord: ChunkCoord, str: ChunkTag, ok_to_fail?: boolean): boolean
    local chunk = get_chunk(coord)

    if ok_to_fail is nil then ok_to_fail = false end
    local was_able_to_remove = false

    if chunk.tags == nil then return false end
    local tags = chunk.tags as {ChunkTag}

    for index, tag in ipairs(tags) do
        if tag == str then
            tags[index] = nil
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
    if chunk.tags == nil then return false end
    
    for _, tag in ipairs((chunk.tags as {ChunkTag})) do
        if tag == str then return true end
    end
    return false
end

--[[function module.get_height(chunk: Chunk): integer
    if chunk.parent_area ~= nil then return chunk.parent_area.height end
    print(comms.robot_send("error", "MetaChunk:getHeight -- could not getHeight"))
    return nil as integer
end--]]

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
    area_helper.add_chunk_to_area(parent, coord)
end

function module.get_doors(coord: ChunkCoord, quad: integer): {DoorInfo} | nil
    local build = module.get_build_ref(coord, quad)
    if build is nil then return nil end
    return (build as Build).doors
end

local function insert_build(build_ref: Build)
    local name = build_ref.name
    if known_buildings[name] == nil then known_buildings[name] = {} end
    local size = #known_buildings[name]
    known_buildings[name][size + 1] = build_ref
end

function module.add_build(coord: ChunkCoord, quad: integer, build_ref: Build): boolean
    if quad < 1 or quad > 4 then
        print(comms.robot_send("error", string.format("failed to add chunk, invalid quad: %d", quad)))
        return false
    end

    local chunk = get_chunk(coord)
    if chunk.builds == nil then chunk.builds = {} end

    local builds: {Build} = chunk.builds as {Build}
    if builds[quad] ~= nil then 
        print(comms.robot_send(
                "error", 
                string.format("Attempted to add a build to a quad that already has a build, quad: %d", quad)
        ))
        return false
    end
    builds[quad] = build_ref
    insert_build(build_ref)

    return true
end

function module.get_build_arr_by_name(name: string): {Build} | nil
    return known_buildings[name] 
end


module.all_builds = known_buildings

-->>-----------------------------------<<--
local type BSaveType = { {string, string, integer, integer, integer, integer} }
local type CSaveType = { {integer, integer, {string}, string | nil}}
local function translate_chunk(chunk: Chunk, coords: ChunkCoord, build_table: BSaveType, chunk_table: CSaveType)
    local area_name: string = (chunk.parent_area as NamedArea).name

    ------- BUILD TABLE --------
    local builds = chunk.builds
    if builds is {integer : Build} then
        -- bd_sub_table = {area_name, build_name, x, z, what_quad}
        for _, build in pairs(builds) do
            local sub_table = {
                area_name,
                build.name,
                coords[1] as integer,
                coords[2] as integer,
                build.height,
                build.quad,
            }
            table.insert(build_table, sub_table)
        end
    end

    ----- CHUNKS PROPER ------
    local sub_table = {
        coords[1],
        coords[2],
        chunk.tags,
        area_name
    }
    local parent_area = chunk.parent_area
    if parent_area is NamedArea then
        sub_table[4] = parent_area.name
    end
    table.insert(chunk_table, sub_table)
end

local type SaveTable = {{NamedArea}, CSaveType, BSaveType}
-- we need data to recreate builds, to recreate areas, and to recreate marks,
function module.get_data(): SaveTable
    -- bd_sub_table = {area_name, build_name, x, z, what_quad}
    local build_table: BSaveType = {}

    -- chunk_proper_sub_table = {x, z, {[marks]}, parent_area}
    local chunk_table: CSaveType  = {}

    for raw_coord, chunk in pairs(map_map) do
        translate_chunk(chunk, {get_coords(raw_coord)}, build_table, chunk_table)
    end

    local big_table = {
        area_table,
        chunk_table,
        build_table,
    }
    return big_table
end

-- local type BSaveType = { {string, string, integer, integer, integer, integer} }
-- local type CSaveType = { {integer, integer, {string}, string | nil}}

-- TODO, change the way chunks are generated so that they are generated only after attempted
-- reinstantiation so that we might provide a different chunk offset, do soon!
function module.re_instantiate(big_table: SaveTable)
    -- module.gen_map_obj(HOME_CHUNK)

    -- First we "recreate" the areas
    area_table = area_helper.area_table_new()
    for _, raw_area in ipairs(big_table[1]) do
        local new_area = COPY(raw_area)
        area_helper.add_named_area(area_table, new_area)
    end

    local chunk_table = big_table[2]

    -- Then we reinstate the basic chunk_info
    -- chunk_proper_sub_table = {x, z, {[marks]}, parent_area}
    for _, chunk_info in ipairs(chunk_table) do
        local x = math.floor(chunk_info[1])
        local z = math.floor(chunk_info[2])
        local coord: ChunkCoord  = {x, z}
        local chunk_ref = module.new_chunk(coord)

        -- this is ok, because de-serialized data is dumped, so ownership is transfered
        chunk_ref.tags = chunk_info[3] as {ChunkTag}
        local area_name = chunk_info[4]
        local area = area_helper.get_named_area(area_table, area_name)
        if area == nil then
            print(comms.robot_send("error", "failure in re-adding parent when re-instaiting chunk" .. x .. ", " .. z))
            goto continue
        end
        module.set_parent(coord, area)

        ::continue::
    end

    -- bd_sub_table = {area_name, build_name, chunk.x, chunk.z, height, quad}
    -- Finally we pretend to build everything that is built
    for _, tbl in ipairs(big_table[3]) do
        local area = area_helper.get_named_area(area_table, tbl[1])
        if area == nil then
            print(comms.robot_send("error", string.format("NamedArea: \":%s\" does not exist -- Reinstate failed", tbl[1])))
        end

        local new_build = build_helper.new(tbl[2], {tbl[3], tbl[4]}, tbl[5], tbl[6])
        local result = primitive_helper.require_build(new_build)
        if result == false then 
            print(comms.robot_send("error", "there was a failure in require a build for reinstating"))
            goto continue
        end

        result = module.add_build(new_build.chunk, new_build.quad, new_build)
        if result == false then 
            print(comms.robot_send("error", "there was a failure in reinstating a building"))
            goto continue
        end

        ::continue::
    end
end

function module.load_preset()
    -- temp
    --[[local name = "home"
    if areas_table:getArea("home") == nil then
        module.create_named_area("home", "green", 69, "Dirt")
    end--]]

    -- perm
    if area_helper.get_named_area(area_table, "gather") == nil then
        area_helper.named_area_new("gather", "green", 69, item_helper.new_item_definition("Dirt", nil))
    end
    if area_helper.get_named_area(area_table, "gather_tree") == nil then
        area_helper.named_area_new("gather_tree", "green", 69, item_helper.new_item_definition("Dirt", nil))
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
    -- module.gen_map_obj(HOME_CHUNK)
    local name = "home"
    if area_helper.get_named_area(area_table, name) == nil then
        area_helper.named_area_new(name, "green", 4, item_helper.new_item_definition("Dirt", nil))
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
