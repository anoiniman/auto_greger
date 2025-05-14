---- Global Objects ----
local map_obj = require("nav_module.map_obj")
local inv_obj = require("inventory.inv_obj")
-- Mind the circular dependencies with care
local eval_build = require("eval.build")
---- Shared ----
local comms = require("comms")
local deep_copy = require("deep_copy")
local prio_insert = require("prio_insert")

---- Other ----
local MetaRecipe = require("reasoning.MetaRecipe")

-- Have name param as well?
-- Add to unlocking behaviour automatic unloading behaviour for scripts that deprecate
-- with the unlocking og the condition I guess
-- Maybe add "current_goal" param, so we don't have to search for best goal everytime idk
local MetaScript = {desc = nil, goals = {}, posterior = nil, p_unlock_condition = nil}
function MetaScript:new() return deep_copy.copy(self, pairs) end
function MetaScript:addGoal(goal)
    if goal == nil or goal.constraint == nil then
        error(comms.robot_send("fatal", "MetaScript:addGoal, attempted to add nil or bad goal :/"))
    end
    prio_insert.named_insert(self.goals, goal)
end

-- check if posterior script file can be unlocked
function MetaScript:unlockPosterior()
    if self.posterior == nil then return nil end
    -- TODO
end

function MetaScript:findBestGoal()
    for index = #self.goals, 1, -1 do -- Reverse order so it goes from highest prio to lowest
        local goal = self.goals[index] 
        if goal:depSatisfied() then
            local inner_index, name = goal:selfSatisfied()
            if inner_index ~= 0 then
                return goal, inner_index, name
            end
        end
    end
    return nil, nil, nil
end

