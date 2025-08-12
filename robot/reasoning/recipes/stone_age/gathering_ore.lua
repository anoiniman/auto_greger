-- luacheck: globals HOME_CHUNK AUTOMATIC_EXPAND_ORE

local sides_api = require("sides")
local robot = require("robot")

local comms = require("comms")
local deep_copy = require("deep_copy")

-- local interactive = require("interactive")
local keep_alive = require("keep_alive")
local geolyzer = require("geolyzer_wrapper")

local map = require("nav_module.map_obj")
local nav = require("nav_module.nav_obj")
local elevator = require("nav_module.simple_elevator")

local inv = require("inventory.inv_obj")
local item_bucket = require("inventory.item_buckets")

local MetaRecipe = require("reasoning.MetaRecipe")

------------------------------------
-- el-state is not global but I saw myself forced to forward declare it for reasons

-- Ideally we'd "feather" out of the chunk a little bit, because of the way ore chunks are, they tend to "spread" into
-- other chunks somewhat, but that justs makes the code more complicated and I don't want that
local el_state = {
    -- i_id = nil,
    priority = 0,

    starting_height = nil,
    not_enough_fuel_reported = false,

    wanted_ore = nil,   -- {lable, name} ahh table plz, needs to be properly initialised by caller :)
    chunk_ore = nil,
    needed_tool_level = 0,

    chunk = nil,        -- Only 1 state per chunk please, careful when storing state :)
                        -- Terrifying - the el state for "gather" actually contains a chunk-ref rather than just coords
    shaft_dug = false,
    layer_done = false,
    cleared = false,

    latest_rel_pos = nil,
    latest_reverse = nil,
    latest_height = nil,

    step = 0,
}
--------------------------------------

---- Global State -----------
-- TODO - Implement save/load for this global state :( (IT HURRRRTSSSS), but I think the objects are straight serialiseable
-- so maybe we're just in luck? No references to handle! :)

local state_list = { -- lists states currently in memory

}

-- adds state into list if state isn't already in the list :)
-- prints error message if fail because it is unexpected that we try to add something that already exists
-- due to way in the code exactly we try and add things to the list
local function add_to_state_list(state_to_add)
    local in_list = false
    for _, state in ipairs(state_list) do
        if state.chunk[1] == state_to_add.chunk[1] and state.chunk[2] == state_to_add.chunk[2] then
            in_list = true
            break
        end
    end
    if in_list then
        print(comms.robot_send("error", "Ore Mining state already in list owsers!"))
        return
    end

    table.insert(state_list, state_to_add)
end

-- Ore center - A chunk that could potentially contain an orevein.
-- Any chunk that satisfies (abs(ChunkX) % 3 == 1, abs(ChunkZ) % 3 == 1).
-- Examples are (1,-1) (22,19) (-124,67) - using chunk X/Z.
--
-- abs(chunk) % 3 = 1
local function get_next_ore_chunk(wanted_ore) -- take the last chunk registered
    if #state_list == 0 then
        return {1, 1}
    end

    -- this will not be the mathematically cleanest (or most efficient) algorithm, but I don't care
    local selected_chunk
    local x1, x2, z1, z2
    x1 = 1; x2 = -1;
    while true do -- x level
        z1 = 1; z2 = -1;
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

    local function nearest_mult3(raw_offset)
        local raw_div = raw_offset / 3
        local mod = raw_offset % 3

        if mod == 0 or mod == 2 then -- roundup
            if raw_offset >= 0 then -- (for obivous reasons, thang needs to be inverted for negative numbers)
                return math.ceil(raw_div) * 3
            else
                return math.floor(raw_div) * 3
            end
        else -- rounddown
            if raw_offset >= 0 then
                return math.floor(raw_div) * 3
            else
                return math.ceil(raw_div) * 3
            end
        end
    end

    local home_chunk = HOME_CHUNK
    local dist = math.abs(home_chunk[1] - selected_chunk[1]) + math.abs(home_chunk[2] - selected_chunk[2])
    if dist > AUTOMATIC_EXPAND_ORE then -- fail quietly, because otherwise it is to bothersome to code for now
        return nil
    end

    local x_offset = nearest_mult3(home_chunk[1])
    local z_offset = nearest_mult3(home_chunk[2])
    selected_chunk[1] = selected_chunk[1] + x_offset
    selected_chunk[2] = selected_chunk[2] + z_offset

    local virtual_chunk = map.get_chunk(selected_chunk)
    if selected_chunk == nil or virtual_chunk == nil then -- invalid chunk in search
        print(comms.robot_send("error", "automatic ore chunk expansion returned a invalid chunk"))
        return nil
    end

    -- TODO -> DON'T HARD-CODE THIS (welp, it'll be fine for now.... I hope)
    if virtual_chunk.chunk.parent_area ~= nil and virtual_chunk.chunk.parent_area.name == "home" then
        -- we should not dig holes in our base automatically for reasons that should be obvious
        local fake_state = deep_copy.copy(el_state, pairs)
        fake_state.wanted_ore = wanted_ore
        fake_state.chunk = selected_chunk
        table.insert(state_list, fake_state)

        return get_next_ore_chunk(wanted_ore)  -- hopefully I don't have to tail optimise this crap :sob:
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

    return get_next_ore_chunk(wanted_ore), "chunk_coords"  -- we don't know if this has what we're looking for ([1] is a chunk)
