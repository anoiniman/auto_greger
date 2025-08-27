-- Basically rel_move adapted to interfacing with door_ways in a simple manner
local module = {}

local comms = require("comms")
local inv = require("inventory.inv_obj")

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

    if  (cur_position[1] == goal_rel[1] and cur_position[1] % 15== 0 )
        or (cur_position[2] == goal_rel[2] and cur_position[2] % 15 == 0)
    then
      --  print("immediate")
        cur_goal_rel[1] = goal_rel[1]
        cur_goal_rel[2] = goal_rel[2]
        return
    end

    -- Naive move is not possible, let's check if we are however, capable of moving
    -- to be inline with the goal directly
    if goal_rel[1] % 15 == 0 and cur_position[2] % 15 == 0 then
        -- print("a1")
        cur_goal_rel[1] = goal_rel[1]
        cur_goal_rel[2] = cur_position[2]
        return
    end

    if goal_rel[2] % 15 == 0 and cur_position[1] % 15 == 0 then
        -- print("a2")
        cur_goal_rel[2] = goal_rel[2]
        cur_goal_rel[1] = cur_position[1]
        return
    end

     -- The thing now must be on an opposite edge, lets move to a corner
    if math.abs(cur_position[1] - goal_rel[1]) == 15 then
        -- print("b1")
        cur_goal_rel[1] = cur_position[1]
        if cur_position[2] < 8 then
            cur_goal_rel[2] = 0
        else
            cur_goal_rel[2] = 15
        end

        return
    end

    if math.abs(cur_position[2] - goal_rel[2]) == 15 then
       -- print("b2")
        cur_goal_rel[2] = cur_position[2]
        if cur_position[1] < 8 then
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
    -- check if the invariants are broken
    if cur_position[1] ~= 15 and cur_position[1] ~= 0 and cur_position[2] ~= 15 and cur_position[2] ~= 0 then
        print(comms.robot_send("error", "door_move setup precondition is broken, returning unsetuped"))
        move_setup = false
        return
    end

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

        -- calc_new_cur_goal(cur_position)
        return 0
    end
    -- Surely this won't bite us in the ass, (attempting to recover from failure)

    local function something_added()
        if not inv.maybe_something_added_to_inv(nil, "any:grass") then
            return inv.maybe_something_added_to_inv()
        end
        return true
    end

    local watch_dog = 0
    while true do
        if watch_dog > 8 then
            error(comms.robot_send("fatal", "Wowzers, le watch_dog in le door_move :("))
        end

        inv.smart_swing("shovel", "front", 0, something_added)
        dir, data = nav_func.navigate_rel_opaque(cur_goal_rel)
        if dir == nil or dir == 0 then
            return 0
        end
        watch_dog = watch_dog + 1
        os.sleep(2)
    end

    -- return 1, data -- couldn't move
end

return module
