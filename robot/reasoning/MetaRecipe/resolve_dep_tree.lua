-- luacheck: globals REASON_WAIT_LIST
local comms = require("comms")

local inv = require("inventory.inv_obj")
local map = require("nav_module.map_obj")
local LogisticTransfer = require("complex_algorithms.LogisticTransfer")

-- If at any point we try go "depth" but there are no further dependencies that means we went down a "bad_path"
-- and we should try to go back up until an "Optional" dep_type gives us another choice,
-- however I don't feel like implementing that right now, so instead of "Optional" types I'll simply
-- "reload" the recipes using global flags once we pass a certain objective and hope for the best,
-- it'll be enough for today (TODO episode 2)
local solve_tree = {}

-- It retrieves things logistacally in an eager manner, I hope we will not run out of inventory space or start
-- dumping things we need into long-term storage and then spin cycling
function solve_tree.selectDependency(ctx, needed_quantity, debug_name)
    local latest_node = ctx:getLatestNode()

    local mode, dep_found
    for _, node in ipairs(latest_node.children) do
        local dep = node.le_self
        -- Check if we're looping over or something similar, detect cycle and try to break it, error out if it can't be done
        if ctx:checkForLoop(dep.inlying_recipe) then
            return "loop_detected", ctx:getCurNodeIndex() + 1
        end

        local inner = dep.inlying_recipe
        local dep_needed_quantity = needed_quantity * dep.input_multiplier

        local current_int_count = inv.how_many_internal(inner.output.lable, inner.output.name)
        if current_int_count >= dep_needed_quantity then goto continue end

        -- if there is enough in external storage return "execute" + with a command to do logistics
        -- else recurse into our dependency tree by ways of searching inside ti for this output

        local needed_to_transfer = dep_needed_quantity - current_int_count
        local min_quant = math.min(needed_to_transfer / 2, 12) -- might need to be optimised in the future
        local pinv = inv.get_nearest_external_inv(
            inner.output.lable, inner.output.name, min_quant, needed_to_transfer
        )

        -- It is complicated to chain these things together without assembling complicated algorithms,
        -- so we'll go with the simpler and least efficient route of going to the first thing we're missing
        if pinv ~= nil then
            local item_table = {inner.output.lable, inner.output.name, needed_to_transfer}
            local to_transfer = {item_table} -- table of items
            local inner = LogisticTransfer:new(pinv, "self", to_transfer)
            local logistic_nav = {inner.doTheThing, inner} -- command gets "completed" by caller
            mode = "execute"
            dep_found = logistic_nav

            print(comms.robot_send("debug", "solve_tree:search, decided to execute logistic_nav"))
            break
        end

        if true then
            local print_lable = inner.output.lable
            local print_name = inner.output.name
            if print_lable == nil then print_lable = "nil" end
            if print_name == nil then print_name = "nil" end

            print(comms.robot_send("debug", "depth_recurse in solve_tree:search -- " .. debug_name
                                    .. " || not enough: " .. print_lable .. ", " .. print_name))
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

function solve_tree.interpretSelection(ctx, needed_quantity, meta_type)
    local mode, dep_found = solve_tree.selectDependency(ctx, needed_quantity, meta_type)

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
    -- extra logic necessary becasue HEAD is always a raw recipe and doesn't need to be unwrapped
    local latest_node = ctx:getLatestNode()

    local parent_dependency = latest_node.le_self
    local parent_recipe
    if parent_dependency.inlying_recipe ~= nil then
        parent_recipe = parent_dependency.inlying_recipe
    else
        parent_recipe = parent_dependency
    end

    if parent_recipe.meta_type == "crafting_table" then
        if parent_recipe.dependencies == nil then error(comms.robot_send("fatal", "This cannot be for a crafting_table")) end
        return solve_tree.interpretSelection(ctx, needed_quantity, parent_recipe.meta_type)

    elseif parent_recipe.meta_type == "gathering" then
        -- In the case of a gathering that is part of a dependency-tree rather than as a global dependency that
        -- interacts with goals directly, the pie will be fingered at dependency creation time, this is to
        -- say that we set up the recipe.mechanism.output there when we define the dependency!

        local gathering = parent_recipe.mechanism
        return "all_good", nil
        -- Attention: no longer auto_generating tool_dependencies because fuck that, that conflicts with
        -- the layout system we desire to actually fucking use, what the fuck

        -- local tool_dependency = gathering:generateToolDependency(gathering.tool, gathering.level)
        -- if tool_dependency == nil then return "all_good", nil end

        -- we fake it!
        -- ctx:addDep(tool_dependency)
        -- return solve_tree.interpretSelection(ctx, needed_quantity, parent_recipe.meta_type)

    elseif parent_recipe.meta_type == "building_user" then
        -- Check if the building was built
        local name = parent_recipe.mechanism.bd_name
        local buildings = map.get_buildings(name)
        if buildings == nil or #buildings == 0 then return "non_fatal_error", "building" end


        for _, build in ipairs(buildings) do
            -- I will assume that the smelting goals only have 1 dependency
            local one_dep = parent_recipe.dependencies[1]
            local one_recipe = one_dep.inlying_recipe

            local dep_quantity = math.ceil(one_dep.input_multiplier * needed_quantity)
            local check_table = {one_recipe.output, dep_quantity}
            local result, b_check_extra = build:runBuildCheck(check_table)

            if result == "all_good" then
                local mode, dep_found = solve_tree.interpretSelection(ctx, needed_quantity, parent_recipe.meta_type)
                if mode ~= "all_good" then return mode, dep_found end

                return "all_good", build

            elseif result == "wait" then
                -- TODO actually wait kekekekekeekek
                -- REASON_WAIT_LIST:checkAndAdd(build) -- building was sent to waiting list, cron will the re-rerun checks
                                                    -- if we still need to use the building and it becomes avaliable use it
                                                    -- otherwise remove it form list (TODO)
                goto continue

           elseif result == "execute" then
                return result, b_check_extra
           elseif result == "replace" then
                return result, b_check_extra
           else
                if result == nil then result = "nil" end
                error(comms.robot_send("error", "bad result in building_thing search: " .. result))
           end

           ::continue::
        end -- forloop end

        return "force_wait" -- for now, since breath doesn't work
        -- return "breath" -- At last, least priority, we look into the other branches if possible
                        -- AKA: This is blocked right now, please go down another sister branch
                        -- But if you Optional into a breath and you run out of things, you are supposed to report fail
    else
        error(comms.robot_send("fatal", "meta_type was badly set somewhere!"))
    end
end

return solve_tree
