---- Global Objects ----

---- Shared ----
local comms = require("comms")
local deep_copy = require("deep_copy")
local prio_insert = require("prio_insert")

---- Other ----
--local MetaRecipe = require("reasoning.MetaRecipe")
local Constraint = require("reasoning.MetaScript.Constraint")
local StructureDeclaration, _ = require("reasoning.MetaScript.Constraint.BuildingConstraint")

-- Have name param as well?
-- Add to unlocking behaviour automatic unloading behaviour for scripts that deprecate
-- with the unlocking og the condition I guess
-- Maybe add "current_goal" param, so we don't have to search for best goal everytime idk
local MetaScript = {desc = nil, goals = {}, posterior = nil, p_unlock_condition = nil, recipes = {}}
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

-- TODO improve matching to follow the "strict" instruction
-- It prefers "singular" matches over table matches, table matches are only resolved after the loop
function MetaScript:findRecipe(for_what)
    if self.recipes == nil then
        error(comms.robot_send("fatal", "MetaScript: \"" .. self.desc .. "\"NO RECIPES!"))
    end

    local table_found = nil
    for _, recipe in ipairs(self.recipes) do
        local output = recipe.output
        if type(output) == "table" then -- aka, an equal mult-output recipe (not merely by-products)
            for _, element in ipairs(recipe) do
                if element == for_what then table_found = recipe end
            end
            goto continue
        end

        if output == for_what then return recipe end
        ::continue::
    end
    
    if table_found ~= nil then return table_found end

    print(comms.robot_send("error", "No recipe for: \"" .. for_what .. "\" found!"))
    return nil
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
        print(comms.robot_send("debug", "MetaScript:step() -- couldn't find best goal"))
        return "fail", nil
    end
    print(comms.robot_send("info", "MetaScript:step() -- selected a command to to execute: " .. best_goal.name))

    local result = best_goal:step(index, name, self)
    if result == nil and index >= 1 then -- activate power saving, or change active scripts
        print(comms.robot_send("warning", "MetaScript:step() -- ran out of goals!"))
        return "end", nil
    end

    return "continue", result
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
local Goal = {name = "None", dependencies = nil, constraint = nil, priority = 0, do_once = false}
function Goal:new(dependencies, constraint, priority, name, do_once)
    local new = deep_copy.copy(self, pairs)
    new.name = name or "None"
    new.do_once = do_once or false
    new.dependencies = dependencies or nil
    new.constraint = constraint or nil -- may resolve to nil or nil and that is hilarious
    new.priority = priority or 0
    return new
end

function Goal:selfSatisfied()
    return self.constraint:check(self.do_once)
end

function Goal:depSatisfied()
    if self.dependencies == nil then return true end
    for _, dep in ipairs(self.dependencies) do
        local index, _ = dep:selfSatisfied()
        if index ~= 0 then return false end
    end
    return true
end

function Goal:step(index, name, parent_script)
    if self.constraint:returnType() == "building" then -- aka, is this a building constraint?
        return self.constraint:step(index, name, self.priority)
    end
    self.constraint.const_obj.lock[1] = 1 -- Say that now we're processing the request and to not accept more
    local needed_recipe = deep_copy.copy(parent_script:findRecipe(name), pairs) -- :) copy it so that the state isn't mutated

    local return_table = needed_recipe:returnCommand(self.priority, self.constraint.const_obj.lock)
    return return_table
end


local MSBuilder = {base_script = MetaScript:new()}
function MSBuilder:new() return deep_copy.copy(self, pairs) end
function MSBuilder:new_w_desc(desc)
    local new = self:new()
    new.base_script.desc = desc
    return new
end

function MSBuilder:addRecipe(recipe)
    table.insert(self.base_script.recipes, recipe)
    return self
end

function MSBuilder:addGoal(goal)
    self.base_script:addGoal(goal)
    return self
end

function MSBuilder:build()
    return self.base_script
end

return {MSBuilder, Goal, Constraint, StructureDeclaration}
