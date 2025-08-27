-- luacheck: globals REASON_WAIT_LIST

local deep_copy = require("deep_copy")
local comms = require("comms")

-- luacheck: push ignore
local serialize = require("serialization")
-- luacheck: pop
local build_eval = require("eval.build")
local inv = require("inventory.inv_obj")

-- This state_primitive bullshitery and what not seems quite poorly designed, we'll need to revise that for v2
-- only gathering uses that stupid crap anyway


-- Whole recipe get copied/cloned by the caller so that state is not changed in the primitive object for a given recipe
-- this decouples the definition of behaviour and data structure from its execution and state-change when in-vivo.
-- Of course, this relies on the caller properly clonning us, but we don't really have a good way to enforce this
-- from within MetaRecipe itself, so just be very very careful ok?
--
-- Output can be a name or lable if specified
local MetaRecipe = {
    output = nil,
    strict = "strict", -- if the names listed in output are strict matching or what sort of liniences they have

    dependencies = nil, -- of MetaDependency type, which is a fat ref to Recipe
    meta_type = nil,
    mechanism = nil,

    state = nil
}

-- ngl "strict" prob is on the way out
-- variable "strict" is related to the interpretation of the output
-- The state and lock are, of course, copied from primitives so that it yeah, for obvious reasions
function MetaRecipe:new(output, state_primitive, strict, dependencies)
    local new = deep_copy.copy(self, pairs)
    --[[local serial = serialize.serialize(output)
    print(serial)
    io.read()--]]

    new.state = deep_copy.copy(state_primitive, pairs)
    if strict ~= nil then
        new.strict = strict
    end

    if type(output) ~= "table" then
        local fmt_output = {lable = output, name = "nil_name"}
        new.output = fmt_output
    else -- complicated set of operations in order to create a valid table arrangement
        if #output == 0 and output.lable == nil and output.name == nil then
            local serial = serialize.serialize(output)
            error(comms.robot_send("fatal", "assertion failed\n" .. serial))
        end

        if output.lable ~= nil then -- it is already well formated
            local fmt_output = deep_copy.copy(output, pairs)
            if type(fmt_output.name) == "table" then
                for index, l_name in ipairs(fmt_output.name) do
                    if l_name == nil then fmt_output.name[index] = "nil_name" end
                end
            else
                if fmt_output.name == nil then fmt_output.name = "nil_name" end
            end
            new.output = output
        elseif output.name ~= nil and type(output.name) == "string" then
            local fmt_output = {lable = "nil_lable", name = output.name}
            new.output = fmt_output
        elseif output.name == nil then -- It's just a table of lables (or
            local fmt_output = {lable = output, name = {}}
            for i = 1, #fmt_output.lable, 1 do
                fmt_output.name[i] = "nil_name"
            end
            new.output = fmt_output
        else
            error(comms.robot_send("fatal", "unexpected"))
        end
    end
    if new.output == nil then error(comms.robot_send("fatal", "assertion failed")) end

    -- this failed to activate because I was only checking for type table and not for if it is a raw MetaDependency
    if dependencies ~= nil and dependencies.inlying_recipe ~= nil then -- else it must be a table of deps
        dependencies = {dependencies}
    elseif dependencies ~= nil and dependencies[1].inlying_recipe == nil then
        error(comms.robot_send("fatal", "You did a big oopsie the dependencies are bad dawg"))
    end
    new.dependencies = dependencies

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

--local default_tools = require("reasoning.recipes.default_tools")
local default_tools = nil
function Gathering:generateToolDependency(tool_type, tool_level)
    if default_tools == nil then default_tools = require("reasoning.recipes.default_tools") end

    if self.tool == nil then return nil end
    local tool_recipes = default_tools[1]

    local match = nil
    for _, tool_def in ipairs(tool_recipes) do
        -- TODO add conditional checks that'll pick bronze over iron etc. when certain conditions are met
        if tool_def.tool_type == tool_type and tool_def.tool_level >= tool_level then
            match = tool_def.inner_dep
            break
        end
    end
    if match == nil then error(comms.robot_send("fatal", "No recipe defined for: " .. tool_type .. ", " .. tool_level)) end

    return match.inner_def
end

-- gathering depends on tools, add tool_recipe when possible?
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

    local new = self:new(output, state_primitive, strict, dependencies)

    new.meta_type = "gathering"
    new.mechanism = Gathering:new(tool, level, algorithm)
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

function MetaRecipe:newCraftingTable(output, recipe_table, dependencies, strict)
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

    local new = self:new(output, nil, strict, dependencies)

    new.meta_type = "crafting_table"
    new.mechanism = CraftingTable:new(recipe_table)
    return new
end

