local module = {}

------- Sys Requires -------
--local io = require("io")
local serialize = require("serialization")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local interactive = require("interactive")
-- YOU CANNOT IMPORT EVAL.NAVIGATE, IT BECOMES CIRCULAR YOU DUFUS
--local eval_nav = require("eval.navigate")

local MetaQuad = require("nav_module.MetaQuad")
local BuildInstruction = require("build.MetaBuild.BuildInstruction")


local areas_table = {}
function areas_table:addArea(new_area)
    table.insert(self, new_area)
end

function areas_table:isInArea(what_chunk) -- luacheck: ignore
    for _, area in ipairs(areas_table) do
        for _, area_chunk in ipairs(area.chunks) do
            if what_chunk[1] == area_chunk[1] and what_chunk[2] == area_chunk[2] then
                return true
            end
        end
    end
    return false
end
function areas_table:getArea(name) -- luacheck: ignore
    for _, area in ipairs(areas_table) do
        if area.name == name then return area end
    end
    return nil
end

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
    table.insert(self.chunks, what_chunk)
end


-- THIS IS A GREAT READ: https://poga.github.io/lua53-notes/table.html,
-- I'll probably maximize array access through pre-allocation write-to-disc de-allocation

-- Speaking of reading: https://web.engr.oregonstate.edu/~erwig/papers/DeclScripting_SLE09.pdf is this peak chat?
-- and smart accessing of disc and remote stored data eventually, so I'll not use string indeces.
-- is_home basically means: is a part of the base
local MetaChunk = {
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
function MetaChunk:new(x, z) -- lazy initialization :I (one day :) )
    local new = deep_copy.copy_table(self, pairs)
    new.x = x
    new.z = z
    return new
end

function MetaChunk:addMark(str)
    if self.marks == nil then self.marks = {} end
    if self:checkMarks(str) then return end 

    table.insert(self.marks, str)
end

function MetaChunk:checkMarks(str)
    if self.marks == nil then return false end

    for _, mark in ipairs(self.marks) do
        if mark == str then
            return true
        end
    end
    return false
end

function MetaChunk:getName(what_quad)
    if self.meta_quads == nil then return nil end
    local quad_in_question = self.meta_quads[what_quad]
    if quad_in_question == nil or not quad_in_question:isInit() then return nil end
    return quad_in_question:getName()
end

function MetaChunk:getHeight()
    if self.height_override ~= nil then return self.height_override end
    if self.parent_area ~= nil then return self.parent_area.height end
    print(comms.robot_send("error", "MetaChunk:getHeight -- could not getHeight"))
    return nil
end

function MetaChunk:getBuildRef(what_quad)
    if self.meta_quads == nil then return nil end
    local quad_in_question = self.meta_quads[what_quad]
    if quad_in_question == nil or not quad_in_question:isInit() then return nil end
    return quad_in_question:getBuild()
end

function MetaChunk:setParent(what_parent, height_override)
    if height_override ~= nil then
        if height_override < 0 or height_override > 255 then
            print(comms.robot_send("error", "MetaChunk:addToParent -- invalid height_override"))
            return false
        end
        self.height_override = height_override
    end

    self.parent_area = what_parent
    return true
end

local function empty_quad_table()
    local quads = {MetaQuad:new(), MetaQuad:new(), MetaQuad:new(), MetaQuad:new()}
    return quads
end

function MetaChunk:getDoors(what_quad_num)
    if not self:quadChecks(what_quad_num, "getDoors") then return nil end
    local this_quad = self.meta_quads[what_quad_num]
    local doors = this_quad:getDoors()
    --if doors == nil then print(comms.robot_send("error", "MetaChunk:getDoors, got nil doors xO")) end
    return doors
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
    return self:addQuadCommon(what_quad_num, what_build)
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
    if this_quad:isBuilt() then
        print(comms.robot_send("error", "cannot prepare to build what is already built!"))
        return false
    end
    return this_quad:setupBuild(self:getHeight())
end

function MetaChunk:doBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "doBuild") then return false end

    local this_quad = self.meta_quads[what_quad_num]
    if this_quad:isBuilt() then
        print(comms.robot_send("error", "cannot build what is already built!"))
        return false
    end
    return this_quad:doBuild()
end

function MetaChunk:finalizeBuild(what_quad_num)
    if not self:quadChecks(what_quad_num, "finalizeBuild") then return false end
    local this_quad = self.meta_quads[what_quad_num]
    this_quad:finalizeBuild()
end

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

local known_buildings = {}
function known_buildings:insert(name, build_ref)
    if self[name] == nil then self[name] = {} end
    local size = #self[name]
    self[name][size + 1] = build_ref
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
        for z = 1, size, 1 do
            local real_x = x - map_obj_offsets[1];
            local real_z = z - map_obj_offsets[2];
            map_obj[x][z] = MetaChunk:new(real_x, real_z)
        end
    end
    return true
end

local function chunk_exists(what_chunk)
    local x = what_chunk[1] + map_obj_offsets[1];
    local z = what_chunk[2] + map_obj_offsets[2];

    if map_obj[x] == nil or map_obj[x][z] == nil then
        print(comms.robot_send("error", "ungenerated chunk"))
        return nil
    end
    return map_obj[x][z]
