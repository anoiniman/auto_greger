local module = {}

------- Sys Requires -------
local serialize = require("serialization")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local interactive = require("interactive")
-- YOU CANNOT IMPORT EVAL.NAVIGATE, IT BECOMES CIRCULAR YOU DUFUS
--local eval_nav = require("eval.navigate")

local MetaQuad = require("nav_module.MetaQuad")
local BuildInstruction = require("build.MetaBuild.BuildInstruction")


local AreasTable = {}
function AreasTable:new()
    local new = deep_copy.copy(self, pairs)
    return new
end

function AreasTable:addArea(new_area)
    for _, area in ipairs(self) do -- checks if the area is already added
        if area.name == new_area.name then return end
    end

    table.insert(self, new_area)
end

function AreasTable:isInArea(what_chunk) -- luacheck: ignore
    for _, area in ipairs(self) do
        for _, area_chunk in ipairs(area.chunks) do
            if what_chunk[1] == area_chunk[1] and what_chunk[2] == area_chunk[2] then
                return true
            end
        end
    end
    return false
end
function AreasTable:getArea(name) -- luacheck: ignore
    for _, area in ipairs(self) do
        if area.name == name then return area end
    end
    return nil
end
local areas_table = AreasTable:new()

-- Names MUST be unique, they are ID's, IDENTIFIERS!
-- We do NOT store REFERENCES to child chunks, we only store their INDICES!
local NamedArea = {
    name = nil,
    colour = nil,
    height = nil,
    floor_block = nil,
    chunks = nil
}
function NamedArea:new(name, colour, height, floor_block)
    if height == nil or height < 0 or height > 255 then
        print(comms.robot_send("error", "NamedArea:new -- invalid height"))
        return nil
    end
    --[[if MapColours[colour] == nil then
        print(comms.robot_send("error", "NamedArea:new -- inavlid colour"))
        return nil
    end--]]

    local new = deep_copy.copy(self, pairs)
    new.name = name
    new.colour = colour
    new.height = height
    new.floor_block = floor_block
    new.chunks = {}
    return new
end
function NamedArea:addChunkToSelf(what_chunk)
    for _, o_chunk in ipairs(self.chunks) do -- checks if chunk is already added
        if what_chunk[1] == o_chunk[1] and what_chunk[2] == o_chunk[2] then return end
    end

    table.insert(self.chunks, what_chunk)
end


-- THIS IS A GREAT READ: https://poga.github.io/lua53-notes/table.html,
-- I'll probably maximize array access through pre-allocation write-to-disc de-allocation

-- Speaking of reading: https://web.engr.oregonstate.edu/~erwig/papers/DeclScripting_SLE09.pdf is this peak chat?
-- and smart accessing of disc and remote stored data eventually, so I'll not use string indeces.
-- is_home basically means: is a part of the base
local UnderlyingChunk = {
    x = 0,
    z = 0,
    marks = nil,

    parent_area = nil,
    height_override = nil,
    meta_quads = nil,
    roads_cleared = false   -- this property and methods that mess with it will have to be changed when
                            -- multi-level areas become a thing, unless we simply "layer" MetaChunks
                            -- like cake, that might be the obvious thing
}

function UnderlyingChunk:new(x, z) -- lazy initialization :I (one day :) )
    local new = deep_copy.copy_table(self, pairs)
    new.x = x
    new.z = z
    return new
end

local MetaChunk = {
    chunk = nil
}

function MetaChunk:new(real_chunk)
    local new = deep_copy.copy_table(self, pairs)
    new.chunk = real_chunk
    return new
end

function MetaChunk:addMark(str)
    if self.chunk.marks == nil then self.chunk.marks = {} end
    if self:checkMarks(str) then return end

    table.insert(self.chunk.marks, str)
end

