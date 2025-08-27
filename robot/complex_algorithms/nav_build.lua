local module = {}

local robot = require("robot")

-- local imports
local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

local inv = require("inventory.inv_obj")
local nav = require("nav_module.nav_obj")
local rel = require("nav_module.rel_move")
local move_to_build = require("nav_module.nav_to_building")

local foundation_fill = require("complex_algorithms.foundation_fill")

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

local function maybe_added()
    if inv.maybe_something_added_to_inv(nil, "any:grass") then return true end
    if inv.maybe_something_added_to_inv(nil, "any:building") then return true end
    return inv.maybe_something_added_to_inv()
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
    if not ab_meta_info.door_move_done and move_to_build.need_move(what_chunk, door_info) then
        ab_meta_info.door_move_done = move_to_build.do_move(what_chunk, door_info)
        return self_return
    end

    local unmodified_height_target = rel_coords[3]
    -------- DO MOVE REL -----------
    -- WARNING, when we return self_return the state of instructions is carried over!
    if not ab_meta_info.rel_moved and not rel.is_setup() then
        -- a little hack to optimize building, basically, we are pre-moving up, rather than going up
        -- and down to place blocks, theoretically saving a lot of time and energy
        if not instructions:includes("top_to_bottom") then
            rel_coords[3] = rel_coords[3] + 1
        else
            rel_coords[3] = rel_coords[3] + 1
            -- rel_coords[3] = rel_coords[3] - 1
        end

        nav.setup_navigate_rel(rel_coords)
    end
    local extra_sauce = nil
    if ab_meta_info.bridge_mode then
        extra_sauce = {"auto_bridge"}
    end

    local result, err
    if not ab_meta_info.rel_moved then
        result, err = nav.navigate_rel(extra_sauce)
    else
        result = -1
    end
    -----------------------------------------

    if result == -1 then -- movement completed (place block, and go back to build_function)
        ab_meta_info.rel_moved = true

        local new_orient = instructions:getArg("orient")
        if new_orient ~= nil then
            nav.change_orientation(new_orient)
        end

        local place_dir
        local swing_func
        if instructions:includes("top_to_bottom") then
            --[[place_dir = "up"
            swing_func = inv.blind_swing_up--]]
            place_dir = "down"
            swing_func = inv.blind_swing_down
        else
            place_dir = "down"
            swing_func = inv.blind_swing_down
        end

        -------- Fill Foundations ----------
        if not ab_meta_info.foundation_filled and ab_meta_info.do_foundation_fill then
            if not foundation_fill.is_setup() then foundation_fill.setup(unmodified_height_target) end
            local result = foundation_fill.fill()
            ab_meta_info.foundation_filled = result -- works because result true == done
            if result then
                ab_meta_info.rel_moved = false
                rel_coords[3] = unmodified_height_target
            end

            return self_return
        end
        ---------------------------------------

        local place_side = instructions:getArg("place")
        if not inv.place_block(place_dir, block_info, "table", place_side) then
            -- I've tried to bandaid this with an "or"
            local s_down_prev = robot.detectDown()
            local swing_result = inv.smart_swing("shovel", "down" 0, maybe_added)
            if not swing_result or not s_down_prev then
                -- TODO in an ideal world we'll simply interrupt the task and allow manual override instead of continueing
                if not swing_result then
                    print(comms.robot_send("error", "Could not break block: \"" .. place_dir .. "\"during move and build smart_cleanup"))
                end

                local something_down, _ = robot.detectDown()
                if  not ab_meta_info.foundation_filled and not ab_meta_info.do_foundation_fill
                    and not something_down
                then
                    -- remember that instructions are "short lived" and live not throught building,
                    -- but rather throughout each block placing
                    print(comms.robot_send("debug", "attempting to auto_fill as a last resort"))
                    ab_meta_info.do_foundation_fill = true
                    return self_return
                end

                print(comms.robot_send("error", "We had to pretend we've placed the block succesefully, plz look at the code"))
                return post_run -- continue as if the block had been placed
                --return nil
            end
            return self_return
        end -- after this SUCCESS
        ab_meta_info.foundation_filled = false
        ab_meta_info.rel_moved = false

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
                return self_return
            elseif err ~= "solid" then error(comms.robot_send("fatal", "Is this even possible")) end

            --[[if block_already_valid(rel_coords, block_info) then
                return post_run -- act as if we placed the block ourselves
            end -- else ]]

            local height_diff = nav.get_height() - rel_coords[3]
            local swing_front_success = false

            local le_detect, _ = robot.detect()
            if le_detect then
                swing_front_success = true
                if not inv.blind_swing_front() then -- try and destory the block
                    --print(comms.robot_send("error", "Could not break block in front during move and build smart_cleanup"))
                    swing_front_success = false
                end
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
