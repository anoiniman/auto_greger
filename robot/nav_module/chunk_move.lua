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

    rel_nearest_side[1] = rel[1] - half_chunk_square
    rel_nearest_side[2] = rel[2] - half_chunk_square
end

function module.setup_navigate_chunk(to_what_chunk, nav_obj)
    if is_setup then
        print(comms.robot_send("warning", "Attempted to setup chunk move when already setup"))
        return
    end

    cur_in_road = false
    is_setup = true

    -- copy provided table (assuming to_what_chunk = {int, int}) (num, num)
    goal_chunk = {to_what_chunk[1], to_what_chunk[2]}

    update_chunk_nav(nav_obj)

    return chunk_nearest_side, rel_nearest_side
end

-- checks if we're in road and in the target_chunk()
function module.quick_check(nav_obj, target_chunk)
    local cur_chunk = nav_obj.chunk
    if cur_chunk[1] ~= target_chunk[1] or cur_chunk[2] ~= target_chunk[2] then return false end

    local rel = nav_obj.rel

    return rel[1] == 0 or rel[1] == 15 or rel[2] == 0 or rel[2] == 15
end


local function move_to_road(what_kind, nav_obj, cur_building)
    local function nearest_side()
        local axis_nearest
        if math.abs(rel_nearest_side[1]) < math.abs(rel_nearest_side[2]) then
            axis_nearest = 0
        else
            axis_nearest = 1
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
        local cur_rel = nav_obj.rel
        return cur_rel[1] == 0 or cur_rel[1] == 15 or cur_rel[2] == 0 or cur_rel[2] == 15
    end

    -- The move to road part
    if cur_building == nil then
        return nearest_side()
    end

    -- The move out of building part
    local doors = cur_building:getDoors()
    local cur_rel = nav_obj.rel

    local what_door = nil
    local dist = 100
    for _, door in ipairs(doors) do
        local inner_dist = math.abs(cur_rel[1] - door.x) + math.abs(cur_rel[2] - door.z)
        if inner_dist < dist then
            what_door = door
            dist = inner_dist
        end
    end
    if what_door == nil then nearest_side() end

    local cur_height = nav_obj.height
    local goal_rel = {what_door.x, what_door.z, cur_height}
    local result, _ = rel_move.access_opaque(nav_obj, goal_rel, nil)
    update_chunk_nav(nav_obj)

    if result == 0 then return false end
    if result == nil then
        nav_obj.cur_building = nil
        return false
    end -- else movement failed
    print(comms.robot_send("error", "chunk_move, failed to exit thorugh door :("))
end


-- returns true if it is finished
function module.navigate_chunk(what_kind, nav_obj, cur_building)
    if is_setup == false then
        print(comms.robot_send("error", "tried to navigate without setting up first"))
        return false
    end

    -- "move to the road"
    if not cur_in_road then
        cur_in_road = move_to_road(what_kind, nav_obj, cur_building)
        return false
    end

    -- after being in road we start moving towards the target chunk
    -- this means we can use chunk_move cur_chunk in order to move to the nearest road for free
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
    is_setup = false
    return true
end

function module.is_setup()
    return is_setup
end


return module
