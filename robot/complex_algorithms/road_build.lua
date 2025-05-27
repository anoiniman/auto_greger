local module = {}

local robot = require("robot")
--local sides_api = require("sides")

local comms = require("comms")

local inv = require("inventory.inv_obj")
local map = require("nav_module.map_obj")
local nav = require("nav_module.nav_obj")
local geolyzer = require("geolyzer_wrapper")

-- it'll be going down-up-move-down-move-up..... etc.
local has_up_stroked = false
local has_down_stroked = false
local moved_once_already = false
local starting_coords = {-1,-1}

local function do_down_stroke(cur_height, height_target)
    -- If we're already there then don't bother
    if cur_height == height_target then
        return true
    end

    local block_down = robot.detectDown()
    if block_down then
        local result = inv.blind_swing_down()
        if not result then -- we report the warning, and we skip to the next block
            print(comms.robot_send("warning", "BuildRoad: failed to swing down"))
            return true
        end
    end

    local result, _ = nav.debug_move("down", 1, 0) -- I think this will always return true
    if not result then print(comms.robot_send("error", "BuildRoad: my oh so perfect assertion failed")) end

    -- See if after this move we got there (uncomment if etc)
    -- return cur_height == height_target
    return false
end

local function do_up_stroke()
    if geolyzer.can_see_sky() then
        return true
    end

    local block_up = robot.detectUp()
    if block_up then
        local result = inv.blind_swing_up()
        if not result then -- we report the warning, and we skip to the next block
            print(comms.robot_send("warning", "BuildRoad: failed to swing up"))
            return true
        end
    end

    local result = nav.debug_move("up", 1, 0)
    -- if not result then: just go to the next thing

    -- See if after this move we got there (uncomment if sudden brokey brokey)
    --return (geolyzer.can_see_sky() or not result)
    return false
end

-- move it counter-clockwise
local function next_block(cur_rel)
    local dir = nil -- luacheck: ignore
    if cur_rel[1] == starting_coords[1] and cur_rel[2] == starting_coords[2] and moved_once_already then
        return true
    end

    if cur_rel[2] == 0 and cur_rel[1] ~= 0 then
        dir = "west"
    elseif cur_rel[1] == 0 and cur_rel[2] ~= 15 then
        dir = "south"
    elseif cur_rel[2] == 15 and cur_rel[1] ~= 15 then
        dir = "east"
    elseif cur_rel[1] == 15 and cur_rel[2] ~= 0 then
        dir = "north"
    else
        print(comms.robot_send("error", "BuildRoad, next_block, how could this happen?"))
        return true
    end

    local result, data = nav.debug_move(dir, 1, 0)
    if not result and data == "impossible" then
        local watch_dog = 0
        while not result do
            if watch_dog > 15 then
                error(comms.robot_send(
                "fatal",    "BuildRoad: Impossible move resolution limit exceeded, \z
                            hard crashing, you are on your own"
                ));
                --return false
            end

            -- luacheck: ignore
            local stroke_dir = nil
            if up_stroke then stroke_dir = "down"
            else stroke_dir = "up" end

            nav.debug_move(stroke_dir, 1, 0)
            result, data = nav.debug_move(dir, 1, 0)
            if not result and data == "impossible" then
                watch_dog = watch_dog + 1
            elseif not result then
                local swing_result = inv.blind_swing_front()
                if not swing_result then
                    watch_dog = watch_dog + 1
                else
                    result, data = nav.debug_move(dir, 1, 0)
                end
            end
        end
    elseif not result then
        local swing_result = inv.blind_swing_front()
        if swing_result == false then
            print(comms.robot_send("error", "BuildRoad, couldn't swing forward"))
        end
    end

    moved_once_already = true
    return false
end

function module.step(instructions, return_table)
    local what_chunk = instructions.what_chunk
    local height_target = instructions.rel_coords[3]

    if what_chunk == nil then print(comms.robot_send("error", "road_build.step(), no what_chunk provided!")) end

    local cur_chunk = nav.get_chunk()
    local is_chunk_setup = nav.is_setup_navigate_chunk()
    -- Get to the read
    if is_chunk_setup or (cur_chunk[1] ~= 15 and cur_chunk[1] ~= 0 and cur_chunk[2] ~= 0 and cur_chunk[2] ~= 15) then
        if not is_chunk_setup then
            nav.setup_navigate_chunk(what_chunk)
        end
        nav.navigate_chunk("surface")
    end

    local cur_height = nav.get_height()
    local cur_rel = nav.get_rel()
    if starting_coords[1] == -1 or starting_coords[2] == -1 then
        starting_coords[1] = cur_rel[1]
        starting_coords[2] = cur_rel[2]
    end

    local closer_to_ceiling = (cur_height - height_target > 4)
    local in_ground = (cur_height == height_target)

    if not closer_to_ceiling and not in_ground and not has_down_stroked then
        has_down_stroked = do_down_stroke(cur_height, height_target)
        return return_table
    elseif closer_to_ceiling and not geolyzer.can_see_sky() and not has_up_stroked then
        has_up_stroked = do_up_stroke()
        return return_table
    end

    if not has_up_stroked then
        has_up_stroked = do_up_stroke()
        return return_table
    elseif not has_down_stroked then
        has_down_stroked = do_down_stroke()
        return return_table
    end


    local finished = false
    if has_up_stroked and has_down_stroked then
        finished = next_block(cur_rel)
        has_up_stroked = false
        has_down_stroked = false
        moved_once_already = false
    end

    if finished then
        map.get_chunk(what_chunk).roads_cleared = true
        starting_coords[1] = -1
        starting_coords[2] = -1
        return return_table
    end

    return return_table
end


return module
