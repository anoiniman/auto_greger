local MetaRecipe = {}
local deep_copy = require("deep_copy")
local comms = require("comms")

-- goal_block is what is recognizable by geolyzer, name is usually enough, but if it is a GT-Ore, for example
-- colour and meta-data will probabily be necessary, these differences can be caught inside
-- "algorithm" which is supposed to be a function that takes "Gathering"
local Gathering = {tool = nil, level = nil, algorithm = nil, state = nil, algo_pass = nil}
function Gathering:new(tool, level, algorithm, algo_pass)
    local new = deep_copy.copy(self, pairs)
    new.tool = tool; new.level = level; new.algorithm = algorithm; new.algo_pass = algo_pass 
    new.state = {}
end
function Gathering:call(change_state)
    return self.algorithm(self.state, change_state, self.algo_pass)
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


local MetaRecipe.output = nil
local MetaRecipe.meta_type = nil
local MetaRecipe.mechanism = nil

function MetaRecipe:new()
    return deep_copy.copy(self, pairs)
end

function MetaRecipe:newCraftingTable(output, recipe)
    if output == nil then
        error(comms.robot_send("error", "MetaRecipe:newCraftingTable, output param is nil"))
        return nil
    end
    if recipe == nil or type(recipe) ~= "table" then 
        error(comms.robot_send("error", "recipe: \"" .. name .. "\" is nil or wrong type"))
        return nil
    end
    if #recipe < 1 and #recipe > 9 then
        error(comms.robot_send("error", "recipe: \"" .. name .. "\" is invalid size"))
        return nil
    end

    local new = self:new()
    new.meta_type = "crafting_table"
    new.output = output

    new.mechanism = CraftingTable:new(recipe)
    return new
end

function MetaRecipe:newGathering(output, tool, level, algorithm, goal_block)
    if output == nil then
        error(comms.robot_send("error", "MetaRecipe:newGathering, output param is nil"))
        return nil
    end
    if tool == nil or level == nil, or algorithm == nil 
            or type(algorithm) ~= "function" or goal_block == nil then

        error(comms.robot_send("error", "MetaRecipe:newGathering, we did a fucky-wucky oopie wooppies"))
        return nil
    end

    local new = self:new()
    new.meta_type = "gathering"
    new.output = output

    new.mechanism = Gathering:new(tool, level, algorithm, goal_block)
    return new
end

return MetaRecipe
