local module = {}

local math = require("math")
local robot = require("robot")
local sides_api = require("sides")
local serialize = require("serialization")

local comms = require("comms")
local io = require("io")

local geolyzer = require("geolyzer_wrapper")

local function update_pos(direction, nav_obj) -- assuming forward move
    local abs = nav_obj.abs
    local rel = nav_obj.rel
    
    local height = nav_obj.height

    if direction == "north" then
        abs[2] = abs[2] - 1
        rel[2] = rel[2] - 1
    elseif direction == "east" then
        abs[1] = abs[1] + 1
        rel[1] = rel[1] + 1
    elseif direction == "south" then
        abs[2] = abs[2] + 1
        rel[2] = rel[2] + 1
    elseif direction == "west" then
        abs[1] = abs[1] + 1
        rel[2] = rel[2] + 1
    elseif direction == "up" then
        height = height + 1
    elseif direction == "down" then
        height = height - 1
    else
        print(comms.robot_send("error", "update_pos, logical impossibility found"))
    end

    nav_obj.height = height
end

local function change_orientation(goal, nav_obj) 
    local orientation = nav_obj.orientation

    local raw_orientation = convert_orientation(orientation) - 1
    local raw_goal = convert_orientation(goal) - 1

    local numeric = raw_orientation % 2
    local numeric_goal = raw_goal % 2

    -- north 1, % = 1, %4 = 1
    -- south 2, % = 0, %4 = 2

    -- east 3,  % = 1, %4 = 3
    -- west 4,  % = 0, %4 = 0

    local mod_difference = numeric - numeric_goal
    
    -- if abs(mod_difference) == 1, then it is to the left
    -- if abs(mod_difference) == 0, then it either is opposite, and so the move direction doesn't matter,
    --                              or it is to the right

    local move_dir = true
    if mod_difference == 0 then move_dir = false -- right
    elseif math.abs(mod_difference) == 1 then move_dir = true -- left
    else 
        print(comms.robot_send("error", "logical impossibility detected in changing orientation"))
        return false
    end

    while raw_orientation % 4 ~= raw_goal do
        numeric = raw_orientation % 2
        if move_dir then
            robot.turnLeft()
            -- TODO
        end
    end

    nav_obj.orientation = orientation
    return true
end

local function un_convert_orientation(num_side)
    if num_side == 0 then
        return "down"
    elseif num_side == 1 then
        return "up"
    elseif num_side == 2 then 
        return "north"
    elseif num_side == 3 then
        return "south"
    elseif num_side == 4 then
        return "east"
    elseif num_side == 5 then
        return "west"
    else
        print(comms.robot_send("error", "un_convert_orientation, logical impossibility"))
        return "error"
    end
end

local function convert_orientation(nav_obj)
    local orientation = nav_obj.orientation

    if orientation == "north" then
        return 2
    elseif orientation == "east" then
        return 4
    elseif orientation == "south" then
        return 3
    elseif orientation == "west" then
        return 5
    else
        print(comms.robot_send("error", "convert_Orientation, Logical Impossibility found"))
        return -1
    end
end

function base_move(direction, nav_obj) -- return result and error string
    local result = nil
    local err = nil
    print("base_move")
    --io.read()

    if direction == "up" then
        result, err = robot.up()
    elseif direction == "down" then
        result, err = robot.down()         
    else
        change_orientation(direction, nav_obj) 
        result, err = robot.forward()
    end
    print("post thing")
    --io.read()

    if result ~= nil then update_pos(direction, nav_obj) end
    return result, err
end

function module.r_move(a,b,c)
    print("r_move used")
    --io.read()
    real_move(a,b,c)
end

-- TODO -> better cave/hole detection so we don't lose ourselves underground
function real_move(what_kind, direction, nav_obj)
    print("attempting real move")
    if nav_obj == nil then
        print(comms.robot_send("error", "No nav obj provided!"))
    end

    if what_kind == "surface" then
        local can_move, block_type = robot.detectDown()
        if block_type == "air" or block_type == "liquid" then
            print("look for air")
            robot.down()
            update_pos("down", nav_obj)
            return true
        end

        local result, err = base_move(direction, nav_obj)
        print("post base_move")
        if err ~= nil and err == "impossible move" then
            -- for know we just panic, maybe one day we'll add better AI
            print(comms.robot_send("error", "real_move: we just IMPOSSIBLE MOVED OURSELVES"))
            return false
        elseif err ~= nil and err ~= "impossible move" then
            --local orientation = convert_orientation(nav_obj)
            if geolyzer.compare("log", "naive_contains", sides_api.front) == true then
                -- TODO: better chopping?
                robot.swing()
                return true
            else
                real_move("free", "up", nav_obj) -- This is the case for a non tree terrain feature
                return true
            end
        end
    elseif what_kind == "free" then
        print("free move")
        local result, err = base_move(direction, nav_obj)
        if result == nil then
            print(comms.robot_send("error", "real_move: \"" .. what_kind .. "\" || error: \"" .. err .. "\""))
            return false
        end
        return true
    else
        print(comms.robot_send("error", "real_move: \"" .. what_kind .. "\" unimplemented"))
    end

end

function module.debug_move(dir, distance, forget, nav_obj)
    for i = 0, distance, 1 do
        local serial = serialize.serialize(nav_obj, true)
        real_move("free", dir, nav_obj)
    end

    if forget == false then
        print("updating")
        update_pos(dir, nav_obj)
    end
end


return module
