local geolyzer = require("geolyzer_wrapper")
local sides_api = require("sides")
local robot = require("robot")

local comms = require("comms")
local deep_copy = require("deep_copy")
-- local interactive = require("interactive")

local nav = require("nav_module.nav_obj")
-- local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")
local generic = require("reasoning.recipes.sweep_gathering_general")

local MetaRecipe = require("reasoning.MetaRecipe")


local el_state = {
    chunk = nil,
    i_id = nil,

    sub_set = {"gravel"},
    interrupt = false,
    mode = "automatic", -- will search for areas tagged with "gather"
                        -- otherwise it will use the interactive system
    step = 1
}

local function check_subset(state)
    local block_below = geolyzer.simple_return(sides_api.down)
    if state.sub_set == nil then
        print(comms.robot_send("warning", "check_subste sub_set is empty! stone_age:gathering01"))
        return false
    elseif type(state.sub_set) ~= "table" then
        print(comms.robot_send("warning", "check_subste sub_set is not table! stone_age:gathering01"))
        return false
    end

    for _, block_name in ipairs(state.sub_set) do
        if geolyzer.sub_compare(block_name, "naive_contains", block_below) 
            and not geolyzer.sub_compare("stone", "naive_contains", block_below) -- temporrary additions, I guess
            and not geolyzer.sub_compare("hard", "naive_contains", block_below)
            and not geolyzer.sub_compare("GravelOre", "naive_contains", block_below) -- thats the name TC tec.
        then
            return true
        end
    end
    return false
end

local function something_added()
    inv.maybe_something_added_to_inv(nil, "any:grass")
    inv.maybe_something_added_to_inv("Clay", nil)
    inv.maybe_something_added_to_inv("Sand", nil)
    inv.maybe_something_added_to_inv("Red Sand", nil)
    inv.maybe_something_added_to_inv("Gravel", nil)
end

local function work_stroke(state)
    local break_result = inv.smart_swing("shovel", "down", 0, something_added) 
    if not break_result then
        print(comms.robot_send("warning", "surface_resource_sweep, I thought the block was a block we \z
                                wanted, but in the end I was unable to break it, worrying"))
        return false
    end

    nav.debug_move("down", 1, 0)
    local interesting_block = check_subset(state)
    if interesting_block == true then
        return true
    end
    return false
end


local function automatic(state)
    return generic.automatic("gather01", state, "surface_depleted", "gather", check_subset, work_stroke, nil)
end

local function surface_resource_sweep(arguments)
    local mechanism = arguments[1]
    local state = arguments[2]
    local up_to_quantity = arguments[3] -- use for interrupts if needed etc etc, but currently function is not interruptable
    local lock = arguments[4]

    if state.interrupt == true then
        return {state.priority, mechanism.algorithm, table.unpack(arguments)}
    end
    if state.mode == "automatic" then
        local is_finished, new_prio = automatic(state)
        if not is_finished then -- I think everything is getting passed as ref so it's ok to pass arguments back in
            local command_prio = state.priority

            -- Detects if we want a permanent or impermanent change in prio
            if new_prio ~= nil then
                if new_prio > 0 then state.priority = new_prio
                else command_prio = new_prio end
            end

            -- return a priority given back by "automatic" OR default - state.priority
            return {command_prio, mechanism.algorithm, table.unpack(arguments)}
        else
            print(comms.robot_send("debug", "finished gathering01 routine"))
            lock[1] = 2 -- "Unlock" the lock (will be unlocked based on "do_once"'s value
            return nil
        end
    elseif state.mode == "manual" then
        error(comms.robot_send("fatal", "TODO surface_resource_sweep, manual mode not implmented"))
    else
        error(comms.robot_send("fatal", "surface_resource_sweep impossible mode selected"))
    end

end

local gravel_only = MetaRecipe:newGathering("Gravel", "shovel", 0, surface_resource_sweep, el_state)

local all_table = {"gravel", "sand", "clay"}
el_state.sub_set = all_table

-- hopefully this works!
local all_table = {
    {lable = "Gravel", name = "nil"},
    {lable = "Sand", name = "nil"},
    {lable = "Clay", name = "minecraft:clay_ball"},
}
local all_gather = MetaRecipe:newGathering(all_table, "shovel", 0, surface_resource_sweep, el_state)


return gravel_only, all_gather
