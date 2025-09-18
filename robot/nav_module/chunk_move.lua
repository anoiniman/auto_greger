local module = {}

local math = require("math")
local comms = require("comms")

local rel_move = require("nav_module.rel_move")
local interface = require("nav_module.nav_interface")


local goal_chunk = {0,0}
local chunk_nearest_side = {0,0}
local rel_nearest_side = {0,0}

local cur_in_road = false
local is_setup = false

local half_chunk_square = 8
local function update_chunk_nav(nav_obj)
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
        rel[2] = 15
        chunk[2] = chunk[2] - 1
    end

    chunk_nearest_side[1] = chunk[1] - goal_chunk[1]
    chunk_nearest_side[2] = chunk[2] - goal_chunk[2]

    rel_nearest_side[1] = rel[1] - half_chunk_square -- x - 8
    rel_nearest_side[2] = rel[2] - half_chunk_square
end

local function f_cur_in_road(nav_obj)
    local rel = nav_obj.rel
    return rel[1] == 0 or rel[1] == 15 or rel[2] == 0 or rel[2] == 15
end

function module.setup_navigate_chunk(to_what_chunk, nav_obj)
    if is_setup then
        print(comms.robot_send("warning", "Attempted to setup chunk move when already setup"))
        return
    end

    cur_in_road = f_cur_in_road(nav_obj)
    is_setup = true

    -- copy provided table (assuming to_what_chunk = {int, int}) (num, num)
    goal_chunk = {to_what_chunk[1], to_what_chunk[2]}

    update_chunk_nav(nav_obj)

    return chunk_nearest_side, rel_nearest_side
end

function module.quick_check(nav_obj, target_chunk)
    local cur_chunk = nav_obj.chunk
    return cur_chunk[1] == target_chunk[1] and cur_chunk[2] == target_chunk[2]
end


local function move_to_road(what_kind, nav_obj, cur_building)
    local cur_rel = nav_obj.rel

    local function nearest_side()
        if f_cur_in_road(nav_obj) then return true end

        local axis_nearest
        if  (math.abs(rel_nearest_side[1]) > math.abs(rel_nearest_side[2]))
            and cur_rel[1] ~= 0 and cur_rel[1] ~= 15
        then
            axis_nearest = 0
        elseif cur_rel[2] ~= 0 and cur_rel[2] ~= 15 then
            axis_nearest = 1
        else
            return true
        end

        if axis_nearest == 0 then
            if rel_nearest_side[1] > 0 then interface.r_move(what_kind, "east", nav_obj)
            elseif rel_nearest_side[1] <= 0 then interface.r_move(what_kind, "west", nav_obj)
            else print(comms.robot_send("error", "Navigate Chunk, find nearest side fatal logic impossibility detected")) end
        else
            if rel_nearest_side[2] > 0 then interface.r_move(what_kind, "south", nav_obj)
            elseif rel_nearest_side[2] <= 0 then interface.r_move(what_kind, "north", nav_obj)
            else print(comms.robot_send("error", "Navigate Chunk, find nearest side fatal logic impossibility detected")) end
        end

        update_chunk_nav(nav_obj)
        return f_cur_in_road(nav_obj)
    end

    -- The move to road part
    if cur_building == nil then
        return nearest_side()
    end

    -- The move out of building part
    local doors = cur_building.doors

    local what_door = nil
    local dist = 100
    for _, door in ipairs(doors) do
        local inner_dist = math.abs(cur_rel[1] - door.x) + math.abs(cur_rel[2] - door.z)
        if inner_dist < dist then
            what_door = door
            dist = inner_dist
        end
    end
    if what_door == nil then return nearest_side() end

    local cur_height = nav_obj.height
    local goal_rel = {what_door.x, what_door.z, cur_height}
    local result, _ = rel_move.access_opaque(nav_obj, goal_rel, nil)
    update_chunk_nav(nav_obj)

    if result == 0 then return false end
    if result == nil then
        nav_obj.cur_building = nil
        return false
    end -- else movement failed

    print("warning", "chunk_move, failed to exit thorugh door :(")
    local height_save = cur_height + 1
    while true do
        local goal_rel = {what_door.x, what_door.z, height_save}
        local result, _ = rel_move.access_opaque(nav_obj, goal_rel, nil)
        update_chunk_nav(nav_obj)
        if result == 0 or result == nil then
            return false
        end
        height_save = height_save + 1
        if height_save - cur_height > 5 then
            error(comms.robot_send("fatal", "chunk_move, failed to exit thorugh door :("))
        end
    end
end

-- When we are in road, but, not in a road correctly orientated we just move forwards anyway, which is bad
local function secondary_road_check(move_dir_x, nav_obj, what_kind) -- move_dir_x -- true for x, false for z
    local cur_rel = nav_obj.rel

    if move_dir_x then
        if cur_rel[2] ~= 0 and cur_rel[2] ~= 15 then
            if chunk_nearest_side[2] < 0 then interface.r_move(what_kind, "south", nav_obj)
            else interface.r_move(what_kind, "north", nav_obj) end

            update_chunk_nav(nav_obj)
            return false
        end
    else
        if cur_rel[1] ~= 0 and cur_rel[1] ~= 15 then
            if chunk_nearest_side[1] < 0 then interface.r_move(what_kind, "east", nav_obj)
            else interface.r_move(what_kind, "west", nav_obj) end

            update_chunk_nav(nav_obj)
            return false
        end
    end

    return true
end


-- returns true if it is finished
function module.navigate_chunk(what_kind, nav_obj, cur_building)
    if is_setup == false then
        print(comms.robot_send("error", "tried to navigate without setting up first"))
        return false
    end

    -- "move to the road"
    if not cur_in_road or cur_building ~= nil then
        cur_in_road = move_to_road(what_kind, nav_obj, cur_building)
        if not cur_in_road then return false end
    end

    -- after being in road we start moving towards the target chunk
    -- this means we can use chunk_move cur_chunk in order to move to the nearest road for free
    if (chunk_nearest_side[1] ~= 0) or (chunk_nearest_side[2] ~= 0) then
        if chunk_nearest_side[1] < 0 then -- move right
            if not secondary_road_check(true, nav_obj, what_kind) then return false end
            interface.r_move(what_kind, "east", nav_obj)
        elseif chunk_nearest_side[1] > 0 then
            if not secondary_road_check(true, nav_obj, what_kind) then return false end
            interface.r_move(what_kind, "west", nav_obj)
        elseif chunk_nearest_side[2] < 0 then
            if not secondary_road_check(false, nav_obj, what_kind) then return false end
            interface.r_move(what_kind, "south", nav_obj)
        else
            if not secondary_road_check(false, nav_obj, what_kind) then return false end
            interface.r_move(what_kind, "north", nav_obj)
        end

        update_chunk_nav(nav_obj)
        if (chunk_nearest_side[1] ~= 0) or (chunk_nearest_side[2] ~= 0) then return false end
    end

    module.reset()
    return true
end

function module.reset()
    print(comms.robot_send("debug", "We've arrived at the target chunk"))
    is_setup = false
end

function module.is_setup()
    return is_setup
end


return module
