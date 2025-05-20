local module = {}

-- local imports
local comms = require("comms")

local inv = require("inventory.inv_obj")
local nav = require("nav_module.nav_obj")
local rel = require("nav_module.rel_move")


-- In order to support different levels, this is to say, buildings in different heights in the same chunk/quad
-- we'll need to improve our navigation algorithms and the data we pass into them
-- but for now this is enough, we'll not need different levels until at-most HV, and at-least IV
local non_smart_keywords = {"no_smart_build", "force_clear"}
local function nav_and_build(instructions, post_run)
    local rel_coords, what_chunk, door_info, block_name = instruction:unpack()
    if instruction:includesOr(non_smart_keywords) then
        error(comms.robot_send("fatal", "nav_and_build_ non-smart building not yet supported"))
    end

    -- I know this shit should be done in place, I don't have the time to code good for now
    local self_return = {80, module.navigate_rel, "and_build", rel_coords, what_chunk, door_info, block_name, post_run}

    -- post_run is a command to be run after this one is finished
    local cur_chunk = nav.get_chunk()

    --print(comms.robot_send("debug", "cur_coords: " .. cur_chunk[1] .. ", " .. cur_chunk[2]))
    if cur_chunk[1] ~= what_chunk[1] or cur_chunk[2] ~= what_chunk[2] then
        -- this is getting ridiculous, we won't do a inner command again this time
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(what_chunk)
        end
        nav.navigate_chunk("surface") -- for now surface move only

        return self_return
    end
    -- Sanity Check:
    if nav.is_setup_navigate_chunk() then
        error(comms.robot_send("fatal", "eval, nav_and_build, did navigation not terminate gracefully?"))
    end

    if not rel.is_setup() then
        -- a little hack to optimize building, basically, we are pre-moving up, rather than going up
        -- and down to place blocks, theoretically saving a lot of time and energy
        rel_coords[3] = rel_coords[3] + 1

        nav.setup_navigate_rel(rel_coords)
    end

    local result, err = nav.navigate_rel()
    if result == -1 then -- movement completed (place block, and go back to build_function)
        --nav.debug_move("up", 1, false) >-----< No longer needed
        if not inv.place_block("down", block_name, "lable") then
            -- Real error handling will come some other time
            error(comms.robot_send("fatal", "how is this possible? :sob:"))
        end

        return post_run
    elseif result == 1 then
        if err == nil then err = "nil" end

        if err == "swong" then print("noop") -- not a big error we keep going
        else error(comms.robot_send("fatal", "eval.navigate: navigate_build, error rel_moving: " .. err)) end
    elseif result ~= 0 then -- elseif 0 then no problem
        error(comms.robot_send("fatal", "impossible error code returned eval navigate"))
    end

    return self_return
end

return module
