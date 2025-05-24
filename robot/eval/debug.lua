local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local deep_copy = require("deep_copy")
local comms = require("comms")


local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")
local reason = require("reasoning.reasoning_obj")


local function print_obj(obj)
    local copy = deep_copy.copy_no_functions(obj, pairs)
    local serial = serialize.serialize(copy, 50)
    comms.robot_send("info", serial)
end

function module.echo(arguments)
    local text = serialize.serialize(arguments, true)
    print("Debug -- Attempting to Echo")
    print(comms.robot_send("response", text))
end

function module.debug(arguments)
    if arguments[1] == "geolyzer" then
        local side = arguments[2]
        if side == nil then -- expects sides api derived num
            side = 0 -- defaults to down
        end
        side = tonumber(side)
        geolyzer.debug_print(side)
    elseif arguments[1] == "move" then
        local move = arguments[2]
        local how_much = arguments[3]
        local forget = arguments[4]
        if move == nil then
            print(comms.robot_send("error", "nil direction in debug move"))
            return nil
        end
        if how_much == nil then
            how_much = 1
        end
        if forget == nil then
            forget = false
        end

        print("attempting to move")
        nav.debug_move(move, how_much, forget)
    elseif arguments[1] == "surface_move" then
        local x = arguments[2]
        local z = arguments[3]

        if x == nil or z == nil then
            print(comms.robot_send("error", "nil objective chunk in debug surface_move"))
            return nil
        end
        local chunk = {x,z}
        nav.setup_navigate_chunk(chunk)
        return {50, "navigate_chunk", "surface"}
    elseif arguments[1] == "set_orientation" then
        local o = arguments[2]
        if o == nil then
            print(comms.robot_send("error", "set_orientation: no orientation mentioned"))
            return nil
        elseif o ~= "north" and o ~= "south" and o ~= "east" and o ~= "west" then
            print(comms.robot_send("error", "set_orientation: mis-formated"))
            return nil
        end
        nav.set_orientation(o)
    elseif arguments[1] == "set_height" then
        local height = tonumber(arguments[2])
        if height == nil then
            print(comms.robot_send("error", "set_height: no orientation provided"))
            return nil
        end
        nav.set_height(height)
    elseif arguments[1] == "print" then
        if arguments[2] == "nav" then
            print_obj(nav)
        elseif arguments[2] == "inv" then
            print_obj(inv)
        elseif arguments[2] == "map" then
            print_obj(map)
        elseif arguments[2] == "reason" then
            print_obj(reason)
        else
            print(comms.robot_send("error", "invalid object provided"))
        end
    else
        print(comms.robot_send("error", "non-recogized arguments for debug"))
    end
    return nil
end

return module
