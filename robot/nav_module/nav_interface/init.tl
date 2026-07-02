local robot = require("robot")
--local sides_api = require("sides")
require("Position")

require("prelude")
local comms = require("comms")
local nav = require("nav_module.nav_obj")
local strat = require("nav_module.nav_interface.strategies")

global enum StratResult
    "impossible move"
    "not enough energy"
    "entity"
    "solid"
    "replaceable"
    "liquid"
    "passable"
    "air"
    
    "lava"
end


local record to_export 
    real_move: function (string, DirectionEnum, ExtraSauce): boolean, StratResult | nil
end
local record inward_facing 
    change_orientation: function(DirectionEnum)
end

function inward_facing.update_pos(direction: DirectionEnum) -- assuming forward move
    local nav_obj = nav.get_obj()

    local abs: {integer, integer, integer} = nav_obj.abs
    local height = nav_obj.height

    if direction == "north" then
        abs[2] = abs[2] - 1
    elseif direction == "east" then
        abs[1] = abs[1] + 1
    elseif direction == "south" then
        abs[2] = abs[2] + 1
    elseif direction == "west" then
        abs[1] = abs[1] - 1
    elseif direction == "up" then
        height = height + 1
    elseif direction == "down" then
        height = height - 1
    else
        print(comms.robot_send("error", "update_pos, logical impossibility found"))
    end

    nav_obj.height = height
end

function inward_facing.un_convert_orientation(num_side: integer): DirectionEnum
    if num_side == 1 then
        return "down"
    elseif num_side == 2 then
        return "up"
    elseif num_side == 3 then
        return "north"
    elseif num_side == 4 then
        return "east"
    elseif num_side == 5 then
        return "south"
    elseif num_side == 6 then
        return "west"
    else
        print(comms.robot_send("error", "un_convert_orientation, logical impossibility"))
        return "error" as DirectionEnum
    end
end

-- NOT SIDES_API COMPATIBLE ANYMORE
function inward_facing.convert_orientation(orientation: DirectionEnum): integer
    if orientation == "north" then
        return 3
    elseif orientation == "east" then
        return 4
    elseif orientation == "south" then
        return 5
    elseif orientation == "west" then
        return 6
    else
        print(comms.robot_send("error", "convert_Orientation, Logical Impossibility found"))
        print(comms.robot_send("error", "orientation: " .. orientation))
        return -1
    end
end

function to_export.rotate_right()
    local nav_obj = nav.get_obj()
    local orient = nav_obj.orientation

    if orient == "north" then
        inward_facing.change_orientation("east")
    elseif orient == "east" then
        inward_facing.change_orientation("south")
    elseif orient == "south" then
        inward_facing.change_orientation("west")
    elseif orient == "west" then
        inward_facing.change_orientation("north")
    else
        error(comms.robot_send("fatal", "invalid state nav_interface.rotate_right"))
    end
end

function inward_facing.get_opposite_orientation(): DirectionEnum
    local nav_obj = nav.get_obj()
    local orientation = nav_obj.orientation

    if orientation == "north" then
        return "south"
    elseif orientation == "east" then
        return "west"
    elseif orientation == "south" then
        return "north"
    elseif orientation == "west" then
        return "east"
    elseif orientation == "up" then
        return "down"
    elseif orientation == "down" then
        return "up"
    else
        print(comms.robot_send("error", "get_opposite_orientation, Logical Impossibility found"))
        print(comms.robot_send("error", "orientation: " .. orientation))
        return nil as DirectionEnum
    end
end

function to_export.get_opposite_orientation(): DirectionEnum
    return inward_facing.get_opposite_orientation()
end

function inward_facing.change_orientation(goal: DirectionEnum)
    local nav_obj = nav.get_obj()
    local orientation = nav_obj.orientation

    local numeric = inward_facing.convert_orientation(orientation) - 2 -- (alignement)
    local num_goal = inward_facing.convert_orientation(goal) - 2

    local difference = numeric - num_goal

    while numeric ~= num_goal do
        if difference > 0 then
            if numeric == 4 and num_goal == 1 then
                robot.turnRight()
                numeric = 1
            else
                robot.turnLeft()
                numeric = numeric - 1
            end
        else -- difference < 0
            if numeric == 1 and num_goal == 4 then
                robot.turnLeft()
                numeric = 4
            else
                robot.turnRight()
                numeric = numeric + 1
            end
        end
    end

    nav_obj.orientation = goal
end

function to_export.change_orientation(goal: DirectionEnum)
    return inward_facing.change_orientation(goal)
end

function inward_facing.base_move(direction: DirectionEnum): boolean, BaseMoveResult | nil
    local result: boolean
    local err: BaseMoveResult | nil

    if direction == "up" then
        result, err = robot.up()
    elseif direction == "down" then
        result, err = robot.down()
    else
        inward_facing.change_orientation(direction)
        result, err = robot.forward()
    end

    -- Translate result to boolean, since this is the standard we've been using in the rest of the programme
    if result ~= nil then inward_facing.update_pos(direction)
    else result = false end

    return result, err
end

local type StratFunction = function(inward_facing, DirectionEnum, ExtraSauce)
local type ExtraSauce = {any}
-- EMPTY_TABLE = {}
-- TODO -> better cave/hole detection so we don't lose ourselves underground
-- Returning true means move sucesseful
function inward_facing.real_move(strat_name: string, direction: DirectionEnum, extra_sauce?: ExtraSauce): boolean, StratResult | nil
    if extra_sauce == nil then extra_sauce = EMPTY_TABLE end -- nice hack!

    -- accept the direct injection without looking twice -- using this for other purposes is UB :>
    -- ('other' is defined as: not executing a movement strategy)
    if type(strat_name) == "function" then
        return (strat_name as StratFunction)(inward_facing, direction, extra_sauce)
    end

    local what_strat: StratFunction
    if strat_name == "surface" then
        what_strat = strat.surface
    elseif strat_name == "free" then
        what_strat = strat.free
    else
        print(comms.robot_send("error", "real_move: \"" .. strat_name .. "\" unimplemented"))
        return false, nil
    end

    return what_strat(inward_facing, direction, extra_sauce)
end

function to_export.debug_move(dir: DirectionEnum, distance: integer): boolean, BaseMoveResult | nil
    local result: boolean
    local err: StratResult | nil

    for _ = 1, distance, 1 do
        result, err = inward_facing.real_move("free", dir)
        if not result then break end
    end

    return result, err as BaseMoveResult
end

function to_export.force_forward(): boolean, BaseMoveResult | nil
    local nav_obj = nav.get_obj()
    return to_export.debug_move(nav_obj.orientation, 1)
end

to_export.real_move = inward_facing.real_move
return to_export