end

local function get_door_info(what_chunk, what_quad)
    local map_chunk = chunk_exists(what_chunk)
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

function module.chunk_set_parent(what_chunk, what_area, height_override)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:setParent(what_area, height_override)
end

function module.get_height(what_chunk)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return -1 end

    return map_chunk:getHeight()
end

function module.get_chunk(what_chunk) -- Evil function!
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return -1 end

    return map_chunk
end

function module.add_quad(what_chunk, what_quad, primitive_name)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:addQuad(what_quad, primitive_name)
end

function module.setup_build(what_chunk, what_quad)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:setupBuild(what_quad) -- pay attention to what are we returning
end

function module.do_build(what_chunk, what_quad)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    local result_bool, result_string, coords, symbol = map_chunk:doBuild(what_quad) -- pay attention to what are we returning
    if result_string == "done" then
        local primitive_name = map_chunk:getName(what_quad)
        if primitive_name == nil then error(comms.robot_send("fatal", "Impossible state, map_obj.do_build")) end
        known_buildings:insert(primitive_name, map_chunk:getBuildRef())

        map_chunk:finalizeBuild(what_quad)
    end

    return result_bool, result_string, coords, symbol
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


-- lock needs to be released only when building is done and registered
-- id allows us to know "who" we are, and it is generated by iteractive
function module.start_auto_build(what_chunk, what_quad, primitive_name, what_step, lock, id, prio, return_table)
    -- if what_step == 0 then what_chunk is simply an offset, else it is an absolute coordinate
    -- the base coordinate to add to the offset is given by the user at a later time

    -- Temporary value?
    local old_prio = prio
    DOOR_MOVE_DONE = false -- SO STUPID, CHANGE THIS WHEN YOUR HEADACHE STOPS
    if what_step <= 0 then
        -- if this crashes add the to_string's
        local hr_table = {
            "offset_chunk:", what_chunk[1], ", ", what_chunk[2], " || ", "quad: ", what_quad, " || \n",
            "name: ", primitive_name, " || ", "waiting for origin_chunk_coords"
        }
        local human_readable = table.concat(hr_table)
        local id = interactive.add("auto_build0", human_readable) -- luacheck: ignore

        what_step = 1 -- updates what_step here
        return_table[4] = what_step
        return_table[6] = id

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
        what_chunk[2] = what_chunk[2] + data[2] -- no need to alter return_table since what_chunk is a ref
        -- return_table[1] = what_chunk -> &a = &a -> useless operation

        interactive.del_element(id) -- remove current interactive "task", in a real language data would now be a null ptr

        what_step = 2
        return_table[4] = what_step

        prio = old_prio
        -- old return
    elseif what_step == 2 then
        if areas_table:isInArea(what_chunk) then
            what_step = 4
            return_table[4] = what_step
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
        return_table[4] = what_step
        return_table[6] = id

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
        area:addChunkToSelf(what_chunk)

        local height_override = data[2] -- it's ok if it's nil
        module.chunk_set_parent(what_chunk, area, height_override) -- the important thing of this step
        interactive.del_element(id)

        what_step = 4
        return_table[4] = what_step

        prio = old_prio
        -- old return
    elseif what_step == 4 then
        local chunk_ref = chunk_exists(what_chunk)
        if chunk_ref.roads_cleared == false then
            local self_table = {prio, "start_auto_build", table.unpack(return_table)}
            local build_height = module.get_height(what_chunk)
            local local_instructions = BuildInstruction:roadBuild(what_chunk, build_height)

            return {80, "navigate_rel", "road_build", local_instructions, self_table}
        end

        local result = module.add_quad(what_chunk, what_quad, primitive_name)
        if not result then
            error(comms.robot_send("fatal", "start_auto_build, step == 4 | TODO - make this thing failable without fatality :)"))
        end

        what_step = 5
        return_table[4] = what_step
        -- old return
    elseif what_step == 5 then
        local result = module.setup_build(what_chunk, what_quad)
        if not result then
            error(comms.robot_send("fatal", "start_auto_build, step == 5 | TODO - idem :)"))
        end

        what_step = 6
        return_table[4] = what_step
        -- old return
    elseif what_step == -100 then
        module.clear_quad()
        error("TODO")

        what_step = 7
        return_table[4] = what_step
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

        local self_table = {prio, "start_auto_build", table.unpack(return_table)}

        if status == "continue" then
            return {80, "navigate_rel", "and_build", instruction, self_table}
        else error(comms.robot_send("fatal", "lol, how?")) end
    end

    ::fall::

    -- let this fall through if this is what we want to return, most of the time this is what we want to return
    return {prio, "start_auto_build", table.unpack(return_table)}
end

-- temp
--module.create_named_area("home", "green", 69, "dirt")
local what_chunk = {-2,0}
module.gen_map_obj({1,1})
module.get_chunk(what_chunk).roads_cleared = true

-- more temp
module.create_named_area("gather", "green", 69, "dirt")
local area = areas_table:getArea("gather")
area:addChunkToSelf(what_chunk)
module.chunk_set_parent(what_chunk, area, nil)

return module
