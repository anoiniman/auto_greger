-- luacheck: globals DO_DEBUG_PRINT
local deep_copy = require("deep_copy")
local comms = require("comms")

local serialize = require("serialization")

local eval_build = require("eval.build")
local map_obj = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")
local MetaBuild = require("build.MetaBuild")

local ABMetaInfo = require("eval.AutoBuildMetaInfo")


-- chunk_x_offset and chunk_z_offset btw
local StructureDeclaration = {name = nil, x_offset = 0, z_offset = 0, quadrant = -1}
function StructureDeclaration:new(structure_name, x_offset, z_offset, quadrant)
    local new = deep_copy.copy(self, pairs)
    new.name = structure_name
    new.x_offset = x_offset
    new.z_offset = z_offset
    new.quadrant = quadrant
    return new
end

-- If chunk_centre is left nil, then the script will be in interactive mode, probabilly
-- this will be the default, but who the fuck knows [tbh, I don't know if I'll
-- ever define a chunk centre, so maybe this is a bit soopid

-- MetaStructures will still only be initialised lazily, because that is the best
-- and esiest way of doing this imo
-- Lock needs to be a table so that it is passed by reference
local BuildingConstraint = {structures = nil, chunk_centre = nil, lock = {0}} -- 0 means unlock
function BuildingConstraint:new(structures, chunk_centre)
    local new = deep_copy.copy(self, pairs)
    new.structures = structures
    new.chunk_centre = chunk_centre or nil
    return new
end

-- Because of the way buildings are built right now (this is to say, because they are built one-shot)
-- It makes little sense to interpret a differnace between a 2 and a 3
function BuildingConstraint:check(do_once)
    if self.lock[1] == 1 or self.lock[1] == 4 then
        return nil, nil -- Hold It
    end

    if self.lock[1] == 2 then
        print(comms.robot_send("warning", "BuildingConstraint, unideomatic lock state (2)"))
        self.lock[1] = 3
        return 0, nil
    end
    if self.lock[1] == 3 then
        if do_once then return 0, nil end
        -- else
        self.lock[1] = 0 -- and continue
    end

    local heap = {}
    for index, structure in ipairs(self.structures) do
        local name = structure.name
        print(comms.robot_send("debug", "BuildingConstraint:check(), name: " .. name))
        print(comms.robot_send("debug", "BuildingConstraint:check(), index: " .. index))
        if heap[name] == nil then
            --local cur_buildings = map_obj.get_buildings(name) -- table
            print(comms.robot_send("debug", "BuildingConstraint:check(), heap[name] is nil"))
            local cur_buildings = map_obj.get_buildings_num(name) -- num
            if cur_buildings == 0 then return index, name end
            heap[name] = cur_buildings
        end

        if heap[name] <= 0 then -- we've run out of buildings, aka, we're below the target
            return index, name -- returns where we failed
        else
            heap[name] = heap[name] - 1
        end
    end

    return 0, nil -- check passed
end

function BuildingConstraint:decideToBuild(to_build)
    local tmp_build = MetaBuild:new()
    -- I don't think it'll be a big deal to recalculate this everytime, but let's see
    tmp_build:require(to_build.name)
    tmp_build:setupBuild(1, 1)

    local tmp_inv = tmp_build:createAndReturnLedger()

    print(comms.robot_send("debug", "decideToBuild temp:"))
    if DO_DEBUG_PRINT then tmp_inv:printObj() end

    local internal = inv.virtual_inventory

    local diff = internal:compareWithLedger(tmp_inv)
    -- local serial = serialize.serialize(diff, true)
    -- print(comms.robot_send("debug", serial)

    if diff == nil or #diff == 0 then return 1 end -- aka return a no-go-signal by default

    -- element.lable, element.name
    for _, element in ipairs(diff) do
        if element.diff < 0 and element.lable ~= "air" then
            return 1, element, math.abs(element.diff)
        end
    end

    return 0
end

function BuildingConstraint:step(index, name, priority) -- returns command to be evaled
    local structure_to_build = nil
    local occurence = 0
    for _, structure in ipairs(self.structures) do
        print(comms.robot_send("debug", "BC:step(), iterated once"))
        if structure.name == name then
            print(comms.robot_send("debug", "BC:step(), name is equal once"))
            occurence = occurence + 1
        end
        if occurence == index then
            print(comms.robot_send("debug", "BC:step(), indexes match"))
            structure_to_build = structure
            break
        end
    end

    if structure_to_build == nil then
        error(comms.robot_send("fatal", "impossible state BuildingConstraint:step()"))
    end
    local to_build = structure_to_build
    local what_to_do, element, missing_quanitty = self:decideToBuild(to_build)

    if what_to_do == 0 then
        return self:doBuild(name, priority, to_build)
    elseif what_to_do == 1 then
        -- element, "try_recipe" -- aka try to find (and follow) the recipe necessary for the thing that we're missing rn

        -- since element already contains fields = "lable" and "name", why not just send it over?
        -- Instead of: \return {lable = element.lable, name = element.name}, "try_recipe"\
        return element, {"try_recipe", missing_quanitty}
    end
end

function BuildingConstraint:doBuild(name, priority, to_build)
    --luacheck: ignore
    local step = 0 -- 0 is interactive mode
    local what_chunk = {} -- what_chunk isn't dropped because of GC I think
    if self.chunk_centre ~= nil then
        --what_chunk = {}
        what_chunk[1] = self.chunk_centre[1] + to_build.x_offset
        what_chunk[2] = self.chunk_centre[2] + to_build.z_offset
        step = 2 -- 2 means that what_chunk we want to build in is already set by definition
    else
        what_chunk[1] = to_build.x_offset
        what_chunk[2] = to_build.z_offset
        step = 0
    end

    self.lock[1] = 1 -- signals that constraint is in the middle of processing and to not do more requests
    local id = -1
    local command = eval_build.start_auto_build
    -- lock will not be released unless building fails in a specific manner, but it's still worth
    -- for it to be around, because, hey, that might happen, and we might want to unluck the
    -- build and "start over", aka, tell the system it is ok to re-try
    local ab_meta_info = ABMetaInfo:new(what_chunk, to_build.quadrant, name, step, self.lock, id, priority)

    -- TODO define prio dynamically somehow
    return {priority, command, ab_meta_info} -- the common format, you know it welll
end

return {StructureDeclaration, BuildingConstraint}
