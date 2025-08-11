-- luacheck: globals HOME_CHUNK AUTOMATIC_EXPAND_ORE

local comms = require("comms")

local deep_copy = require("deep_copy")

-- local interactive = require("interactive")
local keep_alive = require("keep_alive")
local map = require("nav_module.map_obj")
local nav = require("nav_module.nav_obj")

---- Global State -----------
-- TODO - Implement save/load for this global state :( (IT HURRRRTSSSS)

local state_list = { -- lists states currently in memory

}

-- Ore center - A chunk that could potentially contain an orevein.
-- Any chunk that satisfies (abs(ChunkX) % 3 == 1, abs(ChunkZ) % 3 == 1).
-- Examples are (1,-1) (22,19) (-124,67) - using chunk X/Z.
--
-- abs(chunk) % 3 = 1
local function get_next_ore_chunk() -- take the last chunk registered
    if #state_list == 0 then
        return {1, 1}
    end

    -- this will not be the mathematically cleanest (or most efficient) algorithm, but I don't care
    local selected_chunk
    local x1, x2, z1, z2
    x1 = 1; z1 = 1
    x2 = -1; z2 = -1
    while true do -- x level
        while true do -- z level
            local positive_fail = false; local negative_fail = false
            local pn_fail = false; local np_fail = false
            for _, state in ipairs(state_list) do
                if x1 == state.chunk[1] and z1 == state.chunk[2] then positive_fail = true end
                if x2 == state.chunk[1] and z2 == state.chunk[2] then negative_fail = true end
                if x1 == state.chunk[1] and z2 == state.chunk[2] then pn_fail = true end
                if x2 == state.chunk[1] and z1 == state.chunk[2] then np_fail = true end
                if positive_fail and negative_fail and pn_fail and np_fail then break end
            end
            if not positive_fail then selected_chunk = {x1, z1} end
            if not negative_fail then selected_chunk = {x2, z2} end
            if not pn_fail then selected_chunk = {x1, z2} end
            if not np_fail then selected_chunk = {x2, z1} end
            -- else we'll continue incrementing stuff

            if z1 + 3 > x1 then break end
            z1 = z1 + 3; z2 = z2 - 3;
        end
        x1 = x1 + 3; x2 = x2 - 3;
        if x1 > AUTOMATIC_EXPAND_ORE or selected_chunk ~= nil then break end
    end

    if selected_chunk == nil or map.get_chunk(selected_chunk) == nil then -- invalid chunk in search
        print(comms.robot_send("error", "automatic ore chunk expansion returned a invalid chunk"))
        return nil
    end

    local home_chunk = HOME_CHUNK
    local dist = math.abs(home_chunk[1] - selected_chunk[1]) + math.abs(home_chunk[2] - selected_chunk[2])
    if dist > AUTOMATIC_EXPAND_ORE then -- fail quietly, because otherwise it is to bothersome to code for now
        return nil
    end

    return selected_chunk
end

-- Why is my code always so polymorphic :sob:
local function get_ore_chunk(wanted_ore)
    local good_state_list = {}
    for _, state in ipairs(state_list) do
        if state.wanted_ore == wanted_ore and state.chunk ~= nil and not state.cleared then
            table.insert(good_state_list, state)
        end
    end

    if #good_state_list > 0 then
        local cur_chunk = nav.get_chunk()

        local best_dist = 1001 -- distance in chunks
        local closest_good_state

        for _, state in ipairs(good_state_list) do
            local dist = math.abs(cur_chunk[1] - state.chunk[1]) + math.abs(cur_chunk[2] - state.chunk[2])
            if dist < best_dist then
                best_dist = dist
                closest_good_state = state
            end
        end

        return closest_good_state, "state"       -- we know this chunk as what we're looking for ([1] is a state)
    end

    return get_next_ore_chunk(), "chunk_coords"  -- we don't know if this has what we're looking for ([1] is a chunk)
end

---- Not Global State -------

-- Ideally we'd "feather" out of the chunk a little bit, because of the way ore chunks are, they tend to "spread" into
-- other chunks somewhat, but that justs makes the code more complicated and I don't want that
local el_state = {
    i_id = nil,
    priority = 0,

    not_enough_fuel_reported = false,
    wanted_ore = nil,   -- {lable, name} ahh table plz, needs to be properly initialised by caller :)
    chunk_ore = nil,
    chunk = nil,        -- Only 1 state per chunk please, careful when storing state :)
                        -- Terrifying - the el state for "gather" actually contains a chunk-ref rather than just coords
    cleared = false,
    step = 0,
}

