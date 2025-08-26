local module = {}

local comms = require("comms")
local interactive = require("interactive")

local nav = require("nav_module.nav_obj")
local simple_elevator = require("nav_module.simple_elevator")
local map = require("nav_module.map_obj")

-- depleted_string = "surface_depleted" or "tree_depleted" (it resetes eventually)
-- if sweep_mode is not a nil AND a number then it represents a specific y-axis to target and to set free-move
function module.automatic(parent_name, state, depleted_string, gather_string, check_subset, f_step4, sweep_mode)
    if sweep_mode ~= nil and type(sweep_mode) ~= "number" then
        error(comms.robot_send("fatal", "generic automatic sweep: sweep_mode is invalid!"))
    end

    -- (1x) determine what_chunk to sploink
    if state.step == 1 then
        -- Determine if we have a gather area anywhere
        local area = map.get_area(gather_string)
        if area == nil then -- we'll have to wait :)
            if state.i_id == nil then
                state.i_id = interactive.add("generic_hold", parent_name .. "is holding for a \"".. gather_string .. "\" area to be created")
            end

            return false, -2
        end

        state.step = 11
        if state.i_id ~= nil then
            interactive.del_element(state.i_id)
            state.i_id = nil
        end

    elseif state.step == 11 then
        local area = map.get_area(gather_string)
        if area == nil then state.step = 1; return false end

        local chunk_to_act_upon
        for _, chunk_coords in ipairs(area.chunks) do
            local chunk = map.get_chunk(chunk_coords)
            if chunk.chunk.mark == nil or not chunk:checkMarks(depleted_string) then
                chunk_to_act_upon = chunk
                break
            end
        end

        if chunk_to_act_upon == nil then -- wait more
            if state.i_id == nil then
                state.i_id = interactive.add(
                    "generic_hold", parent_name .. " is holding for chunks to be assigned to \"" .. gather_string .. "\"area"
                )
            end

            return false, -2
        end
        if state.i_id ~= nil then
            interactive.del_element(state.i_id)
            state.i_id = nil
        end

        state.chunk = chunk_to_act_upon
        state.step = 2

    elseif state.step == 2 then
        if not nav.is_setup_navigate_chunk() then
            local chunk_coords = {state.chunk.chunk.x, state.chunk.chunk.z}
            nav.setup_navigate_chunk(chunk_coords)
        end

        local is_finished = nav.navigate_chunk("surface")
        if is_finished then
            state.step = 3
        end
    elseif state.step == 3 then
        if sweep_mode ~= nil and nav.get_height() ~= sweep_mode then
            local result = simple_elevator.be_an_elevator(sweep_mode)
            return not result
        end

        if nav.is_sweep_setup() then
            print(comms.robot_send("error", "surface_resource_sweep: sweep was setup when it shouldn't have been \z
            did it terminate wrongly?"))
        end

        if not nav.is_sweep_setup() then
            nav.setup_sweep()
        end
        state.step = 31

    elseif state.step == 31 then -- sure
        local do_surface = true
        if sweep_mode ~= nil then do_surface = false end

        -- tree detection n'shiet (?) if needed do it one day

        local sweep_result = nav.sweep(do_surface) -- goes forward one block

        if sweep_result == -1 then
            state.chunk:addMark("surface_depleted")
            return true, nil
        elseif sweep_result == 0 then
            -- careful with hardened _clay_ (and _sand_stone)
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
        if not f_step4(state) then -- if its true maintain step as 4
            state.step = 31
        end
    end
    return false, nil
end

return module
