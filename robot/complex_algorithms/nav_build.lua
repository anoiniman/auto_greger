local module = {}

-- local imports
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

local inv = require("inventory.inv_obj")
local nav = require("nav_module.nav_obj")
local rel = require("nav_module.rel_move")

-- For now I'll be doing nothing with this, but maybe one day who knows
-- the algorithm doesn't take into account the way we always place blocks from the top
local function block_already_valid(rel_coords, block_info) -- luacheck: ignore
    local cur_rel = nav.get_rel()
    local cur_height = nav.get_height()

    local diff_rel = {0,0,0}
    diff_rel[1] = cur_rel[1] - rel_coords[1]
    diff_rel[2] = cur_rel[2] - rel_coords[2]
    diff_rel[3] = cur_height - rel_coords[3]

    local num_of_diffs = 0
    for _, diff in ipairs(diff_rel) do
        if diff ~= 0 then num_of_diffs = num_of_diffs + 1 end
    end
    -- AKA: if we are not directly adjacent to the target block the block that stopped us must be different
    if num_of_diffs > 1 then return false end
    if geolyzer.compare(block_info.lable, "simple", -1) then return true end
    if geolyzer.compare(block_info.name, "direct", -1) then return true end

    -- todo add more thorough comparisons comparision
    return false
end

-- In order to support different levels, this is to say, buildings in different heights in the same chunk/quad
-- we'll need to improve our navigation algorithms and the data we pass into them
-- but for now this is enough, we'll not need different levels until at-most HV, and at-least IV
function module.nav_and_build(instructions, post_run)
    local rel_coords, what_chunk, door_info, block_info = instructions:nav_and_build_unpack()
    local ab_meta_info = instructions.ab_meta_info_ref

    -- I know this shit should be done in place, I don't have the time to code good for now
    -- post_run is a command to be run after this one is finished
    local self_return = {80, "navigate_rel", "and_build", instructions, post_run}

    --------- CHUNK MOVE -----------
    local cur_chunk = nav.get_chunk()
    --print(comms.robot_send("debug", "cur_coords: " .. cur_chunk[1] .. ", " .. cur_chunk[2]))
    if cur_chunk[1] ~= what_chunk[1] or cur_chunk[2] ~= what_chunk[2] then
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(what_chunk)
        end
        nav.navigate_chunk("surface") -- for now surface move only

        return self_return
    end

    -------- SANITY CHECK ---------
    if nav.is_setup_navigate_chunk() then
        error(comms.robot_send("fatal", "eval, nav_and_build, did navigation not terminate gracefully?"))
    end
    -------- DO MOVE DOOR ----------
    if not ab_meta_info.door_move_done and door_info ~= nil and #door_info ~= 0 then
        if not nav.is_setup_door_move() then nav.setup_door_move(door_info) end
        local result, err = nav.door_move()

        if result == 1 then
            if err == nil then err = "nil" end
            if err ~= "swong" then error(comms.robot_send("fatal", "nav_build: this is unexpected!")) end
            return self_return
        elseif result == -1 then
            ab_meta_info.door_move_done = true
            --instructions:delete("door_info") -- necessary for code to advance to rel_move section
        elseif result == 0 then return self_return
        else error(comms.robot_send("fatal", "nav_build: unexpected2!")) end
    end

    -------- DO MOVE REL -----------
    if not rel.is_setup() then
        -- a little hack to optimize building, basically, we are pre-moving up, rather than going up
        -- and down to place blocks, theoretically saving a lot of time and energy
        if not instructions:includes("top_to_bottom") then
            rel_coords[3] = rel_coords[3] + 1
        else
            rel_coords[3] = rel_coords[3] - 1
        end

        nav.setup_navigate_rel(rel_coords)
    end
    local extra_sauce = nil
    if ab_meta_info.bridge_mode then
        extra_sauce = {"auto_bridge"}
    end

    local result, err = nav.navigate_rel(extra_sauce)
    -----------------------------------------

    if result == -1 then -- movement completed (place block, and go back to build_function)
        local new_orient = instructions:getArg("orient")
        if new_orient ~= nil then
            nav.change_orientation(new_orient)
        end

        local place_dir
        local swing_func
        if instructions:includes("top_to_bottom") then
            place_dir = "up"
            swing_func = inv.blind_swing_up
        else
            place_dir = "down"
            swing_func = inv.blind_swing_down
        end

        local place_side = instructions:getArg("place")
        if not inv.place_block(place_dir, block_info, "optional_name", place_side) then
            -- Real error handling will come some other time
            if not swing_func() then -- just break the damn block and try again
                print(comms.robot_send("error", "Could not break block: \"" .. place_dir .. "\"during move and build smart_cleanup"))
                return post_run -- continue as if the block had been placed
                --return nil
            end
            return self_return
        end

        return post_run
    elseif result == 1 then -- means error
        if err == nil then err = "nil" end

        if err == "swong" then print("debug", "noop") -- not a big error we keep going
        else
            if err == "impossible" then
                local result = inv.place_block("down", "any:building_block", "name")
                ab_meta_info.bridge_mode = true
                if not result then
                    error(comms.robot_send("fatal", "Wasn't able to place down bridge block in nav_build"))
                end

            elseif err ~= "solid" then error(comms.robot_send("fatal", "Is this even possible")) end

            --[[if block_already_valid(rel_coords, block_info) then
                return post_run -- act as if we placed the block ourselves
            end -- else ]]

            local height_diff = nav.get_height() - rel_coords[3]
            local swing_front_success = true
            if not inv.blind_swing_front() then -- try and destory the block
                --print(comms.robot_send("error", "Could not break block in front during move and build smart_cleanup"))
                swing_front_success = false
            end
            if not swing_front_success and height_diff > 0 and not inv.blind_swing_down() then -- just break the damn block te-he
                print(comms.robot_send("error", "Could not break nor block in front, nor block down during move and build smart_cleanup"))
                return nil -- this breaks out of the "job"
            elseif not swing_front_success and height_diff < 0 and not inv.blind_swing_up() then -- just break the damn block te-he
                print(comms.robot_send("error", "Could not break nor block in front, nor block up during move and build smart_cleanup"))
                return nil
            end
        end
    elseif result ~= 0 then -- elseif 0 then no problem
        error(comms.robot_send("fatal", "impossible error code returned eval navigate"))
    end

    return self_return
end

return module