function MetaChunk:tryRemoveMark(str, ok_to_fail)
    if ok_to_fail == nil then ok_to_fail = false end
    local was_able_to_remove = false
    for index, mark in ipairs(self.chunk.marks) do
        if mark == str then
            self.chunk.marks[index] = nil
            was_able_to_remove = true
            break
        end
    end

    if not was_able_to_remove then
        if not ok_to_fail then
            print(comms.robot_send("warning", "Attempted to remove a mark that is not present: \"" .. str  .. "\""))
            return false
        end
    end
    return true
end

function MetaChunk:checkMarks(str)
    if self.chunk.marks == nil then return false end

    for _, mark in ipairs(self.chunk.marks) do
        if mark == str then
            return true
        end
    end
    return false
end

function MetaChunk:getName(what_quad)
    if self.chunk.meta_quads == nil then return nil end
    local quad_in_question = self.chunk.meta_quads[what_quad]
    if quad_in_question == nil or not quad_in_question:isInit() then return nil end
    return quad_in_question:getName()
end

function MetaChunk:getHeight()
    if self.chunk.height_override ~= nil then return self.chunk.height_override end
    if self.chunk.parent_area ~= nil then return self.chunk.parent_area.height end
    print(comms.robot_send("error", "MetaChunk:getHeight -- could not getHeight"))
    return nil
end

function MetaChunk:getBuildRef(what_quad)
    if self.chunk.meta_quads == nil then return nil end
    local quad_in_question = self.chunk.meta_quads[what_quad]
    if quad_in_question == nil or not quad_in_question:isInit() then return nil end
    return quad_in_question:getBuild()
end

function MetaChunk:setParent(what_parent, height_override)
    if height_override ~= nil then
        if height_override < 0 or height_override > 255 then
            print(comms.robot_send("error", "MetaChunk:addToParent -- invalid height_override"))
            return false
        end
        self.chunk.height_override = height_override
    end

    self.chunk.parent_area = what_parent
    return true
end

local function empty_quad_table()
    local quads = {MetaQuad:new(), MetaQuad:new(), MetaQuad:new(), MetaQuad:new()}
    return quads
end

function MetaChunk:getDoors(what_quad_num)
    if not self:quadChecks(what_quad_num, "getDoors") then return nil end
    local this_quad = self.chunk.meta_quads[what_quad_num]
    local doors = this_quad:getDoors()
    --if doors == nil then print(comms.robot_send("error", "MetaChunk:getDoors, got nil doors xO")) end
    return doors
end

function MetaChunk:quadChecks(what_quad_num, from_where)
    if what_quad_num > 4 or what_quad_num < 1 then
        print(comms.robot_send("error", "-- " .. from_where .. " --" .. "specified invalid quad_num: \"" .. tostring(what_quad_num) .. "\""))
        return false
    end
    if self.chunk.meta_quads == nil then self.chunk.meta_quads = empty_quad_table() end
    return true
end

function MetaChunk:addQuadCommon(what_quad_num, what_build, what_chunk)
    local this_quad = self.chunk.meta_quads[what_quad_num]
    local result = this_quad:setQuad(what_quad_num, what_build, what_chunk)

    if result == true then
        return true
    end
    print(comms.robot_send("error", "couldn't add build to quad"))
    -- TODO if this happens reset the chunk?
    return false
end

function MetaChunk:addQuad(what_quad_num, what_build, what_chunk)
    if not self:quadChecks(what_quad_num, "addQuad") then return false end
    if self.chunk.meta_quads[what_quad_num]:getNum() ~= 0 then
        print(comms.robot_send("error", "trying to overwrite already defined quad, without specifing desire to overwrite!"))
    end
    return self:addQuadCommon(what_quad_num, what_build, what_chunk)
end

function MetaChunk:replaceQuad(what_quad_num, what_build, what_chunk)
    if not self:quadChecks(what_quad_num, "replaceQuad") then return false end
    local this_quad = self.chunk.meta_quads[what_quad_num]
    if this_quad:getNum() ~= 0 and this_quad:isBuilt() then
        print(comms.robot_send("error", "trying to overwrite already BUILT quad, UNIMPLEMENTED!"))
    end
    return self:addQuadCommon(what_quad_num, what_build, what_chunk)
