local geolyzer = require("geolyzer_wrapper")
local sides_api = require("sides")

local comms = require("comms")
-- local deep_copy = require("deep_copy")
-- local interactive = require("interactive")

local robot = require("robot")
local component = require("component")
local os = require("os")

local nav = require("nav_module.nav_obj")
-- local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")
local generic = require("reasoning.recipes.sweep_gathering_general")

local MetaRecipe = require("reasoning.MetaRecipe")

local sucker = component.getPrimary("tractor_beam")


local el_state = {
    chunk = nil,
    i_id = nil,

    sub_set = {"log"},
    interrupt = false,
    mode = "automatic", -- will search for areas tagged with "gather"
                        -- otherwise it will use the interactive system
    step = 1
}

local function check_subset(state, do_up) -- (do up is optional and abuses polymorphism)
    if do_up == nil then do_up = false end

    local side
    if do_up then side = sides_api.up
    else side = sides_api.forward end

    local block_to_check = geolyzer.simple_return(side)

    if state.sub_set == nil then
        print(comms.robot_send("warning", "check_subste sub_set is empty! stone_age:gatheringtree"))
        return false
    elseif type(state.sub_set) ~= "table" then
        print(comms.robot_send("warning", "check_subste sub_set is not table! stone_age:gatheringtree"))
        return false
    end

    for _, block_name in ipairs(state.sub_set) do
        if geolyzer.sub_compare(block_name, "naive_contains", block_to_check) then
            return true
        end
    end
    return false
end

local function come_down()
    local _
    local moved_down = true
    while moved_down do
        moved_down, _ = nav.debug_move("down", 1, 0)
    end -- if we leave the loop we assume we've hit the ground
end

-- luacheck: push ignore err
local function climb_loop(state)
    local result, err
    local block_intersting = true
    while block_intersting do
        result = robot.swingUp() -- make sure this returns false on hitting air
        if not result then break end
        inv.maybe_something_added_to_inv()

        result, err = nav.debug_move("up", 1, 0)
        if not result then break end
        block_intersting  = check_subset(state, true)
    end
end
-- luacheck: pop


local function work_stroke(state)
    -- We don't really care if it fails to equip tool since we can mine the blocks with our "hands" anyway
    local _ = inv.equip_tool("axe", 0)
    local break_result, _ = robot.swing() -- yurp
    inv.maybe_something_added_to_inv()

    if not break_result then
        print(comms.robot_send("warning", "surface_resource_sweep, I thought the block was a block we \z
                                wanted, but in the end I was unable to break it, worrying"))
        return false -- this won't bite us in the ass
    end

    nav.force_forward()
    climb_loop(state)
    come_down()
    os.sleep(10) -- wait for leaves to decay
    sucker.suck() -- assuming all this goes into first slot, otherwise we need to change the inv code
    inv.maybe_something_added_to_inv()

    return false
end

local deplete_mark = "tree_depleted"

local function automatic(state)
    return generic.automatic("gather_tree", state, deplete_mark, check_subset, work_stroke, nil)
end

local function surface_resource_sweep(arguments)
    local mechanism = arguments[1]
    local state = arguments[2]
    local up_to_quantity = arguments[3] -- will be used to interrupt eventually
    local lock = arguments[4]

    if state.interrupt == true then
        return {mechanism.priority, mechanism.algorithm, mechanism}
    end
    if state.mode == "automatic" then
        local is_finished, new_prio = automatic(state)
        if not is_finished then -- I think everything is getting passed as ref so it's ok to pass arguments back in
            local prio_to_return = mechanism.priority
            if new_prio ~= nil then prio_to_return = new_prio end

            -- return a priority given back by "automatic" OR default - mechanism.priority
            return {prio_to_return, mechanism.algorithm, table.unpack(arguments)}
        else
            state.chunk:addMark(deplete_mark) -- Will mark chunk such that we don't try to gather it again
            lock[1] = 2 -- "Unlock" the lock (will be unlocked based on "do_once"'s value
            return nil
        end
    elseif state.mode == "manual" then
        error(comms.robot_send("fatal", "TODO surface_resource_sweep, manual mode not implmented"))
    else
        error(comms.robot_send("fatal", "surface_resource_sweep impossible mode selected"))
    end

end

local log_recipe = MetaRecipe:newGathering("log", "shovel", 0, surface_resource_sweep, el_state, "name_naive_contains")
return log_recipe
