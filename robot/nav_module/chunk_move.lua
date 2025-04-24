local module = {}

local math = require("math")
local robot = require("robot")
local sides = require("sides")
local io = require("io")
local serialize = require("serialization")

local comms = require("comms")

local geolyzer = require("geolyzer_wrapper")

local interface = require("nav_module.nav_interface")

local goal_chunk = {0,0}
local chunk_nearest_side = {0,0}
local rel_nearest_side = {0,0}

local cur_in_road = false

function module.setup_navigate_chunk(to_what_chunk, nav_obj)
    cur_in_road = false

    -- copy provided table (assuming to_what_chunk = {int, int}) (num, num)
    goal_chunk = {to_what_chunk[1], to_what_chunk[2]}

    update_chunk_nav(nav_obj)

    return chunk_nearest_side, rel_nearest_side
end

function update_chunk_nav(nav_obj)
    local rel = nav_obj["rel"]
    local chunk = nav_obj["chunk"]

    if rel[1] > 15 then
        rel[1] = 0
        chunk[1] = chunk[1] + 1
    elseif rel[1] < 0 then
        rel[1] = 15
        chunk[1] = chunk[1] - 1
    elseif rel[2] > 15 then
        rel[2] = 0
        chunk[2] = chunk[2] + 1
    elseif rel[2] < 0 then
        rel[2] = 16
        chunk[2] = chunk[2] - 1
    end

    chunk_nearest_side[1] = chunk[1] - goal_chunk[1]
    chunk_nearest_side[2] = chunk[2] - goal_chunk[2]

    local half_chunk_square = 8
    rel_nearest_side[1] = rel[1] - half_chunk_square
    rel_nearest_side[2] = rel[2] - half_chunk_square
end

-- returns if it is finished
function module.navigate_chunk(what_kind, nav_obj)
    -- I feel as if this 2 bools are logically overlapping too much so i'll comment out 1 of em
    --local bool1 = (math.abs(rel_nearest_side[1]) < 8) or (math.abs(rel_nearest_side[2]) < 8)
    local bool1 = true
    cur_in_road = (math.abs(rel_nearest_side[1]) == 8) or (math.abs(rel_nearest_side[2]) == 8)

    -- "move to the road"
    if bool1 == true and cur_in_road == false then
        if rel_nearest_side[1] > 0 then interface.r_move(what_kind, "east", nav_obj)
        elseif rel_nearest_side[1] < 0 then interface.r_move(what_kind, "west", nav_obj)
        elseif rel_nearest_side[2] > 0 then interface.r_move(what_kind, "south", nav_obj)
        elseif rel_nearest_side[2] < 0 then interface.r_move(what_kind, "north", nav_obj) 
        else print(comms.robot_send("error", "Navigate Chunk, find nearest side fatal logic impossibility detected")) end

        update_chunk_nav(nav_obj)
        return false
    end

    if (chunk_nearest_side[1] ~= 0) or (chunk_nearest_side[2] ~= 0) then
        if chunk_nearest_side[1] < 0 then -- move right
            interface.r_move(what_kind, "east", nav_obj)
        elseif chunk_nearest_side[1] > 0 then
            interface.r_move(what_kind, "west", nav_obj)
        elseif chunk_nearest_side[2] < 0 then
            interface.r_move(what_kind, "south", nav_obj)
        else
            interface.r_move(what_kind, "north", nav_obj)
        end

        update_chunk_nav(nav_obj)
        return false
    end

    print(comms.robot_send("info", "We've arrived at the target chunk"))
    return true
end


return module