function MetaScript:step() -- most important function does everything, I think
    self:unlockPosterior()
    local best_goal, index, name = self:findBestGoal()
    if best_goal == nil then
        print(comms.robot_send("error", "MetaScript:step() -- couldn't find best goal"))
        return "fail", nil
    end

    local result = best_goal:step(index, name)
    if result == nil and index == 1 then -- activate power saving, or change active scripts
        print(comms.robot_send("warning", "MetaScript:step() -- ran out of goals!"))
        return "end", nil
    end

    print(comms.robot_send("info", "MetaScript:step() -- selected a command to to execute))
    return "continue", result
end

-- Possible filters = "strict", "loose", <!"gt_ore"!> (maybe not anymore)
-- perfect string match, imperfect match, item_name is actually a table
local ItemConstraint = {item_name = nil, total_count = nil, filter = nil}
function ItemConstraint:new(item_name, total_count, filter) 
    local new = deep_copy.copy(self, pairs)
    new.item_name = item_name
    new.total_count = total_count
    new.filter = filter
end
function ItemConstraint:check()
    error(comms.robot_send("fatal", "ItemConstraint:check() TODO!"))
end

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
function BuildingConstraint:check()
    -- early return
    if self.lock[1] ~= 0 then return 0, nil end

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
            if structure.lock[1] == 0 then -- if we've NOT already started working on this
                return index, name -- returns where we failed
            end -- else we want to fall through
        else
            heap[name] = heap[name] - 1
        end
    end

    return 0, nil -- check passed
end

function BuildingConstraint:step(index, name) -- returns command to be evaled
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

    local step_num = 0 -- 0 is interactive mode
    local what_chunk = {} -- what_chunk isn't dropped because of GC I think
    if self.chunk_centre ~= nil then
        --what_chunk = {}
        what_chunk[1] = self.chunk_centre[1] + to_build.x_offset
        what_chunk[2] = self.chunk_centre[2] + to_build.z_offset
        step_num = 2 -- 2 means that what_chunk we want to build in is already set by definition
    else
        what_chunk[1] = to_build.x_offset
        what_chunk[2] = to_build.z_offset
        step_num = 0
    end

    self.lock[1] = 1 -- signals that constraint is in the middle of processing and to not do more requests
    local step = 0
    local id = -1
    local prio = 60
    local command = eval_build.start_auto_build
    -- lock will not be released unless building fails in a specific manner, but it's still worth
    -- for it to be around, because, hey, that might happen, and we might want to unluck the
    -- build and "start over", aka, tell the system it is ok to re-try
    local arguments = {what_chunk, to_build.quadrant, name, step, self.lock, id, prio}
    -- TODO define prio dynamically somehow
    return {prio, command, arguments} -- the common format, you know it welll
end

-- AKA, some sub-condition/way to alter the constraint condition, such that when met
-- the force or the constraint is slackened, might be unimplemented for now
local Slacking = {}

-- Constraints define what a goal should try and do to achieve it self,
-- they are recursable, so if you ask for item "x", and it needs building "y",
-- and building "y" needs item "z" it will do z->y->x successefully.....
-- hopefully
local Constraint = { const_type = nil, const_obj = nil, slacking = nil }
function Constraint:new() return deep_copy.copy(self, pairs) end
function Constraint:newItemConstraint(item_name, total_count, slacking)
    local new = self:new()
    new.const_type = "item"
    new.const_obj = ItemConstraint:new(item_name, total_count)
    new.slacking = slacking or nil
    return new
end

function Constraint:newBuildingConstraint(structures, centre, slacking)
    if structures == nil then
        print(comms.robot_send("error", "Constraint:newBC, structures is nil!"))
    elseif structures[1] == nil then
        print(comms.robot_send("debug", "Constraint:newBC, strucutres is not table of structures, attempting quick-fix!"))
        structures = {structures}
    end

    local new = self:new()
    new.const_type = "building"
    new.const_obj = BuildingConstraint:new(structures, centre)
    new.slacking = slacking or nil
    return new
end

function Constraint:check()
    local index, name = self.const_obj:check()
    if index ~= 0 then
        print(comms.robot_send("debug", "check for building of name: \"" .. name .. "\", index -- " .. index))
    end

    return index, name
end

function Constraint:step(index, name) -- useful only for Building Constraints
    if self.const_type ~= "building" then
        error(comms.robot_send("fatal", "Constraint:step used for non building"))
    end
    return self.const_obj:step(index, name)
end

-- goals depend on other goals (goals will have names, but not inside their struct definition)
-- in this way goals follow a sort of dependency acyclic (hopefully graph)
-- if a cyclic graph is created it probably is undefined behaviour so yeah
-- Dependencies tell us /when/ to do, constraints tell us /what/ to do
-- and recipes tell us /how/ to do, and priority in /what order/ when there are
-- multiple things to do
-- Of course in the case of buildings, the "how to do" is just a matter of reading
-- the requires schematic, so it is much more a case of extracting the required
-- user interaction from the user -- this is to say, the recipes are the buildings
-- themselves which are self-explaining, unlike items which require explanations
local Goal = {dependencies = nil, constraint = nil, recipe = nil, priority = 0}
function Goal:new(dependencies, constraint, recipe, priority) 
    local new = deep_copy.copy(self, pairs) 
    new.dependencies = dependencies or nil
    new.constraint = constraint or nil -- may resolve to nil or nil and that is hilarious
    new.recipe = recipe or nil
    new.priority = priority or 0
    return new
end

function Goal:selfSatisfied()
    return self.constraint:check()
end

function Goal:depSatisfied()
    if self.dependencies == nil then return true end
    for _, dep in ipairs(self.dependencies) do
        local index, _ = dep:selfSatisfied()
        if index ~= 0 then return false end
    end
    return true
end

function Goal:step(index, name)
    if self.recipe == nil then -- aka, is this a building constraint?
        return self.constraint:step(index, name)
    end
    self.recipe:step() -- ?
    return nil
end


local MSBuilder = {base_script = MetaScript:new()}
function MSBuilder:new() return deep_copy.copy(self, pairs) end
function MSBuilder:new_w_desc(desc)
    local new = self:new()
    new.base_script.desc = desc
    return new
end

function MSBuilder:addGoal(goal)
    self.base_script:addGoal(goal)
    return self
end

function MSBuilder:build()
    return self.base_script
end

return {MSBuilder, Goal, Constraint, StructureDeclaration}
