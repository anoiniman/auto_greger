local MetaRecipe = {
    output = nil,
    meta_type = nil,
    mechanism = nil
}
local deep_copy = require("deep_copy")
local comms = require("comms")

-- goal_block is what is recognizable by geolyzer, name is usually enough, but if it is a GT-Ore, for example
-- colour and meta-data will probabily be necessary, these differences can be caught inside
-- "algorithm" which is supposed to be a function that takes "Gathering"
local Gathering = {tool = nil, level = nil, algorithm = nil, state = nil}
function Gathering:new(tool, level, algorithm, state)
    local new = deep_copy.copy(self, pairs)
    new.tool = tool;
    new.level = level;
    new.algorithm = algorithm;
    new.state = state

    return new
end

-- Maybe make it so that once there is a crafting area in the base (maybe with a "cache"-like storage included
-- in such an area) the robot will no longer use/keep empty reserved it's internal crafting slot, and instead
-- fully relies on the base's crafting areas, because of the possible "caching" effect, and freeing up
-- robot internal inventory space this might be an amazing idea
local CraftingTable = {recipe = nil}
function CraftingTable:new(array)
    local new = deep_copy.copy(self, pairs)
    new.recipe = array
    return new
end
-- function CraftingTable:craft(dictionary)    -- this definition is probably useless, because prob. the inventory manager
                                            -- is the one that will have to do the crafting itself
--end

--[[local MetaRecipe.output = nil
local MetaRecipe.meta_type = nil
local MetaRecipe.mechanism = nil--]]

function MetaRecipe:new()
    return deep_copy.copy(self, pairs)
end

function MetaRecipe:newCraftingTable(output, recipe_table)
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

    local new = self:new()
    new.meta_type = "crafting_table"
    new.output = output

    new.mechanism = CraftingTable:new(recipe_table)
    return new
end

function MetaRecipe:newGathering(output, tool, level, algorithm, state_primitive)
    if output == nil then
        error(comms.robot_send("error", "MetaRecipe:newGathering, output param is nil"))
        return nil
    end
    if tool == nil or level == nil or algorithm == nil
            or type(algorithm) ~= "function" or state_primitive == nil then

        error(comms.robot_send("error", "MetaRecipe:newGathering, we did a fucky-wucky oopie wooppies"))
        return nil
    end

    local new = self:new()
    new.meta_type = "gathering"
    new.output = output

    local state = deep_copy.copy(state_primitive, pairs)

    new.mechanism = Gathering:new(tool, level, algorithm, state)
    return new
end

-- TODO programme this for crafting recipes
function MetaRecipe:returnCommand(priority)
    if self.meta_type == "gathering" then
        self.mechanism.state.priority = priority
        return {prio, self.mechanism.algorithm, self.mechanism }
    elseif self.meta_type == "crafting_table" then
        error(comms.robot_send("fatal", "MetaType \"crafting_table\" for now is unimplemented returnCommand"))
    else
        error(comms.robot_send("fatal", "Unimplemented meta_type selected for returnCommand in MetaRecipe: \""
            .. self.meta_type .. "\""))
    end
end

return MetaRecipe
