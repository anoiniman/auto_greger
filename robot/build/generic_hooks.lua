local module = {}

local deep_copy = require("deep_copy")
local comms = require("comms")

local robot = require("robot")
local nav = require("nav_module.nav_obj")
local nav_to_build = require("nav_module.nav_to_build")


local function navigate_to_rel(target_coords, origin_fsm, target_jmp, target_fsm)
    if not nav.is_setup_navigte_rel() then
        nav.setup_navigate_rel(target_coords)
    end

    local jmp_to_func
    local set_fsm = origin_fsm

    local result = nav.navigate_rel()
    if result == 1 then error(comms.robot_send("fatal", "Couldn't rel_move oak_tree_farm, are we stupid? (2)"))
    elseif result == 0 then jmp_to_func = 1 -- hopefully this isn't arbitrary
    elseif result == -1 then -- we've arrived
        set_fsm = target_fsm
        jmp_to_func = target_jmp
    end

    return jmp_to_func, set_fsm
end

local function count_occurence_of_symbol(what_symbol, how_much, where)
    local to_return = nil
    local num_to_return = nil

    local hits = 0
    for _, symbol in ipairs(where) do
        if symbol[1] == what_symbol then hits = hits + 1 end
        if hits == how_much then
            num_to_return = how_much + 1
            local copy = deep_copy.copy(symbol, ipairs)
            table.remove(copy, 1)
            to_return = copy
            break
        end
    end

    return to_return, num_to_return
end


-- assumes that symbol's (?) and (+) relation with storage is always in the x-axis
function module.std_hook1(state, parent, flag, state_init_func, name)
    local cur_chunk = nav.get_chunk()
    if not state.in_building and (cur_chunk[1] ~= parent.what_chunk[1] or cur_chunk[2] ~= parent.what_chunk[2]) then
        if nav_to_build.do_move(parent.what_chunk, parent.doors) then
            state.in_building = true -- make it so when we leave building this becomes false
        end
        return 1
    end

    -- after these checks and basic movement, we'll now rel move towards the cache (remember that x-move comes first)
    if state.fsm == 1 then

        if not nav.is_setup_navigte_rel() then
            local target_coords, _ = count_occurence_of_symbol('?', 1, parent.s_interface:getSpecialBlocks())
            if target_coords == nil then
                state.fsm = 2
                return 1
            end
            nav.setup_navigate_rel(target_coords)
        end

        local result = nav.navigate_rel()
        if result == 1 then error(comms.robot_send("fatal", "Couldn't rel_move \"" .. name .. "\" are we stupid?"))
        elseif result == 0 then return 1
        elseif result == -1 then -- we've arrived (face towards the chest and return)
            state.fsm = 2 -- aka, after function no.4 returns, function no.1 will be dealing with the '*' things

            nav.change_orientation("east")
            local check, _ = robot.detect()
            if check then return 4 end

            nav.change_orientation("west")
            check, _ = robot.detect()
            if not check then error(comms.robot_send("fatal", "Couldn't face chest, " .. name)) end
            return 4
        end

    elseif state.fsm == 2 then -- time to look at the *'s
        local what_asterisk = state.in_what_asterisk
        local success, new_what_asterisk = count_occurence_of_symbol('*', what_asterisk, parent.s_interface:getSpecialBlocks())

        if success == nil then -- we have run out of asterisks, time to go to state 4 ('+')
            state.in_what_asterisk = 1
            state.tmp_reg = nil
            state.fsm = 3
            return 1
        end -- else goto asterisk code (change to state 3 -- aka move towards '*')
        state.in_what_asterisk = new_what_asterisk
        state.temp_reg = success
        state.fsm = 21
        return 1

    elseif state.fsm == 21 then

        local target_coords = state.temp_reg
        local jmp_to_func, new_fsm = navigate_to_rel(target_coords, state.fsm, 2, 2)

        state.fsm = new_fsm
        return jmp_to_func

    elseif state.fsm == 3 then
        if flag == "no_store" then -- skip over this part of the fsm, keeping everything in the robot inventory
            state.in_what_asterisk = 1 -- prob useless
            state.tmp_reg = nil
            state.fsm = 4
            return 1
        end

        local what_plus = state.in_what_asterisk -- le reuse of registry
        local success, new_what_plus = count_occurence_of_symbol('+', what_plus, parent.s_interface:getSpecialBlocks())

        if success == nil then -- this means we've run out of +'s (go back to '?' and retrieve our items)
            state.in_what_asterisk = 1 -- prob useless
            state.tmp_reg = nil
            state.fsm = 4
            return 1
        end

        state.in_what_asterisk = new_what_plus
        state.temp_reg = success
        state.fsm = 31
        return 1
    elseif state.fsm == 31 then
        local target_coords = state.temp_reg
        local target_func = 3

        local jmp_to_func, new_fsm = navigate_to_rel(target_coords, state.fsm, target_func, 3)

        if jmp_to_func == target_func then
            nav.change_orientation("east")
            local check, _ = robot.detect()
            if check then goto a_after_turn end

            nav.change_orientation("west")
            check, _ = robot.detect()
            if not check then error(comms.robot_send("fatal", "Couldn't face chest (+) " .. name)) end
            goto a_after_turn
        end
        ::a_after_turn::

        state.fsm = new_fsm
        return jmp_to_func
    elseif state.fsm == 4 then
        if not nav.is_setup_navigte_rel() then
            local target_coords, _ = count_occurence_of_symbol('?', 1, parent.s_interface:getSpecialBlocks())
            if target_coords == nil then error(comms.robot_send("fatal", "There is no '?' symbol, " .. name)) end
            nav.setup_navigate_rel(target_coords)
        end

        local result = nav.navigate_rel()
        if result == 1 then error(comms.robot_send("fatal", "Couldn't rel_move, are we stupid: "  .. name))
        elseif result == 0 then return 1
        elseif result == -1 then -- we've arrived (face towards the chest and return)
            state.fsm = 5 -- aka, after function no.4 returns, function no.1 will be exiting

            nav.change_orientation("east")
            local check, _ = robot.detect()
            if check then return 4 end

            nav.change_orientation("west")
            check, _ = robot.detect()
            if not check then error(comms.robot_send("fatal", "Couldn't face chest" .. name)) end
            return 4
        end
    elseif state.fsm == 5 then -- we done, let us reset ourselves
        print(comms.robot_send("info", "FSM finished " .. name)) -- TODO change this to debug
         -- reset state
        local new_state = state_init_func()
        for key, value in pairs(new_state) do
            state[key] = new_state[key]
        end

        return nil
    else
        error(comms.robot_send("fatal", "state.fsm went into undefined state " .. name))
    end
end

return module