end

-- Checks all possible things that might've been added in exploring underground things
local function maybe_something_added()
    inv.maybe_something_added_to_inv(nil, "any:building")
    inv.maybe_something_added_to_inv("Dirt", nil)
    inv.maybe_something_added_to_inv("Gravel", nil)
end

local function set_state21(state, warn)
    if warn == nil then warn = nil
    else warn = tostring(warn) end

    state.latest_rel_pos = nav.get_rel()
    state.latest_height = nav.get_height()
    state.step = 21

    if warn ~= nil then
        print(comms.robot_send("warning", "We set 22 in bad circunstances: " .. warn .. "\n" .. debug.traceback()))
    end
end

---- Not Global State -------

-- move_func will either be a nav.sweep(false), or a nav.force_forward()
local function deal_with_the_ladder(state, move_func)
    local result = inv.equip_tool("pickaxe", state.needed_tool_level)
    if not result then set_state21(state); return "All_Good", nil end
    robot.swing()
    maybe_something_added()

    local result = move_func(false)
    local watch_dog = 0
    while result == 1 do -- sweep fail state attempt to recover
        os.sleep(2)
        local s_result = move_func(false)
        if s_result == 0 then break end
        if watch_dog >= 12 then
            state.step = 31
            print(comms.robot_send("error", "Ore Mining, got le stuck during le critical moment :sob:"))
            return "All_Good", nil
        end
    end
    -- Now you have to place back the block behind you! So that the shaft-ladder continues it's existance
    nav.change_orientation(nav.get_opposite_orientation())
    local result = inv.place_block("front", {"any:building", "any:grass"}, "name_table")
    if not result then
        error(comms.robot_send("fatal", "I really don't know how to recover from this, sorry"))
    end

    return "All_Good", nil
end


-- TODO: run some periodic power checks to make sure we can get back home, and interrupt if we start nearing the limit