local function automatic(state, mechanism)
    if state.step == 0 then -- Basic state loading
        state.wanted_ore = deep_copy.copy(mechanism.output)
        state.step = 1
        return "Nope", nil
    elseif state.step == 1 then -- State selector
        -- no manual mode for this mfo because I see no reason why, so just deal with it
        local result, r_type = get_ore_chunk(state.wanted_ore)
        if r_type == "chunk_coords" then
            state.chunk = result
            state.step = 2
        elseif r_type == "state" then -- Now this is super fun, wow nothing will go wrong
            for k, v in pairs(result) do -- updates fields so that ref doesn't change externaly
                state[k] = v
            end
        else
            error(comms.robot_send("fatal", "Wowsers, invalid r_type :) yay"))
        end

        return "Nope", nil
    elseif state.step == 2 then -- move to chunk
        local block_move_potential = keep_alive.possible_round_trip_distance(0, true)
        local chunk_move_potential = math.floor(block_move_potential / 16.0)
        local dist = math.abs(nav.get_chunk() - state.chunk)
        local dist_diff = chunk_move_potential - dist
        if dist_diff < 0 then
            if not state.not_enough_fuel_reported then
                print(comms.robot_send("warning", "Distance diff not good in mine ore, diff was: " .. dist_diff))
                state.not_enough_fuel_reported = true
            end
            return "Nope", 1
        end
        state.enough_fuel_reported = false

        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(deep_copy.copy(state.chunk))
        end

        local is_finished = nav.navigate_chunk("surface")
        if is_finished then
            state.step = 3
        end
        return "Nope", nil
    elseif state.step == 3 then -- I think we should build the shaft in a pre-determined location (rel: 0, 0)
        local cur_rel = nav.get_rel()
        if cur_rel[1] - 0 > 0 then nav.surface_move("west"); return "Nope", nil end
        if cur_rel[2] - 0 > 0 then nav.surface_move("north"); return "Nope", nil end
        -- now we know for sure that we are on 0, 0

        state.step = 4
        return "Nope", nil
    elseif state.step == 4 then -- now we dig a shaft
    else
        error(comms.robot_send("fatal", "Bad State ore-gathering"))
    end

    return "Nope", nil
end

local function ore_mining(arguments)
    local mechanism = arguments[1]
    local state = arguments[2]
    local up_to_quantity = arguments[3] -- use for interrupts if needed etc etc
    local lock = arguments[4]

    if state.interrupt == true then
        return {state.priority, mechanism.algorithm, table.unpack(arguments)}
    end
    if state.mode == "automatic" then
        local finish_state, new_prio = automatic(state, mechanism)
        if finish_state == "Nope" then -- I think everything is getting passed as ref so it's ok to pass arguments back in
            local command_prio = state.priority

            -- No permanent changes to prio here
            if new_prio ~= nil then
                command_prio = new_prio
            end

            -- return a priority given back by "automatic" OR default - mechanism.priority
            return {command_prio, mechanism.algorithm, table.unpack(arguments)}
        elseif finish_state == "Interrupt" then -- For now this is just the same as finish
            print(comms.robot_send("debug", "interrupted ore_mining routine"))
            lock[1] = 2
            return nil
        elseif finish_state == "Close" then
            print(comms.robot_send("debug", "finished ore_mining routine"))
            lock[1] = 2 -- "Unlock" the lock (will be unlocked based on "do_once"'s value
            return nil
        else
            error(comms.robot_send("fatal", "Bad State in Ore Mining"))
        end
    elseif state.mode == "manual" then
        error(comms.robot_send("fatal", "TODO ore_mining, manual mode not implmented"))
    else
        error(comms.robot_send("fatal", "ore_mining impossible mode selected"))
    end
end

-- TODO, hook up, and modify MetaRecipies appropriatly to use this correctly
local ore_gathering = MetaRecipe:newGathering("Ore", "Ore", 0, ore_mining, el_state)
return ore_gathering
