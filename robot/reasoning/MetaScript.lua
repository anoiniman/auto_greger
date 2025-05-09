local comms = require("comms")
local deep_copy = require("deep_copy")
local prio_insert = require("prio_insert")
local MetaRecipe = require("reasoning.MetaRecipe")

-- Have name param as well?
-- Add to unlocking behaviour automatic unloading behaviour for scripts that deprecate
-- with the unlocking og the condition I guess
local MetaScript = {desc = nil, goals = {}, posterior = nil, p_unlock_condition = nil}
function MetaScript:new() return deep_copy.copy(self, pairs) end
function MetaScript:addGoal(goal)
    if goal == nil or goal.constraint == nil then
        error(comms.robot_send("fatal", "MetaScript:addGoal, attempted to add nil or bad goal :/"))
    end
    prio_insert.named_insert(self.goals, goal)
end
function MetaScript:step() -- most important function does everything, I think
    -- TODO check if posterior script file can be unlocked
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

local StructureDeclaration = {structure_name = nil, x_offset = 0, z_offset = 0, quadrant = -1}
function StructureDeclaration:new(structure_name, x_offset, z_offset, quadrant)
    local new = deep_copy.copy(self, pairs)
    new.structure_name = structure_name
    new.x_offset = x_offset
    new.z_offset = z_offset
    new.quadrant = quadrant
    return new
end

-- If chunk_centre is left nil, then the script will be in interactive mode, probabilly
-- this will be the default, but who the fuck knows
-- MetaStructures will first be eagerly pre-loaded and only then associated with
-- determinate MetaBuilds and MetaQuads, probabily
local BuildingConstraint = {structutres = nil, chunk_centre = nil}
function BuildingConstraint:new()
    local new = deep_copy.copy(self, pairs)
    return new
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
function Constraint:newItemConstraint(item_name, total_count)
    local new = self:new()
    new.const_type = "item_constraint"
    new.const_obj = ItemConstraint:new(item_name, total_count)
end

function Constraint:newBuildingConstraint(structures, centre)
    local new = BuildingConstraint:new()
    new.structures = structures
    new.centre = centre or nil
    return new
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
end


local MSBuilder = {base_script = MetaScript:new()}
function MSBuilder:new() return deep_copy.copy(self, pairs) end
function MSBuilder:new_w_desc(desc)
    local new = self:new()
    new.base_script.desc = desc
    return new
end

function MSBuilder:addGoal(goal)
    self.base_script:add_goal(goal)
    return self
end

function MSBuilder:build()
    return self:base_script
end

return MSBuilder, Goal, Constraint, StructureDeclaration
