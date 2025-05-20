local module = {}

-- local imports
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

local inv = require("inventory.inv_obj")
local nav = require("nav_module.nav_obj")
local rel = require("nav_module.rel_move")

-- TODO fix this mess
-- the algorithm doesn't take into account the way we always place blocks from the top
local function block_already_valid(rel_coords, block_info) -- luacheck: ignore
    local cur_rel = nav.get_rel()
    local cur_height = nav.get_height()

    local diff_rel = {0,0,0}
    diff_rel[1] = cur_rel[1] - rel_coords[1]
    diff_rel[2] = cur_rel[2] - rel_coords[2]
    diff_rel[3] = cur_height - rel_coords[3]

    local num_of_diffs = 0
    for diff in ipairs(diff_rel) do
        if diff ~= 0 then num_of_diffs = num_of_diffs + 1 end
    end
    -- AKA: if we are not directly adjacent to the target block the block that stopped us must be different
    if num_of_diffs > 1 then return false end
    if geolyzer.compare(block_info.lable, "simple", -1) then return true end
    if geolyzer.compare(block_info.name, "direct", -1) then return true end

    -- TODO add more thorough comparisons comparision
    return false
end


-- In order to support different levels, this is to say, buildings in different heights in the same chunk/quad
-- we'll need to improve our navigation algorithms and the data we pass into them
-- but for now this is enough, we'll not need different levels until at-most HV, and at-least IV

local non_smart_keywords = {"no_smart_build", "force_clear"} -- this is now useless since I decided to make force_clear the default
function module.nav_and_build(instructions, post_run)
    local rel_coords, what_chunk, door_info, block_info = instructions:unpack()
    if instructions:includesOr(non_smart_keywords) then
        error(comms.robot_send("fatal", "nav_and_build_ non-smart building not yet supported"))
    end

    -- I know this shit should be done in place, I don't have the time to code good for now
    local self_return = {80, "navigate_rel", "and_build", instructions, post_run}

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
        if not inv.place_block("down", block_info, "lable") then
            -- Real error handling will come some other time
            if not inv.blindSwingDown() then -- just break the damn block te-he
                print(comms.robot_send("error", "Could not break block below during move and build smart_cleanup"))
                return nil
            end
        end

        return post_run
    elseif result == 1 then
        if err == nil then err = "nil" end

        if err == "swong" then print("debug", "noop") -- not a big error we keep going
        else
            if err == "impossible" then error(comms.robot_send("fatal", "Can't deal with this yeat"))
            elseif err ~= "solid" then error(comms.robot_send("fatal", "Is this even possible")) end

            --[[if block_already_valid(rel_coords, block_info) then
                return post_run -- act as if we placed the block ourselves
            end -- else ]]

            if not inv.blindSwing() then -- try and destory the block
                print(comms.robot_send("error", "Could not break block in front during move and build smart_cleanup"))
                return nil -- this breaks out of the "job"
            end
        end
    elseif result ~= 0 then -- elseif 0 then no problem
        error(comms.robot_send("fatal", "impossible error code returned eval navigate"))
    end

    return self_return
end

return module
