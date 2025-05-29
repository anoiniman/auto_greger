local geolyzer = require("geolyzer_wrapper")
local sides_api = require("sides")

local comms = require("comms")
local deep_copy = require("deep_copy")

local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")

local MetaRecipe = require("reasoning.MetaRecipe")


local el_state = {
    chunk = nil,

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
        if geolyzer.sub_compare(block_name, "naive_contains", block_below) then
            return true
        end
    end
    return false
end

local function automatic(state) -- hopefully I don't have to make this global
    if state.step == 1 then -- determine what_chunk to sploink
        local area = map.get_area("gather")
        if area == nil then -- we'll have to wait :)
            return
        end

        local chunk_to_act_upon
        for _, chunk in ipairs(area.chunks) do
            if chunk.mark == nil or not chunk:checkMarks("surface_depleted") then
                chunk_to_act_upon = chunk
                break
            end
        end

        if chunk_to_act_upon == nil then return end -- wait more

        state.chunk = chunk_to_act_upon
        state.step = 2

    elseif state.step == 2 then
        if not nav.is_setup_navigate_chunk() then
            local chunk_coords = {state.chunk.x, state.chunk.z}
            nav.setup_navigate_chunk(chunk_coords)
        end

        local is_finished = nav.navigate_chunk("surface")
        if is_finished then
            state.step = 3
        end
    elseif state.step == 3 then
        if nav.is_sweep_setup() then
            print(comms.robot_send("error", "surface_resource_sweep: sweep was setup when it shouldn't have been \z
            did it terminate wrongly?"))
        end

        if not nav.is_sweep_setup() then
            nav.setup_sweep()
        end
        local sweep_result = nav.sweep(true) -- goes forward one block

        if sweep_result == -1 then
            state.chunk:addMark("surface_depleted")
            return true
        elseif sweep_result == 0 then
            -- careful with hardened clay
            local interesting_block = check_subset(state)
            if interesting_block == true then
                state.step = 4
            end
        elseif sweep_result == 1 then
            -- makes sense for surface move but maybe not so much for other storts of move
            error(comms.robot_send("fatal", "not able to deal with a failed sweep for now"))
        else
            error(comms.robot_send("fatal", "surface_resource_sweep sweep_result is not expected"))
        end
    elseif state.step == 4 then -- there is a good block below us
        -- We don't really care if it fails to equip tool since we can mine the blocks with our "hands" anyway
        local _ = inv.equip_tool("shovel", 0)
        local break_result = inv.blind_swing_down()
        if not break_result then
            print(comms.robot_send("warning", "surface_resource_sweep, I thought the block was a block we \z
                                    wanted, but in the end I was unable to break it, worrying"))
        end

        nav.debug_move("down", 1, 0)
        local interesting_block = check_subset(state)
        if interesting_block == true then
            -- luacheck: ignore
            --state.step = 4
        else
            state.step = 3
        end
    end
    return false
end

local function surface_resource_sweep(arguments)
    local mechanism = arguments[1]
    local lock = arguments[2]

    local state = mechanism.state
    if state.interrupt == true then
        return {mechanism.priority, mechanism.algorithm, mechanism}
    end
    if state.mode == "automatic" then
        local is_finished = automatic(state)
        if not is_finished then
            return {mechanism.priority, mechanism.algorithm, mechanism}
        else
            --lock[1] = 0 -- Unlock the lock
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

local all_table = {"Gravel", "Sand", "Clay"}
el_state.sub_set = deep_copy.copy(all_table, ipairs)
local all_gather = MetaRecipe:newGathering(all_table, "shovel", 0, surface_resource_sweep, el_state)


return gravel_only, all_gather
