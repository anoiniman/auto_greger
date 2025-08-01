-- Basically rel_move adapted to interfacing with door_ways in a simple manner
local module = {}

local comms = require("comms")

-- After moving to the correct x,z, move 1 inside the building
local goal_rel = {0, 0, -1}
local move_setup = false
local cur_goal_rel = {0, 0, -1}


function module.is_setup()
    return move_setup
end

-- somehow we're going towards the diametrically opposed side :P
local function calc_new_cur_goal(cur_position)
   -- if this is the case we can move naivly (it means one of the end points is in our place)
   if cur_position[1] - goal_rel[1] == 0  or cur_position[2] - goal_rel[2] == 0 then
        cur_goal_rel[1] = goal_rel[1]
        cur_goal_rel[2] = goal_rel[2]
        return
   end
   -- Cases remaining, it is in the opposite side OR it is either to the right or the left, OR we are on an corner

   -- This checks if we're on an edge, and naive move is not possible (as per the previous check)
   if cur_position[1] % 15 == 0 and cur_position[2] % 15 == 0 then
        -- check which coord is directly opposite to us and move towards it
        if math.abs(cur_position[1] - goal_rel[1]) == 15 then
            cur_goal_rel[1] = goal_rel[1]
            cur_goal_rel[2] = cur_position[2]
            return
        end

        if math.abs(cur_position[2] - goal_rel[2]) == 15 then
            cur_goal_rel[2] = goal_rel[2]
            cur_goal_rel[1] = cur_position[1]
            return
        end

        error(comms.robot_send("fatal", "Unexpected! Corner navigation of door_move case"))
   end

   -- This checks if we're opposite to something and in which way are we opposite
   -- find closest side, move to corner, using road, and then the corner thing mabob might be able to fix it
   if goal_rel[1] % 15 == 0 then -- door is in an x-aligned edge
        cur_goal_rel[1] = cur_position[1]

        if goal_rel[2] <= 8 then
            cur_goal_rel[2] = 0
        else
            cur_goal_rel[2] = 15
        end

        return
   elseif goal_rel[2] % 15 == 0 then -- door is in a z aligned edge
        cur_goal_rel[2] = cur_position[2]

        if goal_rel[1] <= 8 then
            cur_goal_rel[1] = 0
        else
            cur_goal_rel[1] = 15
        end

        return
   end

   error(comms.robot_send("fatal", "Unexpected"))
end

local function finish_setup(door_info, cur_position)
    goal_rel[1] = door_info.x; goal_rel[2] = door_info.z;
    calc_new_cur_goal(cur_position)
end

-- we have to assume that we are in a road
local function table_search(door_info_table, cur_position)
    local cur_distance = 255 -- default value
    local cur_door = nil
    for _, door in ipairs(door_info_table) do
        print(comms.robot_send("debug", "Door(: " .. door.x .. ", " .. door.z .. ")"))
        -- check for ANY door
        local calc_diff = math.abs(cur_position[1] - door.x) + math.abs(cur_position[2] - door.z)
        if calc_diff < cur_distance then
            cur_distance = calc_diff
            cur_door = door
        end
    end
    if cur_door == nil then error(comms.robot_send("fatal", "door_move, table_search, couldn't find door")) end
    return cur_door
end

-- we assume that our cur_position is already on a road
function module.setup_move(door_info_table, cur_position)
    if type(door_info_table) ~= "table" then
        print(comms.robot_send("warning", "door_move, door_info is not a table, this is non-standard"))
        finish_setup(door_info_table)
        move_setup = true
        return
    end

    local door_info = table_search(door_info_table, cur_position)
    finish_setup(door_info, cur_position)
    move_setup = true
end

local function last_move(nav_func) -- changed to 2, but could be 1 idk
    if goal_rel[1] == 0 then nav_func.debug_move("east", 2, 0)
    elseif goal_rel[1] == 15 then nav_func.debug_move("west", 2, 0)
    elseif goal_rel[2] == 15 then nav_func.debug_move("north", 2, 0)
    elseif goal_rel[2] == 0 then nav_func.debug_move("south", 2, 0)
    else
        print(comms.robot_send("warning", "door_move.last_move() -- couldn't last move!"))
    end
end


-- local function


-- we must move --around-- in the road so that le things are le good, this means, we first move to the nearest corner,
-- then forward, then into the doorway in a worst case scenario
function module.do_move(nav_func)
    if not move_setup then return 1 end

    local cur_position = nav_func.get_rel()
    calc_new_cur_goal(cur_position)
    local dir, data = nav_func.navigate_rel_opaque(cur_goal_rel)

    if dir == 0 then return 0
    elseif dir == nil then -- This means that we've finished the current treck
        -- (we need to check if we are at the true goal or if we need to calculate again and keep going)
        if cur_position[1] == goal_rel[1] and cur_position[2] == goal_rel[2] then -- finish up
            last_move(nav_func)
            move_setup = false
            return -1
        end -- else generate new move position

        calc_new_cur_goal(cur_position)
        return 0
    end

    return 1, data -- couldn't move
end

return module
