-- luacheck: globals REASON_WAIT_LIST
local comms = require("comms")

local inv = require("inventory.inv_obj")
local map = require("nav_module.map_obj")
local LogisticTransfer = require("complex_algorithms.LogisticTransfer")


local solve_tree = {}

-- It retrieves things logistacally in an eager manner, I hope we will not run out of inventory space or start
-- dumping things we need into long-term storage and then spin cycling
function solve_tree.selectDependency(ctx, needed_quantity, debug_name)
    local latest_node = ctx:getLatestNode()

    local mode, dep_found
    for _, dep in ipairs(latest_node.children) do
        -- Check if we're looping over or something similar, detect cycle and try to break it, error out if it can't be done
        if ctx:checkForLoop(dep.inlying_recipe) then
            return "loop_detected", ctx:getCurNodeIndex() + 1
        end


        local inner = dep.inlying_recipe
        local dep_needed_quantity = needed_quantity * dep.input_multiplier

        local count = inv.how_many_internal(inner.output.lable, inner.output.name)
        if count >= dep_needed_quantity then goto continue end

        -- if there is enough in external storage return "execute" + with a command to do logistics
        -- else recurse into our dependency tree by ways of searching inside ti for this output
        local min_quant = math.min(dep_needed_quantity / 2, 24) -- might need to be optimised in the future
        local pinv = inv.get_nearest_external_inv(
            inner.output.lable, inner.output.name, min_quant, dep_needed_quantity
        )

        -- It is complicated to chain these things together without assembling complicated algorithms,
        -- so we'll go with the simpler and least efficient route of going to the first thing we're missing
        if pinv ~= nil then
            local item_table = {inner.output.lable, inner.output.name, dep_needed_quantity}
            local to_transfer = {item_table}
            local inner = LogisticTransfer:new(pinv, "self", to_transfer)
            local logistic_nav = {inner.doTheThing, inner} -- command gets "completed" by caller
            mode = "execute"
            dep_found = logistic_nav
            break
        end

        if true then
            print(comms.robot_send("debug", "depth_recurse in solve_tree:search -- " .. debug_name))
            mode = "depth"
            dep_found = dep
            break
        end

        ::continue::
    end
    if mode == nil then
        print(comms.robot_send("debug", "all_good in solve_tree:search -- " .. debug_name))
        mode = "all_good"
        dep_found = nil
    end

    return mode, dep_found
end

function solve_tree.interpretSelection(needed_quantity, ctx, meta_type)
    local mode, dep_found = solve_tree.selectDependency(needed_quantity, meta_type)
    if mode == "depth" or mode == "execute" then
        return mode, dep_found
    elseif mode == "loop_detected" then
        local index = dep_found
        local recipe = ctx:unwind(index)
        return "force_recipe", recipe
    end

    return "all_good", nil
end


-- Are the conditions met so that we can be executed, or do we need to go into the dependencies?
-- If we need to go into the dependencies which return what we're missing
function solve_tree.isSatisfied(needed_quantity, ctx)
    local parent_recipe = ctx:getParentNode()

    if parent_recipe.meta_type == "crafting_table" then
        if parent_recipe.dependencies == nil then error(comms.robot_send("fatal", "This cannot be for a crafting_table")) end
        return solve_tree.interpretSelection(needed_quantity, ctx, parent_recipe.meta_type)

    elseif parent_recipe.meta_type == "gathering" then
        local gathering = parent_recipe.method
        local tool_dependency = parent_recipe.method:generateToolDependency(gathering.tool, gathering.level)
        if tool_dependency == nil then return "all_good", nil end

        -- we fake it!
        ctx:addDep(tool_dependency)
        return solve_tree.interpretSelection(needed_quantity, ctx, parent_recipe.meta_type)

    elseif parent_recipe.meta_type == "building_user" then
        -- Check if the building was built
        local name = parent_recipe.mechanism.bd_name
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
                if parent_recipe.dependencies == nil then error(comms.robot_send("fatal", "MetaScript no dependencies when we should have some")) end

                -- For example if we fail: No resources -> Oak Log, or No resources -> any:log etc. we should have a gathering or
                -- farming (building) dependency that provides such log etc.
                -- But, for example: if the thing that causes us to fail is something like: lack of flint, yet in the dependency
                -- resolution we come to understand first that there is lack of sticks, it's ok if the stick branch is chosen to
                -- performe a "depth" operation, because eventually, no matter de order, the deps will be solved

                local mode, dep_found = parent_recipe:selectDependency(needed_quantity, "building_thing")
                return mode, dep_found

           else
                error(comms.robot_send("error", "bad result in building_thing search"))
           end

        end -- forloop end

        return "breath" -- At last, least priority, we look into the other branches if possible
                        -- AKA: This is blocked right now, please go down another sister branch
    else
        error(comms.robot_send("fatal", "meta_type was badly set somewhere!"))
    end
end

return solve_tree
