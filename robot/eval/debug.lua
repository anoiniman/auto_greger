-- luacheck: globals DO_DEBUG_PRINT
local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local deep_copy = require("deep_copy")
local comms = require("comms")
local post_exit = require("post_exit")


local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")
local reason = require("reasoning.reasoning_obj")


local function print_obj(obj)
    local copy = deep_copy.copy_no_functions(obj) -- this prob no worky because of how require works :/
    local serial = serialize.serialize(copy, 70)
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
            print(comms.robot_send("error", "set_height: no valid number provided"))
            return nil
        end
        nav.set_height(height)
    elseif arguments[1] == "set_pos" then -- x and z as abs
        local x = tonumber(arguments[2])
        local z = tonumber(arguments[3])
        local y = tonumber(arguments[4])
        if x == nil then print(comms.robot_send("error", "set_pos: invalid x")) end
        if z == nil then print(comms.robot_send("error", "set_pos: invalid z")) end

        nav.set_pos_auto(x, z, y)

    elseif arguments[1] == "print" then
        if arguments[2] == "nav" then
            nav.print_nav_obj()
        elseif arguments[2] == "inv" then
            print_obj(inv)
        elseif arguments[2] == "map" then
            print_obj(map)
        elseif arguments[2] == "reason" then
            print_obj(reason)
        else
            print(comms.robot_send("error", "invalid object provided"))
        end
    elseif arguments[1] == "inv" or arguments[1] == "inventory" then

        if arguments[2] == "list" then
            if arguments[3] == "external" then
                inv.list_external_inv()
            else
                print(comms.robot_send("error", "invalid inv-list argument provided"))
            end

        elseif arguments[2] == "print" then
            if arguments[3] == "internal" then
                local pp_obj = inv.virtual_inventory:getFmtObj() -- it's already pre-built for us
                local new_obj = deep_copy.copy(pp_obj)
                new_obj:printPage(false)

                local castrated_object = deep_copy.copy_no_functions(pp_obj)
                comms.send_command("execute", "ppObj", "printPage", castrated_object, false)
            elseif arguments[3] == "external" then
                local name = arguments[5]; local index = tonumber(arguments[6]);
                if name == "nil" then name = nil end
                if index <= 0 then index = nil end

                local uncompressed = arguments[4]
                if uncompressed == "full" or uncompressed == "uncompressed" or uncompressed == "-u"  then
                    uncompressed = true
                else uncompressed = false end

                inv.print_external_inv(name, index, uncompressed)
            end
        elseif arguments[2] == "force" then
            if arguments[3] == "add_all" then
                if arguments[4] == "internal" or arguments[4] == nil then
                    inv.force_update_vinv()
                else
                    print(comms.robot_send("error", "invalid arguments for inv force add_all"))
                end
            elseif arguments[3] == "add_to" or arguments[3] == "at" then -- TODO FROM HERE <----
                local table_name = arguments[4]
                local index = tonumber(arguments[5])
                local lable = arguments[6]
                local name = arguments[7]
                local to_add = tonumber(arguments[7])

                inv.add_item_to_external(table_name, index, lable, name, to_add)
            elseif arguments[3] == "remove_from" or arguments[3] == "rf" then
                local table_name = arguments[4]
                local index = tonumber(arguments[5])
                local slot = tonumber(arguments[6])
                local to_remove = tonumber(arguments[7])

                inv.remove_stack_from_external(table_name, index, slot, to_remove)
            end
        else
            print(comms.robot_send("error", "invalid arguments"))
        end
    elseif arguments[1] == "debug_mode" then
        if arguments[2] == "on" or tonumber(arguments[2]) == 1 then
            DO_DEBUG_PRINT = true
        elseif arguments[2] == "off" or tonumber(arguments[2]) == 0 then
            DO_DEBUG_PRINT = false
        else
            print(comms.robot_send("error", "invalid arguments"))
        end
    elseif arguments[1] == "save" then
        post_exit.save_state()
    elseif arguments[1] == "load" then
        table.remove(arguments, 1)
        local exclude_table = arguments
        post_exit.load_state(exclude_table)
    elseif arguments[1] == "pretend_build" then
        local area_name = tostring(arguments[2])
        local name = tostring(arguments[3])
        local x = tonumber(arguments[4])
        local z = tonumber(arguments[5])
        local quad = tonumber(arguments[6])

        if name == nil or x == nil or z == nil or quad == nil then
            print(comms.robot_send("error", "pretend_build invalid arguments"))
            return nil
        end
        local what_chunk = {x, z}
        local err = map.pretend_build(area_name, name, what_chunk, quad)
        if err ~= 0 then
            print(comms.robot_send("error", "error in pretending at: " .. err))
        end
    else
        print(comms.robot_send("error", "non-recogized arguments for debug"))
    end
    return nil
end

local function fixed_pretend_build(area_name, name, what_chunk, quad)
    local err = map.pretend_build(area_name, name, what_chunk, quad)
    if err ~= 0 then
        print(comms.robot_send("error", "error in FIXED pretending at: " .. err))
    end
end

-- temp
local chunk = {-2, 0}
fixed_pretend_build("home", "coke_quad", chunk, 1)
fixed_pretend_build("home", "oak_tree_farm", chunk, 3)

return module