local BuildingUser = { -- This sort of recipe passes all the implementation over to the "build" module
    bd_name = nil,
    usage_flag = nil, -- I think that it is in recipe level that it is appropriate to decide the flag
}
function BuildingUser:new(bd_name, usage_flag)
    local new = deep_copy.copy(self, pairs)
    if bd_name == nil then
        bd_name = "nil"
        print(comms.robot_send("warning", "bd_name was nil in:\n" .. debug.traceback()))
    end

    new.bd_name = bd_name

    if usage_flag == nil then
        print(comms.robot_send(
            "warning",
            string.format("usage flag for building has been set to nil for bd_name: \"%s\"\n%s", bd_name, debug.traceback())
        ))
        usage_flag = "raw_usage"
    end

    new.usage_flag = usage_flag

    return new
end

function MetaRecipe:newBuildingUser(output, bd_name, usage_flag, strict, dependencies)
    local new = self:new(output, nil, strict, dependencies)

    new.meta_type = "building_user"
    new.mechanism = BuildingUser:new(bd_name, usage_flag)
    return new
end

-- checks if there is ANY intersection betwen the sets
function MetaRecipe:includesOutput(other)
    -- TODO - support multiple outputs, but not in this way!
    if type(self.output.lable) == "table" then
        for self_index = 1, #self.output.lable, 1 do
            local s_lable = self.output.lable[self_index]
            local s_name = self.output.name[self_index]

            if type(other.output.lable) == "table" then
                for other_index = 1, #other.output.lable, 1 do
                    local o_lable = other.output.lable[other_index]
                    local o_name = other.output.name[other_index]
                    if o_lable == s_lable and o_name == s_name then return true end
                end -- for other
                return false
            end -- if otther is table

            if other.output.lable == s_lable and other.output.name == s_name then return true end
        end -- for self

        return false
    end

    return self.output.lable == other.output.lable and self.output.name == other.output.name
end

function MetaRecipe:includesName(name)
    return self.output.name == other.output.name
end

function MetaRecipe:includesOutputLiteral(lable, name)
    if lable == nil then lable = "nil_lable" end
    if name == nil then name = "nil_name" end

    local other = {output = {lable = lable, name = name}}
    return self:includesOutput(other)
end

function MetaRecipe:returnCommand(priority, lock_ref, up_to_quantity, extra_info, dictionary)
    -- This gathering bullshit is the buggiest, hackiest stuff around, makes sense since it was the first thing I did, but
    -- holy shit, I should've been way way way smarter.
    if self.meta_type == "gathering" then
        -- state probabily needs to be copied over no matter what (whenever we create/start a new gathering instance)
        -- to stop the pie from getting contaminated

        -- self.state.priority = priority
        self.state.priority = 100   -- I guess that the priority of a gathering once we start doing one should always be 100
                                    -- we should as well certify that only one gathering occurs at a time, but that is a little
                                    -- bit more difficult to certify, I just hope that this priority trick is enough
        -- even though we set the state.priority as 100 we keep the regular priority as whatever was defined in the goal
        -- this means that the command will be handled as normal BEFORE we start executing the gathering, but once we
        -- start gathering there is no stopping until we finish the gathering!
        return {priority, self.mechanism.algorithm, self.mechanism, deep_copy.copy(self.state), up_to_quantity, lock_ref }
    elseif self.meta_type == "building_user" then
        -- here extra info should be a ref to the building we need to use
        local build = extra_info
        if build == nil then error(comms.robot_send("fatal", "MetaRecipe:returnCommand, extra_info was nil when it shouldn't")) end

        local usage_flag = self.mechanism.usage_flag
        local hook_exec_index = 1

        local one_dep = self.dependencies[1]
        local one_recipe = one_dep.inlying_recipe

        local dep_quantity = math.ceil(one_dep.input_multiplier * up_to_quantity)
        local check_table = {one_recipe.output, dep_quantity}

        -- callee then determins how many inputs are needed and does all the inventory management
        -- reasoning should not be doing any invenotry management fr fr
        local r_table = {priority, build_eval.use_build, build, usage_flag, hook_exec_index, check_table, priority, lock_ref}
        --[[for k, v in pairs(r_table) do
            if v == nil then v = "nil"
            elseif type(v) == "table" then v = "table"
            elseif type(v) == "function" then v = "function" end
            print(comms.robot_send("debug", k .. ", " .. v))
        end--]]
        return r_table
    elseif self.meta_type == "crafting_table" then
        -- seems good? All that is missing is a mechanism that limites the batch size for a craft
        -- (so that we don't try and craft 234 things at once for example) -- add this to the mechanism?!
        return {priority, inv.craft, dictionary, self.mechanism.crafting_recipe, self.output, up_to_quantity, lock_ref}
    else
        error(comms.robot_send("fatal", "Unimplemented meta_type selected for returnCommand in MetaRecipe: \""
            .. self.meta_type .. "\""))
    end
end

return MetaRecipe
