local module = {}

local math = require("math")
local robot = require("robot")
local sides = require("sides")

local comms = require("comms")
local geolyzer = require("geolyzer_wrapper")

-- Internal Map things --
map_x = {}
map_y = {}
map_z = {}

chunk_x = {}
chunk_z = {}
-----------------

-- The robot will understand chunk boundries as movement highways in between chunks
-- and focus inner-chunk movement inside it's own chunk

-- please centre the robot in the top left (north oriented map) of the "origin chunk" 
-- Moving north = -Z, moving east = +X

local c_zero = {0,0}

local abs = {0,0} -- (x,z)
local height = 0
local rel = {0,0} -- (x,z)
local chunk = {0,0} -- (x,z)

local orientation = "north"


-- rel_chunk is 0 inclusive, therefore 0 to 15, and not 1 to 16
-- rel and chunk are unrelated to abs, rather they relate to chunk 0,0 or c_zero

-- Fuck complex path-finding, we'll just grid move with bias for the X direction
function module.navigate(what)

end

local chunk_nearest_side = {0,0}
local rel_nearest_side = {0,0}
local cur_in_road = false

function module.setup_chunk(x, z)
    chunk[1] = x
    chunk[2] = z
end

function setup_absolute(x,z,y)
    abs[1] = x
    abs[2] = z
    height = y
end

function module.update_pos(direction) -- assuming forward move
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
        chunk[2] = chunk[2] -1
    end

    chunk_nearest_side[1] = chunk[1] - what_chunk[1]
    chunk_nearest_side[2] = chunk[2] - what_chunk[2]

    rel_nearest_side[1] = rel[1] - half_chunk_square
    rel_nearest_side[2] = rel[2] - half_chunk_square
end


function module.change_orientation(goal) 
    while orientation ~= goal do
        robot.turnRight()
        if orientation == "north" then
            orientation = "east"
        elseif orientation == "east" then
            orientation = "south"     
        elseif orientation == "south" then
            orientation = "west"
        elseif orientation == "west" then
            orientation = "north"
        else
            print(comms.robot_send("error", "Change_Orientation, Logical Impossibility found"))
        end
    end
end

function module.convert_orientation(o_orient)
    if o_orient == "north" then
        return 2
    elseif o_orient == "east" then
        return 4
    elseif o_orient == "south" then
        return 3
    elseif o_orient == "west" then
        return 5
    else
        print(comms.robot_send("error", "convert_Orientation, Logical Impossibility found"))
    end
end

function module.base_move(direction) -- return result and error string
    local result, err = nil, nil
    if direction == "up" then
        result, err = robot.up()
    elseif direction == "down" then
        result, err = robot.down()         
    else
        change_orientation(direction) 
        result, err = robot.forward()
    end

    if result ~= nil then update_pos(direction) end
    return result, err
end

-- TODO -> better cave/hole detection so we don't lose ourselves underground
function module.real_move(what_kind, direction)
    print("attempting real move")
    if what_kind == "surface" then
        local can_move, block_type = robot.detectDown()
        if block_type == "air" or block_type == "liquid" then
            robot.down()
            height = height - height
        end

        local result, err = base_move(direction)
        if err ~= nil and err == "impossible move" then
            -- for know we just panic, maybe one day we'll add better AI
            print(comms.robot_send("error", "real_move: we just IMPOSSIBLE MOVED OURSELVES"))
        elseif err ~= nil and err ~= "impossible move" then
            local o_orient = convert_orientation(orientation)
            if geolyzer.compare("log", "naive_contains", o_orient) == true then
                robot.swing()
            else
                real_move("free", "up") -- This is the case for a non tree terrain feature
            end
        end
    elseif what_kind == "free" then
        local result, err = base_move(direction)
        if result == nil then
            print(comms.robot_send("error", "real_move: \"" .. what_kind .. "\" || error: \"" .. err .. "\""))
        end

    else
        print(comms.robot_send("error", "real_move: \"" .. what_kind .. "\" unimplemented"))
    end
end

function module.debug_move(dir, distance, forget)
    for i = 0, distance, 1 do
        print(i)
        real_move("free", dir)
    end

    if forget == false then
        print("updating")
        update_pos(dir)
    end
end

function module.setup_navigate_chunk(what_chunk)
    cur_in_road = false

    chunk_nearest_side = {0,0}
    chunk_nearest_side[1] = chunk[1] - what_chunk[1]
    chunk_nearest_side[2] = chunk[2] - what_chunk[2]
    -- Example if chunk is to the bottom-left coords become: {1, -1},
    -- if chunk is to top-right coords become: {-1, 1} (the number might be bigger/smaller than 1)
    
    local half_chunk_square = 8
    rel_nearest_side = {0,0}
    rel_nearest_side[1] = rel[1] - half_chunk_square
    rel_nearest_side[2] = rel[2] - half_chunk_square
end

-- returns if it is finished
function module.navigate_chunk(what_kind)
    -- I feel as if this 2 bools are logically overlapping too much so i'll comment out 1 of em
    --local bool1 = (math.abs(rel_nearest_side[1]) < 8) or (math.abs(rel_nearest_side[2]) < 8)
    local bool1 = true
    cur_in_road = (math.abs(rel_nearest_side[1]) == 8) or (math.abs(rel_nearest_side[2]) == 8)

    -- "move to the road"
    if bool1 == true and cur_in_road == false then
        if rel_nearest_side[1] > 0 then real_move(what_kind, "east")
        elseif rel_nearest_side[1] < 0 then real_move(what_kind, "west")
        elseif rel_nearest_side[2] > 0 then real_move(what_kind, "south")
        elseif rel_nearest_side[2] < 0 then real_move(what_kind, "north") 
        else print(comms.robot_send("error", "Navigate Chunk, find nearest side fatal logic impossibility detected")) end

        return false
    end

    if (chunk_nearest_side[1] ~= 0) or (chunk_nearest_side[2] ~= 0) then
        if chunk_nearest_side[1] < 0 then -- move right
            real_move(what_kind, "east")
        elseif chunk_nearest_side[1] > 0 then
            real_move(what_kind, "west")
        elseif chunk_nearest_side[2] < 0 then
            real_move(what_kind, "south")
        else
            real_move(what_kind, "north")
        end
        return false
    end

    print(comms.robot_send("info", "We've arrived at the target chunk"))
    return true
end
function module.mark_chunk(what_chunk, as_what)

end

return module
