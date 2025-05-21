-- Basically rel_move adapted to interfacing with door_ways in a simple manner
local module = {}

local comms = require("comms")
local nav = require("nav_module.nav_obj")

-- After moving to the correct x,z, move 1 inside the building
local goal_rel = {0,0, -1}
local move_setup = false
function module.is_setup()
    return move_setup
end

local function finish_setup(door_info)
   goal_rel[1] = door_info.x; goal_rel[2] = door_info.z;
end

-- we have to assume that we are in a road
local function table_search(door_info_table, cur_position)
    local cur_distance = 100 -- default value
    local cur_door = nil
    for door in ipairs(door_info_table) do
        if cur_position[1] == door.x and cur_position[2] - door.z < cur_distance then
            cur_distance = cur_position[2] - door.z
            cur_door = door
        elseif cur_position[2] == door.z and cur_position[1] - door.x < cur_distance then
            cur_distance = cur_position[1] - door.x
            cur_door = door
        end
    end
    if cur_door == nil then error(comms.robot_send("fatal", "door_move, table_search, couldn't find door")) end
    return cur_door
end

-- we assume that our cur position is already on a road
function module.setup_move(door_info_table, cur_position)
    if type(door_info_table) ~= "table" then
        print(comms.robot_send("warning", "door_move, door_info is not a table, this is non-standard"))
        finish_setup(door_info_table)
        move_setup = true
        return
    end

    local door_info = table_search(door_info_table, cur_position)
    finish_setup(door_info)
    move_setup = true
end

local function last_move()
    if goal_rel[1] == 0 then nav.debug_move("east", 1, 0)
    elseif goal_rel[1] == 15 then nav.debug_move("west", 1, 0)
    elseif goal_rel[2] == 15 then nav.debug_move("north", 1, 0)
    elseif goal_rel[2] == 0 then nav.debug_move("south", 1, 0)
    else
        print(comms.robot_send("warning", "door_move.last_move() -- couldn't last move!"))
    end
end

function module.do_move()
    if not move_setup then return 1 end
    local result, data = nav.navigate_rel_opaque(goal_rel)

    if result == nil then -- luacheck: ignore
    elseif result == 0 then return 0 end

    local dir = result
    if dir == nil then
        -- This means that we've arrived at the spot
        last_move()
        move_setup = false
        return -1
    end

    return 1, data -- couldn't move
end

return module
