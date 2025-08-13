---- Global Objects ----
-- luacheck: push ignore
local serialize = require("serialization")
local computer = require("computer")
-- luacheck: pop

---- Shared ----
local comms = require("comms")
local deep_copy = require("deep_copy")
local prio_insert = require("prio_insert")

---- Other ----
--local MetaRecipe = require("reasoning.MetaRecipe")
local command_helper = require("command_helper")
local solve_tree = require("reasoning.MetaRecipe.resolve_dep_tree")

local MetaContext = require("reasoning.MetaScript.RecipeTreeContext")
local Constraint = require("reasoning.MetaScript.Constraint")
local StructureDeclaration, _ = table.unpack(require("reasoning.MetaScript.Constraint.BuildingConstraint"))


-- Have name param as well?
-- Add to unlocking behaviour automatic unloading behaviour for scripts that deprecate
-- with the unlocking og the condition I guess
-- Maybe add "current_goal" param, so we don't have to search for best goal everytime idk
local MetaScript = {desc = nil, goals = {}, posterior = nil, p_unlock_condition = nil, recipes = {}, dictionary = nil}
function MetaScript:new() return deep_copy.copy(self, pairs) end
function MetaScript:addGoal(goal)
    if goal == nil or goal.constraint == nil then
        error(comms.robot_send("fatal", "MetaScript:addGoal, attempted to add nil or bad goal :/"))
    end
    prio_insert.named_insert(self.goals, goal)
end

MetaScript.latest_dud = {"Nothing", computer.uptime()}
function MetaScript:printLatestDud()
    local calc = computer.uptime() - self.latest_dud[2]
    print(comms.robot_send("info", string.format("Latest Dud: %s, %ss", self.latest_dud[1], calc)))
end

-- check if posterior script file can be unlocked
function MetaScript:unlockPosterior()
    if self.posterior == nil then return nil end
    error(comms.robot_send("fatal", "todo MetaScript unlock posterior"))
    -- TODO
end

-- TODO improve matching to follow the "strict" instruction
-- It prefers "singular" matches over table matches, table matches are only resolved after the loop
function MetaScript:findRecipe(lable, name)
    if self.recipes == nil then
        error(comms.robot_send("fatal", "MetaScript: \"" .. self.desc .. "\"NO RECIPES!"))
    end
    if lable == nil then
        error(comms.robot_send("fatal", "MetaScript -- can't find a recipe when no lable provided dummy dumb dumb"))
    end

    for _, recipe in ipairs(self.recipes) do
        if recipe:includesOutputLiteral(lable, name) then
            return recipe
        end
    end -- fallthrough

    -- Time for a hack!
    if name == nil then name = "nil" end
    if lable == nil then lable = "nil" end
    if string.find(lable, "Ore") or string.find(name, ":raw_ore") then
        for _, recipe in ipairs(self.recipes) do
            if recipe:includesOutputLiteral("_Ore", "_Ore") then return recipe end
        end
    end

    print(comms.robot_send("error", "No recipe for: \"" .. lable .. "\" found!"))
    return nil
end

function MetaScript:findBestGoal()
    for index = #self.goals, 1, -1 do -- Reverse order so it goes from highest prio to lowest
        local goal = self.goals[index]
        if goal:depSatisfied() then
            local inner_index, name = goal:selfSatisfied()
            if inner_index ~= nil and inner_index ~= 0 then
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

    local result, extra = best_goal:step(index, name, self, false)
    if result == nil and index >= 1 then -- activate power saving, or change active scripts
        print(comms.robot_send("warning", "MetaScript:step() -- ran out of goals!"))
        return "end", nil
    end

    -- TODO -> check if we only need to do fetch it from an external inventory or if we really need to recurse
    -- this behaves really curiously, since it doesn't lock the goal, it'll keep trying to lock it in, maybe change this?
    if extra ~= nil and extra[1] == "try_recipe" then -- happens when a non recipe goal demands a recipe
        -- after try recipe it's getting locked? idk why
        -- luacheck: push ignore extra
        local extra_quantity = extra[2]
        result, extra = best_goal:step(nil, result, self, true, extra_quantity)
        if result == nil then
            print(comms.robot_send("error", "MetaScript:step() -- Tried to force a recipe, but failed to find one"))
            return "end", nil
        end
        -- luacheck: pop
    end

    return "continue", result
end


-- goals depend on other goals
-- in this way goals follow a sort of dependency acyclic (hopefully graph)
-- if a cyclic graph is created it probably is undefined behaviour so yeah
-- Goals tell us /when/ to do, constraints tell us /what/ to do
-- and recipes tell us /how/ to do, and priority in /what order/ when there are
-- multiple things to do
-- Of course in the case of buildings, the "how to do" is just a matter of reading
-- the requires schematic, so it is much more a case of extracting the required
-- user interaction from the user -- this is to say, the recipes are the buildings
-- themselves which are self-explaining, unlike items which require explanations
local Goal = {name = "None", dependencies = nil, constraint = nil, priority = 0, do_once = false}
function Goal:new(dependencies, constraint, priority, name, do_once)
    local new = deep_copy.copy(self, pairs)
    if name == nil then
        print(comms.robot_send("error", "Failed to create goal because no name sent"))
        print(comms.robot_send("error", debug.traceback()))
    end

    new.name = name or "None"
    new.do_once = do_once or false
    if dependencies == nil then
        new.dependencies = nil
    elseif dependencies.name ~= nil then -- it means this is not a table of dependencies
        new.dependencies = { dependencies }
    else
        new.dependencies = dependencies  -- because it already IS a table of dependencies (hopefully)
    end
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
        if index == nil or index ~= 0 then return false end
    end
    return true
