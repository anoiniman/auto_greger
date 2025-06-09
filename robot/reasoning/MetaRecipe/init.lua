-- luacheck: globals REASON_WAIT_LIST

local deep_copy = require("deep_copy")
local comms = require("comms")

local serialize = require("serialization")

local build_eval = require("eval.build")
local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")

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

-- variable "strict" is related to the interpretation of the output
-- The state and lock are, of course, copied from primitives so that it yeah, for obvious reasions
function MetaRecipe:new(output, state_primitive, strict, dependencies)
    local new = deep_copy.copy(self, pairs)

    new.state = deep_copy.copy(state_primitive, pairs)
    if strict ~= nil then
        new.strict = strict
    end

    if type(output) ~= "table" then
        output = {lable = output, name = nil}
    end
    new.output = output

    if type(dependencies) ~= "table" then
        dependencies = {dependencies}
    end
    new.dependencies = dependencies

    return new
end

-- Are the conditions met so that we can be executed, or do we need to go into the dependencies?
-- If we need to go into the dependencies which return what we're missing
function MetaRecipe:isSatisfied(needed_quantity)
    if self.meta_type == "gathering" then
        -- Check if we got the tools
        error(comms.robot_send("fatal", "MetaRecipe todo01"))
    elseif self.meta_type == "crafting_table" then
        -- Check if we have enough materials to craft the given quantity
        error(comms.robot_send("fatal", "MetaRecipe todo02"))
    elseif self.meta_type == "building_user" then
        -- Check if the building was built
        local name = self.mechanism.bd_name
        local buildings = map.get_buildings(name)
        if buildings == nil or #buildings == 0 then return "non_fatal_error", "building" end


        for _, build in ipairs(buildings) do
            local result = build:runBuildCheck(needed_quantity)

            if result == "all_good" then
                return "all_good", build

            elseif result == "wait" then
                REASON_WAIT_LIST:checkAndAdd(build) -- building was sent to waiting list, cron will the re-rerun checks
                                                    -- if we still need to use the building and it becomes avaliable use it
                                                    -- otherwise remove it form list (TODO)

            elseif result == "no_resources" then -- TODO -> continue from here, add some debug symbols
                -- The below intuition is not true, because if it can return "no_resources" then we must have dependencies
                -- if this is not the case then we've failed in configurating and we should crash
                -- if self.dependencies == nil then return "all_good", nil end
                if self.dependencies == nil then error(comms.robot_send("fatal", "MetaScript no dependencies when we should have some")) end

                -- For example if we fail: No resources -> Oak Log, or No resources -> any:log etc. we should have a gathering or
                -- farming (building) dependency that provides such log etc.
                -- But, for example: if the thing that causes us to fail is something like: lack of flint, yet in the dependency
                -- resolution we come to understand first that there is lack of sticks, it's ok if the stick branch is chosen to
                -- performe a "depth" operation, because eventually, no matter de order, the deps will be solved

                local found_dep
                for _, dep in ipairs(self.dependencies) do
                    local inner = dep.inlying_recipe
                    local dep_needed_quantity = needed_quantity * dep.input_multiplier

                    local count = inv.how_many_internal(inner.output.name, inner.output.lable)
                    -- we have the stuff with us (make sure that the hook can handle this fact, aka, that we won't dump the needed
                    -- stuff into an entry-cache chest ('?' symbol)
                    if count >= needed_quantity then break end

                    -- this checks if the inner dep is satisfied which is wrong VVV
                    --> if count >= dep_needed_quantity then goto continue end -- check next dep

                    -- TODO: if there is enough in long term storage return "all_good" + where we can find this, else recurse deeper
                    -- into our dependency tree by ways of searching inside ti for this output

                    -- if ledger_exists(inner.output.name, inner.output.lable, required_quantity) then
                    --      return "needs_logitics", extra_information
                    -- else if this fails to then it must mean that this dependency is unsatisfied:

                    found_dep = dep
                    break

                    ::continue::
                end

                -- TODO: this works in the case we have the missing resources in our inventory, however if these missing resources are
                -- in fact in long-term storage we'll need to return something different, so that the robot may first retrieve these
                -- items and only then proceed to the building we want to use
                if found_dep == nil then 
                    print(comms.robot_send("debug", "all_good in MetaRecipe search building_thing"))
                    return "all_good", build 
                end

                print(comms.robot_send("debug", "depth_recurse in MetaRecipe search building_thing"))
                return "depth", found_dep
            end
        end
        return "breath" -- At last, least priority, we look into the other branches if possible
                        -- AKA: This is blocked right now, please do down another sister branch
    else
        error(comms.robot_send("fatal", "meta_type was badly set somewhere!"))
    end
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

    local new = self:new(output, state_primitive, strict, dependencies)

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
    new.bd_name = bd_name
    new.usage_flag = usage_flag

    return new
end

function MetaRecipe:newBuildingUser(output, bd_name, usage_flag, strict, dependencies)
    local new = self:new(output, nil, strict, dependencies)

    new.meta_type = "building_user"
    new.mechanism = BuildingUser:new(bd_name, usage_flag)
    return new
end

-- TODO programme this for crafting recipes
function MetaRecipe:returnCommand(priority, lock_ref, up_to_quantity, extra_info)
    if self.meta_type == "gathering" then
        self.state.priority = priority
        return {priority, self.mechanism.algorithm, self.mechanism, self.state, up_to_quantity, lock_ref }
    elseif self.meta_type == "building_user" then
        -- here extra info should be a ref to the building we need to use
        local build = extra_info
        if build == nil then error(comms.robot_send("fatal", "MetaRecipe:returnCommand, extra_info was nil when it shouldn't")) end

        local usage_flag = self.mechanism.usage_flag
        local hook_exec_index = 1

        -- callee then determins how many inputs are needed and does all the inventory management
        -- reasoning should not be doing any invenotry management fr fr
        local r_table = {priority, build_eval.use_build, build, usage_flag, hook_exec_index, up_to_quantity, priority, lock_ref}
        for k, v in pairs(r_table) do
            if v == nil then v = "nil"
            elseif type(v) == "table" then v = "table"
            elseif type(v) == "function" then v = "function" end
            print(comms.robot_send("debug", k .. ", " .. v))
        end
        return r_table
    elseif self.meta_type == "crafting_table" then
        error(comms.robot_send("fatal", "MetaType \"crafting_table\" for now is unimplemented returnCommand"))
    else
        error(comms.robot_send("fatal", "Unimplemented meta_type selected for returnCommand in MetaRecipe: \""
            .. self.meta_type .. "\""))
    end
end

return MetaRecipe
