local module = {}

local comms = require("comms")
local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")

local el_state = {
    chunk = nil,

    interrupt = false,
    mode = "automatic", -- will search for areas tagged with "gather"
                        -- otherwise it will use the interactive system
    step = 1
}

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
        -- TODO HERE KEEP GOING
        if nav.is_sweep_setup() then
            print(comms.robot_send("error", "surface_resource_sweep: sweep was setup when it shouldn't have been \z
            did it terminate wrongly?"))
        end

        if not nav.is_sweep_setup() then
            nav.setup_sweep()
        end
    end
end

local function surface_resource_sweep(mechanism)
    local state = mechanism.state
    if state.interrupt == true then
        return {mechanism.priority, mechanism.algorithm, mechanism}
    end
    if state.mode == "automatic" then
        automatic(state)
        return {mechanism.priority, mechanism.algorithm, mechanism}
    elseif state.mode == "manual" then
        error(comms.robot_send("fatal", "TODO surface_resource_sweep, manual mode not implmented"))
    else
        error(comms.robot_send("fatal", "surface_resource_sweep impossible mode selected"))
    end

end


return module