-- TODO: priority better be locked to 100, (exceptions may apply)
-- because we always need to use special methods to leave the mine,
-- we can't just suddenly start doing something else
local function automatic(state, mechanism)
    print(comms.robot_send("debug", "Ore Mining, state.step = " .. state.step))

    -- Sanity Check
    if item_bucket.normalise_ore(state.wanted_ore) == "Unrecognised Ore" then
        if state.wanted_ore == nil then state.wanted_ore = "Nil" end
        error(comms.robot_send("fatal",
            string.format("We are trying to obtain an un-recognised ore, check you definitions: \"%s\"", state.wanted_ore)
        ))
    end


    -- TODO summon logistic storing unneeded stuff (we'll have load outs n' shit)
    if state.step == 0 then -- Basic state loading
        state.wanted_ore = deep_copy.copy(mechanism.output)
        state.step = 1
        return "All_Good", nil
    elseif state.step == 1 then -- State selector
        -- no manual mode for this mfo because I see no reason why, so just deal with it
        local result, r_type = get_ore_chunk(state.wanted_ore)
        if r_type == "chunk_coords" then
            add_to_state_list(state)    -- added to list here
            state.chunk = result
            state.step = 2
        elseif r_type == "state" then -- Now this is super fun, wow nothing will go wrong
            for k, v in pairs(result) do -- updates fields so that ref doesn't change externaly
                state[k] = v
            end
        else
            error(comms.robot_send("fatal", "Wowsers, invalid r_type :) yay"))
        end

        return "All_Good", nil
    elseif state.step == 2 then -- move to chunk
        local block_move_potential = keep_alive.possible_round_trip_distance(0, true)
        local chunk_move_potential = math.floor(block_move_potential / 16.0)

        local cur_chunk = nav.get_chunk(); local home_chunk = HOME_CHUNK
        local home_dist = math.abs(home_chunk[1] - cur_chunk[1]) + math.abs(home_chunk[2] - cur_chunk[2])
        local dist = math.abs(state.chunk[1] - cur_chunk[1]) + math.abs(state.chunk[2] - cur_chunk[2])

        local dist_diff = chunk_move_potential - dist - home_dist
        if dist_diff < 0 then
            if not state.not_enough_fuel_reported then
                print(comms.robot_send("warning", "Distance diff not good in mine ore, diff was: " .. dist_diff))
                state.not_enough_fuel_reported = true
            end
            return "All_Good", 1
        end
        state.enough_fuel_reported = false

        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(deep_copy.copy(state.chunk))
        end

        local is_finished = nav.navigate_chunk("surface")
        if is_finished then
            state.step = 3
        end

        return "All_Good", nil
    elseif state.step == 3 then -- I think we should build the shaft in a pre-determined location (rel: 7, 7)
        local cur_rel = nav.get_rel()
        if cur_rel[1] - 7 > 0 then nav.surface_move("west"); return "All_Good", nil
        elseif cur_rel[1] - 7 < 0 then nav.surface_move("east"); return "All_Good", nil end
        if cur_rel[2] - 7 > 0 then nav.surface_move("north"); return "All_Good", nil
        elseif cur_rel[2] - 7 < 0 then nav.surface_move("south"); return "All_Good", nil end
        -- now we know for sure that we are on 7, 7
        -- the shaft shall always be on 7,8, thank you!, so when the robot is in 8,8 or whatever it places a block back

        state.step = 4
        return "All_Good", nil
    elseif state.step == 4 then -- now we dig a shaft (remember to protect the shaft wall at all times :))
        -- ATTENTION, IF YOU ALREADY GOT A SHAFT DUG YOU NEED TO GO THROUGH A DIFFERENT STEP NUMBER

        -- this is literally the worst way to do this, but also the easieast so whatever
        local inv_snapshot = deep_copy.copy(inv.virtual_inventory, pairs)
        local result = elevator.be_an_elevator(0, true, "south", "pickaxe") -- way say: dig till zero, cause we're waiting to hit ore!

        if not result then -- This means we weren't able to break the block below us, and we need to handle this fact
            local analysis = geolyzer.simple_return()
            state.needed_tool_level = analysis.harvestLevel
            state.step = 21      -- step 21 will get us out and revert to: 2, cause we'll just have to try again
            return "All_Good", nil
        end

        local updated_inv = inv.virtual_inventory
        local diff_tbl = inv_snapshot:compareWithLedger(updated_inv)

        for _, diff in ipairs(diff_tbl) do
            if diff.lable == state.wanted_ore then
                state.chunk_ore, state.needed_tool_level = item_bucket.normalise_ore(diff.lable)
                state.step = 5 -- Continue down the "good path"

                local result, _ = inv.equip_tool("pickaxe", state.needed_tool_level) -- get ourselves 1 block further down
                if not result then
                    print(comms.robot_send("error", "Failed to equip pickaxe with needed level in mining: " .. state.needed_tool_level))
                    state.step = 11
                    return "All_Good", nil
                end

                result, _ = robot.swingDown()
                if not result then
                    print(comms.robot_send("error", "Failed to mine 01"))
                    state.step = 11
                    return "All_Good", nil
                end
                maybe_something_added() -- Important
                state.starting_height = nav.get_height()

                return "All_Good", nil
            elseif diff.name == "gregtech:raw_ore" then -- and it is not the wanted ore
                local analysis = geolyzer.simple_return(sides_api.bottom)
                state.needed_tool_level = analysis.harvestLevel
                state.chunk_ore = "Unmined"
                state.step = 11 -- Swap to bad path 1

                return "All_Good", nil
            end
        end

        local cur_height = nav.get_height()
        if cur_height <= 3 then
            print(comms.robot_send("error", "We went all the way down to the bedrock, yet....."))

            state.chunk_ore = "Empty"
            state.step = 21
            return "All_Good", nil
        end

        return "All_Good", nil -- keep le digging
    elseif state.step == 5 then -- now we go to 0,0!
        -- swing first, axe (ha) questions later
        local result, _ = inv.equip_tool("pickaxe", state.needed_tool_level)
        if not result then set_state21(state); return "All_Good", nil end

        local function s5_move(orient)
            nav.change_orientation(orient)
            result, _ = robot.swing()
            if not result then set_state21(state, "swing failed"); return false end

            maybe_something_added()

            local err
            result, err = nav.force_forward()
            if not result then
                if err ~= "impossible" then
                    set_state21(state, "err: " .. err)
                    return false
                end
                print(comms.robot_send("error", "this mine is not stable, and I don't care to make it stable, we're bailing \z
                                        and setting its clear state to: \"clear\", maybe in the future I do it right rn don't care"))
                state.step = 31
                return true
            end

            return true
        end

        local cur_rel = nav.get_rel()
        if cur_rel[1] > 0 then
            local result = s5_move("north")
            return "All_Good", nil
        end
        if cur_rel[2] > 0 then
            local result = s5_move("west")
            return "All_Good", nil
        end

        -- Great, now we are on 0,0!
        state.step = 6
        return "All_Good", nil
    elseif state.step == 6 then -- now we crawl around in the mud! (remember we have rock above us and below, hopefully)
        -- we'll keep sweeping until we are ~6-7 blocks below our starting point, I think that is the sweet spot

        -- First we have already setup our sweep
        if not nav.is_sweep_setup() then
            -- Then we check if we're going to sweep from the begining, or if we need to resume it from somewhere
            if state.latest_rel_pos == nil then
                nav.setup_sweep()
            else
                nav.resume_sweep(state.latest_rel_pos, state.latest_reverse)
            end
        end

        local result = inv.equip_tool("pickaxe", state.needed_tool_level)
        if not result then set_state21(state); return "All_Good", nil end

        -- We swing first
        robot.swing()
        maybe_something_added()
        inv.equip_tool("pickaxe", state.needed_tool_level)
        robot.swingUp()
        maybe_something_added()
        inv.equip_tool("pickaxe", state.needed_tool_level)
        robot.swingDown()
        maybe_something_added()
        ----------------------------------------------------

        -- Then we move
        local sweep_result = nav.sweep(false) -- goes forward one block (not surface_move using)
        local cur_rel = nav.get_rel()

        -- Check for the special ladder position
        if cur_rel[1] == 7 and cur_rel[2] == 8 then
            deal_with_the_ladder(state, nav.sweep)
            return "All_Good", nil -- the function we call manages tate for us
        end
        -- End of ladder position check

        if sweep_result == -1 then
            -- go to mode 21, and move height value further 3-down?, else if we're already low enough, set 31 and clear with no error
            local cur_height = nav.get_height()
            local cur_height_diff = state.starting_height - cur_height
            if cur_height_diff >= 7 then
                state.step = 31
                return "All_Good", nil
            end
            state.step = 21
            state.layer_done = true
            return "All_Good", nil
        elseif sweep_result == 0 then
            return "All_Good", nil -- just keep goind with no more comments
        elseif sweep_result == 1 then
            -- First we try and mine forward (we might've gotten stuck in a bend)
            local result = inv.equip_tool("pickaxe", state.needed_tool_level)
            if not result then set_state21(state); return "All_Good", nil end
            robot.swing()
            maybe_something_added()

            while true do -- then we try to recover from the stall
                os.sleep(2)
                local s_result = nav.sweep(false)
                if s_result == 0 then break end
                if watch_dog >= 12 then
                    state.step = 31
                    print(comms.robot_send("error", "At the most likely time: Ore Mining, got le stuck :sob:"))
                    return "All_Good", nil
                end
            end
            return "All_Good", nil
        else
            error(comms.robot_send("fatal", "ore_mining sweep_result is not expected"))
        end
    end

    -- state.step == 11 means, we are yet to progress past step 4, this will mostly be
    -- things that were above our mining level at the time (It won't matter (mostly, I hope) for the stone-age tho)
    if state.step == 11 then
        error(comms.robot_send("fatal", "TODO! in oremining"))
    end

    -- This means "regular" (post step 4) mining interruption (we ran out of pickaxes, or acheived our goal or smthing)
    if state.step == 21 then
        local cur_rel = nav.get_rel()
        local cur_height = nav.get_height()

        -- first we have to forcefully navigate to le right place;
        -- I think we'll be able to avoid most error checking if first navigate to x,0 and then to the "hole",
        -- because of the way we make our way to {0,0} in the first place
        if cur_rel[1] ~= 7 or cur_rel[2] ~= 7 then
            -- TODO -> continue through here

            cur_rel = nav.get_rel()
            -- Check for we having moved to a position that might f-up the ladder
            if  math.abs(cur_rel[1] - 7) == 1 and math.abs(cur_rel[1] - 8) == 1
                and (cur_rel[1] ~= 7 and cur_rel[2] ~= 7)
            then
                deal_with_the_ladder(state, nav.force_forward)
                return "All_Good", nil
            end

            return "All_Good", nil
        end
        -- Now we can be sure that we are in the ladder tile

        error(comms.robot_send("fatal", "TODO2! in oremining"))
    end

    -- This means: "Time to abandon this dump"
    if state.step == 31 then
        state.clear = true
        error(comms.robot_send("fatal", "TODO3! in oremining"))
    end

    -- Alternative step 4 for those that already have a shaft dug
    if state.step == 41 then
        error(comms.robot_send("fatal", "TODO4! in oremining"))
    end

    error(comms.robot_send("fatal", "Bad State ore-gathering, we somehow fell through"))
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
        if finish_state == "All_Good" then -- I think everything is getting passed as ref so it's ok to pass arguments back in
            local command_prio = state.priority

            -- No permanent changes to prio here
            if new_prio ~= nil then
                command_prio = new_prio
            end

            -- return a priority given back by "automatic" OR default - mechanism.priority
            return {command_prio, mechanism.algorithm, table.unpack(arguments)}
        elseif finish_state == "Interrupt" then -- For now this is just the same as finish
            print(comms.robot_send("debug", "interrupted ore_mining routine"))
            lock[1] = 0 -- Report our lack of success and order the bot to keep looking
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