end

function MetaChunk:setupBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "setupBuild") then return false end

    local this_quad = self.chunk.meta_quads[what_quad_num]
    if this_quad:isBuilt() then
        print(comms.robot_send("error", "cannot prepare to build what is already built!"))
        return false
    end

    local chunk_height = self:getHeight()
    return this_quad:setupBuild(chunk_height)
end

function MetaChunk:doBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "doBuild") then return false end

    local this_quad = self.chunk.meta_quads[what_quad_num]
    if this_quad:isBuilt() then
        print(comms.robot_send("error", "cannot build what is already built!"))
        return false
    end
    return this_quad:doBuild()
end

function MetaChunk:finalizeBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "finalizeBuild") then return false end
    local this_quad = self.chunk.meta_quads[what_quad_num]
    this_quad:finalizeBuild()
    return true
end

-->>-----------------------------------<<--

local known_buildings = {}
function known_buildings:insert(name, build_ref)
    if self[name] == nil then self[name] = {} end
    local size = #self[name]
    self[name][size + 1] = build_ref
end

module.all_builds = known_buildings

-->>-----------------------------------<<--

local default_map_size = 31 -- generate 31x31 square of chunks
local current_map_size = default_map_size
local map_obj = {}
local map_obj_offsets = {1,1}   -- offsets logical 0,0 in the array in order to translate it to "real" 0,0
                                -- what this means is that if set the "origin", the "map centre" of the robot
                                -- à posteriori then we don't need to re-alloc the array
                                -- 1,1 is default since array acess in lua is [1][1] rather than [0][0]
                                -- so "real" [0][0] is logical [1][1]

if default_map_size % 2 == 0 then
    error(comms.robot_send("fatal", "default_map_size is divisble by 2"))
end

function module.gen_map_obj(offset)
    if map_obj[1] ~= nil then
        print(comms.robot_send("error", "map_obj already generated"))
        return false
    end

    map_obj_offsets = offset

    -- (necessary offset so that we can load negative numbers)
    local negative_offset = math.floor(current_map_size / 2)
    map_obj_offsets[1] = map_obj_offsets[1] + negative_offset
    map_obj_offsets[2] = map_obj_offsets[2] + negative_offset

    local size = default_map_size
    for x = 1, size, 1 do
        map_obj[x] = {}
        local real_x = x - map_obj_offsets[1];
        for z = 1, size, 1 do
            local real_z = z - map_obj_offsets[2];
            map_obj[x][z] = UnderlyingChunk:new(real_x, real_z)
        end
    end
    return true
end

local function chunk_is_unique(chunk)
    return  chunk.marks ~= nil or chunk.parent_area ~= nil
            or chunk.meta_quads ~= nil or chunk.height_override ~= nil or chunk.roads_cleared ~= false
end

local function translate_chunk(chunk, a_table, build_table, chunks_proper)
    ------- META QUADS --------
    if chunk.meta_quads ~= nil then
        for _, quad in ipairs(chunk.meta_quads) do
            if not quad:isBuilt() then goto continue end
            local sub_table = {
                chunk.parent_area.name,
                quad:getName(),
                math.floor(chunk.x),
                math.floor(chunk.z),
                quad:getNum()
            }

            table.insert(build_table, sub_table)
            ::continue::
        end
    end

    ----- CHUNKS PROPER ------
    local sub_table = {
        math.floor(chunk.x),
        math.floor(chunk.z),
        chunk.marks,
        chunk.height_override,
        chunk.roads_cleared,
    }
    if chunk.parent_area ~= nil then
        sub_table[6] = chunk.parent_area.name
    end

    table.insert(chunks_proper, sub_table)
end

