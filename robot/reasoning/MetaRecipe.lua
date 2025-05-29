local deep_copy = require("deep_copy")
local comms = require("comms")

-- Whole recipe get copied/cloned by the caller so that state is not changed in the primitive object for a given recipe
-- this decouples the definition of behaviour and data structure from its execution and state-change when in-vivo.
-- Of course, this relies on the caller properly clonning us, but we don't really have a good way to enforce this
-- from within MetaRecipe itself, so just be very very careful ok?
--
-- Output can be a name or lable if specified
local MetaRecipe = {
    output = nil,
    strict = "strict", -- if the names listed in output are strict matching or what sort of liniences they have

    dependencies = nil,
    meta_type = nil,
    mechanism = nil,

    state = nil
}
-- The state and lock are, of course, copied from primitives so that it yeah, for obvious reasions
function MetaRecipe:new(output, state_primitive, strict)
    local new = deep_copy.copy(self, pairs)

    new.state = deep_copy.copy(state_primitive, pairs)
    if strict ~= nil then
        new.strict = strict
    end

    if type(output) ~= table then
        output = {lable = output, name = nil}
    end
    new.output = output
    return new
end

-- goal_block is what is recognizable by geolyzer, name is usually enough, but if it is a GT-Ore, for example
-- colour and meta-data will probabily be necessary, these differences can be caught inside
-- "algorithm" which is supposed to be a function that takes "Gathering"
--
local Gathering = {tool = nil, level = nil, algorithm = nil}
function Gathering:new(tool, level, algorithm)
    local new = deep_copy.copy(self, pairs)
    new.tool = tool
    new.level = level
    new.algorithm = algorithm

    return new
end

-- Maybe make it so that once there is a crafting area in the base (maybe with a "cache"-like storage included
-- in such an area) the robot will no longer use/keep empty reserved it's internal crafting slot, and instead
-- fully relies on the base's crafting areas, because of the possible "caching" effect, and freeing up
-- robot internal inventory space this might be an amazing idea
local CraftingTable = {crafting_recipe = nil}
function CraftingTable:new(array)
    local new = deep_copy.copy(self, pairs)
    new.crafting_recipe = array
    return new
end
-- function CraftingTable:craft(dictionary)    -- this definition is probably useless, because prob. the inventory manager
                                            -- is the one that will have to do the crafting itself
--end

function MetaRecipe:newCraftingTable(output, recipe_table, dependencies, state_primitive, strict)
    if output == nil then
        error(comms.robot_send("error", "MetaRecipe:newCraftingTable, output param is nil"))
        return nil
    end
    if recipe_table == nil or type(recipe_table) ~= "table" then
        error(comms.robot_send("error", "recipe_table: \"" .. output .. "\" is nil or wrong type"))
        return nil
    end
    if #recipe_table < 1 and #recipe_table > 9 then
        error(comms.robot_send("error", "recipe_table: \"" .. output .. "\" is invalid size"))
        return nil
    end

    local new = self:new(output, state_primitive, strict)
    new.dependencies = dependencies
    new.meta_type = "crafting_table"

    new.mechanism = CraftingTable:new(recipe_table)
    return new
end

function MetaRecipe:newGathering(output, tool, level, algorithm, state_primitive, dependencies, strict)
    if output == nil then
        error(comms.robot_send("error", "MetaRecipe:newGathering, output param is nil"))
        return nil
    end
    if tool == nil or level == nil or algorithm == nil
            or type(algorithm) ~= "function" or state_primitive == nil then

        error(comms.robot_send("error", "MetaRecipe:newGathering, we did a fucky-wucky oopie wooppies"))
        return nil
    end

    local new = self:new(output, state_primitive, strict)
    new.dependencies = dependencies
    new.meta_type = "gathering"

    new.mechanism = Gathering:new(tool, level, algorithm)
    return new
end

-- TODO programme this for crafting recipes
function MetaRecipe:returnCommand(priority, lock_ref)
    if self.meta_type == "gathering" then
        self.state.priority = priority
        return {priority, self.mechanism.algorithm, self.mechanism, self.state, lock_ref }
    elseif self.meta_type == "crafting_table" then
        error(comms.robot_send("fatal", "MetaType \"crafting_table\" for now is unimplemented returnCommand"))
    else
        error(comms.robot_send("fatal", "Unimplemented meta_type selected for returnCommand in MetaRecipe: \""
            .. self.meta_type .. "\""))
    end
end

return MetaRecipe