end


local recurse_watch_dog = 0
local function recurse_recipe_tree(head_recipe, needed_quantity, ctx)
    local recurse = false
    local recipe_to_execute = head_recipe

    -- Type of extra_info and its usage is dependent of check value returned
    local return_info

    ctx:addAllDeps(head_recipe.dependencies)
    local check, extra_info = solve_tree.isSatisfied(needed_quantity, ctx)
    if check == "breadth" then -- will return back and tell caller to find a sister if possible

        return "breadth"
    elseif check == "depth" then -- will continue deeper

        recurse = true
        recipe_to_execute = extra_info.inlying_recipe
        needed_quantity = needed_quantity * extra_info.input_multiplier
        ctx:addDepth(extra_info) -- IMPORTANT
    elseif check == "all_good" then

        return_info = extra_info
    elseif check == "no_resources" then

        error(comms.robot_send("fatal", "recurse_recipe_tree, not implemented"))
    elseif check == "non_fatal_error" then

        print(comms.robot_send("warning", "recurse_recipe_tree non_fatal_error, check your ils for more information"))
        return nil
    elseif check == "execute" then

        recipe_to_execute = "execute"
        return_info = extra_info
    elseif check == "force_recipe" then
        recurse = false
        recipe_to_execute = extra_info
    else
        error(comms.robot_send("fatal", "recurse_recipe_tree, unknown"))
    end

    if not recurse then return recipe_to_execute, return_info, needed_quantity end

    if recurse_watch_dog > 20 then
        error(comms.robot_send("fatal", "Goal:step() -- watch_dog exceeded, does recipe not get solved?"))
    end
    recurse_watch_dog = recurse_watch_dog + 1

    return recurse_recipe_tree(recipe_to_execute, needed_quantity, ctx) -- tail recursion
end

-- Some day please fix the idiotic polymorphism of this whole code section
-- (Some-times we try to find a recipe from something that is not an item contraint goal and we'll need
-- to override the quantity from outside (for example when a building constraint doesn't have building
-- materials)
function Goal:step(index, name, parent_script, force_recipe, quantity_override)
    if self.constraint:returnType() == "building" and not force_recipe then -- aka, is this a building constraint?
        return self.constraint:step(index, name, self.priority)
    end
    self.constraint.const_obj.lock[1] = 1 -- Say that now we're processing the request and to not accept more
    local needed_recipe = deep_copy.copy(parent_script:findRecipe(name.lable, name.name), pairs) -- :) copy it so that the state isn't mutated
    if needed_recipe == nil then
        -- self.constraint.const_obj.lock[1] = 4  -- aka -> locked until user input (TODO)
        self.constraint.const_obj.lock[1] = 0 -- auto-unlock until we implement the waiting list fully
        parent_script.latest_dud[1] = self.name; parent_script.latest_dud[2] = computer.uptime()
        return nil
    end

    local needed_quantity
    if quantity_override == nil then
        needed_quantity = self.constraint.const_obj.set_count
    else
        needed_quantity = quantity_override
    end

    local extra_info
    needed_recipe, extra_info, needed_quantity = recurse_recipe_tree(needed_recipe, needed_quantity, MetaContext:new(needed_recipe))

    -- TODO implement mechanism to unlock this lock
    if needed_recipe == nil then
        -- TODO -- add different lock number for: "we check again after this many seconds" (3 is == "add to ils-system")
        -- eh, for now fuck it, just return nil and wait?
        -- self.constraint.const_obj.lock[1] = 4  -- aka -> locked until user input
        parent_script.latest_dud[1] = self.name; parent_script.latest_dud[2] = computer.uptime()
        return nil
    elseif needed_recipe == "breadth" then -- TODO
        error(comms.robot_send("fatal", "MetaScript todo! breath search"))
    elseif needed_recipe == "execute" then
        -- nice and abstract
        if extra_info == nil or type(extra_info) ~= "table" then error(comms.robot_send("fatal", "bad arguments!")) end
        table.insert(extra_info, 1, self.priority)

        table.insert(extra_info, self.constraint.const_obj.lock)
        table.insert(extra_info, self.priority)
        local return_table = extra_info
        -- local prio, command, arguments = command_helper.raw_break_appart(return_table)
        -- command_helper.inspect_raw(prio, command, arguments)

        return return_table
    end
    print(comms.robot_send("debug", "Found needed_recipe for: " .. needed_recipe.output.lable))

    -- local serial_recipe = serialize.serialize(needed_recipe, 40)
    -- print(comms.robot_send("debug", serial_recipe))

    -- local up_to_quantity = self.constraint.const_obj.reset_count
    local return_table = needed_recipe:returnCommand(
        self.priority,
        self.constraint.const_obj.lock,
        needed_quantity,
        extra_info,
        parent_script.dictionary
    )
    return return_table
end


local MSBuilder = {base_script = MetaScript:new()}
function MSBuilder:new() return deep_copy.copy(self, pairs) end
function MSBuilder:new_w_desc(desc)
    local new = self:new()
    new.base_script.desc = desc
    return new
end

function MSBuilder:addMultipleRecipes(recipes)
    for _, element in ipairs(recipes) do
        table.insert(self.base_script.recipes, element)
    end
    return self
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

function MSBuilder:setDictionary(dict)
    self.base_script.dictionary = dict
    return self
end

return {MSBuilder, Goal, Constraint, StructureDeclaration, MetaScript}