-- we need data to recreate builds, to recreate areas, and to recreate marks,
function module.get_data()
    local a_table = deep_copy.copy_no_functions(areas_table)

    -- MetaQuads are never stored directly, instead they are stored as an order to pretend_build
    -- something at the given MetaQuad, and by something let us say: the building that IS THERE!
    -- bd_sub_table = {area_name, build_name, x, z, what_quad}
    local build_table = {}

    -- chunk_proper_sub_table = {x, z, {[marks]}, height_override, roads_cleared}
    local chunks_proper = {}

    for _, line in ipairs(map_obj) do
        for _, chunk in ipairs(line) do
            if not chunk_is_unique(chunk) then goto continue end
            -- tbls are being passed by ref
            translate_chunk(chunk, a_table, build_table, chunks_proper)
            ::continue::
        end
    end

    local big_table = {
        a_table,
        chunks_proper,
        build_table,
    }
    return big_table
end

-- TODO, change the way chunks are generated so that they are generated only after attempted
-- reinstantiation so that we might provide a different chunk offset, do soon!
function module.re_instantiate(big_table)
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
        print(comms.robot_send("error", "ungenerated chunk"))
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
    if map_chunk == nil then return -1 end

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

function module.find_quad(what_chunk, door_info)
    local quads = module.get_chunk(what_chunk).chunk.meta_quads
    local cur_quad = nil
    for _, quad in ipairs(quads) do
        -- if not quad:isBuilt() then goto continue end
        local doors = quad:getDoors()
        if doors == door_info then -- checks if references match
            cur_quad = quad
            break
        end

        --[[for _, door in ipairs(doors) do
            if door == door_info then -- checks if references match
                cur_quad = quad
                break
            end
        end --]]

        ::continue::
    end
    return cur_quad
end

function module.find_build(what_chunk, door_info)
    local cur_quad = module.find_quad(what_chunk, door_info)
    if cur_quad ~= nil then
        return cur_quad:getBuild()
    end
    return nil
end


function module.get_buildings(name)
    return known_buildings[name]
end

function module.get_buildings_num(name)
    if known_buildings[name] == nil then return 0 end

    return #known_buildings[name]
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

