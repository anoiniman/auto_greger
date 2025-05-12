local module = {}

------- Sys Requires -------
local io = require("io")
local serialize = require("serialization")

------- Own Requires -------
local comms = require("comms")
local deep_copy = require("deep_copy")

local interactive = require("interactive")

local interface = require("nav_module.nav_interface")
local chunk_move = require("nav_module.chunk_move")

local MetaBuild = require("build.MetaBuild")
local MetaDoorInfo = require("build.MetaBuild.MetaDoorInfo")
local MetaQuad = require("nav_module.MetaQuad")


local areas_table = {}

local NamedArea = {
    name = nil,
    colour = nil,
    height = nil,
    floor_block = nil
}
function NamedArea:new(name, colour, height, floor_block)
    if height == nil or height < 0 or height > 255 then
        print(comms.robot_send("error", "NamedRect:new -- invalid height")) 
        return nil
    end
    if MapColours[colour] == nil then
        print(comms.robot_send("error", "nameRect:new -- inavlid colour"))
        return nil
    end

    local new = deep_copy.copy(self, pairs)
    new.name = name
    new.colour = colour
    new.height = height
    new.floor_block = floor_block
    return new
end


-- THIS IS A GREAT READ: https://poga.github.io/lua53-notes/table.html, I'll probably maximize array access through pre-allocation write-to-disc de-allocation
-- Speaking of reading: https://web.engr.oregonstate.edu/~erwig/papers/DeclScripting_SLE09.pdf is this peak chat?
-- and smart accessing of disc and remote stored data eventually, so I'll not use string indeces.
-- is_home basically means: is a part of the base
local MetaChunk = {
    parent_area = nil,
    height_override = nil,
    meta_quads = nil
}
function MetaChunk:new() -- lazy initialization :I
    return deep_copy.copy_table(self, pairs)
end

function MetaChunk:getHeight()
    if self.height_override ~= nil then return self.height_override end
    if parent_rect ~= nil then return parent_rect.height end
    print(comms.robot_send("error", "MetaChunk:getHeight -- could not getHeight"))
    return nil
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
    self:addQuadCommon(what_quad_num, what_build)
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
    if not self:quadChecks(what_quad_num, "setupBuild") then return false end

    local this_quad = self.meta_quads[what_quad_num]
    if this_quad:isBuilt() then
        print(comms.robot_send("error", "cannot build what is already built!"))
        return false
    end
    return this_quad:doBuild()
end

-->>-----------------------------------<<--

local current_map_size = 30
local default_map_size = 30 -- generate 30x30 square of chunks
local map_obj = {}
local map_obj_offsets = {1,1}   -- offsets logical 0,0 in the array in order to translate it to "real" 0,0
                                -- what this means is that if set the "origin", the "map centre" of the robot
                                -- à posteriori then we don't need to re-alloc the array
                                -- 1,1 is default since array acess in lua is [1][1] rather than [0][0]
                                -- so "real" [0][0] is logical [1][1]

function module.gen_map_obj(offset)
    map_obj_offsets = offset
    if map_obj[1] ~= nil then
        print(comms.robot_send("error", "map_obj already generated"))
        return false
    end

    local size = default_map_size 
    for x = 1, size, 1 do
        map_obj[x] = {}
        for z = 1, size, 1 do
            map_obj[x][z] = MetaChunk:new()
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
    table.insert(areas_table, new_area)
    return true
end

function module.chunk_set_parent(what_chunk, as_what, height_override)
    local map_chunk = chunk_exists(what_chunk)
    if map_chunk == nil then return false end

    return map_chunk:setParent(as_what, height_override)
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

    return map_chunk:doBuild(what_quad) -- pay attention to what are we returning
end

-- TODO register completed buildings, base_wide? In someway that our reasoning scripts can acess tehm
-- lock needs to be released only when building is done and registered
-- id allows us to know "who" we are, and it is generated by iteractive
function module.start_auto_build(what_chunk, what_quad, primitive_name, what_step, lock, id, return_table)
    -- if what_step == 0 then what_chunk is simply an offset, else it is an absolute coordinate
    -- the base coordinate to add to the offset is given by the user at a later time

    -- TODO this is all still to do
    if what_step <= 0 then
        -- if this crashes add the to_string's
        local hr_table = {"offset_chunk:", what_chunk[1], ", ", what_chunk[2], " || ", "quad: ", what_quad, " || ", primitive_name}
        local human_readable = table.concat(hr_table)
        interactive.add("auto_build", human_readable)

        what_step = 1 -- updates what_step here
        return prio, module.start_auto_build, return_table
    elseif what_step == 1 then
        local data = interactive.get_data_table(id)
        if data == nil then
            return
        end
    end

    print(comms.robot_send("error", "start_auto_build fell through xO"))
    return nil
end

return module