-- lock needs to be released only when building is done and registered
-- id allows us to know "who" we are, and it is generated by iteractive
function module.start_auto_build(ab_metainfo)
    local what_chunk, what_quad, primitive_name, what_step, lock, id, prio = ab_metainfo:unpack()

    -- if what_step == 0 then what_chunk is simply an offset, else it is an absolute coordinate
    -- the base coordinate to add to the offset is given by the user at a later time

    -- Temporary value?
    local old_prio = prio

    if what_step <= 0 then
        -- if this crashes add the to_string's
        local hr_table = {
            "offset_chunk:", what_chunk[1], ", ", what_chunk[2], " || ", "quad: ", what_quad, " || \n",
            "name: ", primitive_name, " || ", "waiting for origin_chunk_coords"
        }
        local human_readable = table.concat(hr_table)
        local id = interactive.add("auto_build0", human_readable) -- luacheck: ignore

        what_step = 1 -- updates what_step here
        ab_metainfo.step = what_step
        ab_metainfo.id = id

        prio = -2
        -- old return
    elseif what_step == 1 then
        prio = -2
        local data = interactive.get_data_table(id)
        if data == nil then
            goto fall
            -- old return
        end
        what_chunk[1] = what_chunk[1] + data[1]
        what_chunk[2] = what_chunk[2] + data[2] -- no need to alter ab_metainfo since what_chunk is a ref
        -- ab_metainfo[1] = what_chunk -> &a = &a -> useless operation

        interactive.del_element(id) -- remove current interactive "task", in a real language data would now be a null ptr

        what_step = 2
        ab_metainfo.step = what_step

        prio = old_prio
        -- old return
    elseif what_step == 2 then
        if areas_table:isInArea(what_chunk) then
            what_step = 4
            ab_metainfo.step = what_step
            goto fall
            -- old return
        end -- else iteractive mode_it again

        local hr_table = {
            "abs_chunk:", what_chunk[1], ", ", what_chunk[2], " || ", "quad: ", what_quad, " || \n",
            "name: ", primitive_name, " || ", "waiting for area_name and optional height override"
        }
        local human_readable = table.concat(hr_table)
        local id = interactive.add("auto_build1", human_readable) -- luacheck: ignore

        what_step = 3
        ab_metainfo.step = what_step
        ab_metainfo.id = id

        prio = -2
        -- old return
    elseif what_step == 3 then
        prio = -2
        local data = interactive.get_data_table(id)
        if data == nil then
            goto fall
            -- old return
        end
        local area_name = data[1]
        local area = areas_table:getArea(area_name)
        if area == nil then
            print(comms.robot_send("error", "what are you? Stupid? start_auto_build, what_step == 3 | area doesn't exist stupid"))
            interactive.del_data_table(id) -- resets table
            goto fall
            -- old return
        end

        local height_override = data[2] -- it's ok if it's nil
        if not module.chunk_set_parent(what_chunk, area, height_override) then -- the important thing of this step
            print(comms.robot_send("error", "There was an error executing chunk_set_parent"))
        end
        interactive.del_element(id)

        what_step = 4
        ab_metainfo.step = what_step

        prio = old_prio
        -- old return
    elseif what_step == 4 then
        local chunk_ref = module.chunk_exists(what_chunk)
        if chunk_ref.chunk.roads_cleared == false then
            local self_table = {prio, "start_auto_build", ab_metainfo}
            local build_height = module.get_height(what_chunk)
            local local_instructions = BuildInstruction:roadBuild(what_chunk, build_height)

            return {80, "navigate_rel", "road_build", local_instructions, self_table}
        end

        local result = module.add_quad(what_chunk, what_quad, primitive_name)
        if not result then
            error(comms.robot_send("fatal", "start_auto_build, step == 4 | TODO - make this thing failable without fatality :)"))
        end

        what_step = 5
        ab_metainfo.step = what_step
        -- old return
    elseif what_step == 5 then
        local result = module.setup_build(what_chunk, what_quad)
        if not result then
            print(comms.robot_send("error", "start_auto_build, step == 5 | TODO - idem :)"))
            lock[1] = 0
            return nil
        end

        what_step = 6
        ab_metainfo.step = what_step
        -- old return
    elseif what_step == -100 then -- quite an important TODO if I say so myself
        -- Do things like filling in the floor so monsters don't spawn etc. !
        module.clear_quad()
        error("TODO")

        what_step = 7
        ab_metainfo.step = what_step
    elseif what_step == 6 then
        local result, status, instruction = module.do_build(what_chunk, what_quad)
        if not result then error(comms.robot_send("fatal", "start_auto_build, step == 6")) end
        if status == "done" then
            lock[1] = 0 -- VERY IMPORTANT, unlocking the building constraint
            return nil -- I think we return nil?
        end

        local door_info = get_door_info(what_chunk, what_quad)
        instruction:addDoors(door_info)
        instruction:addChunkCoords(what_chunk)
        instruction.ab_meta_info_ref = ab_metainfo -- wowzers

        local self_table = {prio, "start_auto_build", ab_metainfo}

        if status == "continue" then
            return {80, "navigate_rel", "and_build", instruction, self_table}
        else error(comms.robot_send("fatal", "lol, how?")) end
    end

    ::fall::

    -- let this fall through if this is what we want to return, most of the time this is what we want to return
    return {prio, "start_auto_build", ab_metainfo}
end

-- temp
module.create_named_area("home", "green", 69, "dirt")
local what_chunk = {-2,0}
module.gen_map_obj({1,1})
module.get_chunk(what_chunk).chunk.roads_cleared = true

-- I think this is being erased by the loading process :P
what_chunk[2] = -1
module.get_chunk(what_chunk).chunk.roads_cleared = true

-- more temp
--[[
module.create_named_area("gather", "green", 69, "dirt")
local area = areas_table:getArea("gather")
area:addChunkToSelf(what_chunk)
module.chunk_set_parent(what_chunk, area, nil)
--]]

-- x and z are still fine here, even after assigning to area

return module
