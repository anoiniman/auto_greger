-- luacheck: globals DO_DEBUG_PRINT HOME_CHUNK FORCE_INTERRUPT_ORE
local module = {}

-- import of globals
local serialize = require("serialization")
local robot = require("robot")
local keyboard = require("keyboard")
local sides_api = require("sides")

-- local imports
local deep_copy = require("deep_copy")
local comms = require("comms")
local post_exit = require("post_exit")

local geolyzer = require("geolyzer_wrapper")
local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local inv = require("inventory.inv_obj")
local loadouts = require("inventory.loadouts")

local reason = require("reasoning.reasoning_obj")
local _, ore = table.unpack(require("reasoning.recipes.stone_age.gathering_ore"))

local component = require("component")
local inv_controller = component.getPrimary("inventory_controller")


local known_symbols = {
    geolyzer = geolyzer,
    nav = nav,
    map = map,
    inv = inv,
    reason = reason,
}


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
    elseif arguments[1] == "set_home" then -- PLEASE NEVER FORGET TO DO THIS!
        local x = tonumber(arguments[2])
        local z = tonumber(arguments[3])
        if x == nil or z == nil then
            print(comms.robot_send("error", "Invalid argument(s)"))
            return nil
        end

        HOME_CHUNK[1] = x
        HOME_CHUNK[2] = z
        print(comms.robot_send("info", string.format("HOME_CHUNK = (%s, %s)", HOME_CHUNK[1], HOME_CHUNK[2])))
    elseif arguments[1] == "dig_move" then
        local dir = arguments[2]
        local to_move = tonumber(arguments[3])
        local use_tool = arguments[3]

        if dir == nil then
            print(comms.robot_send("error", "nil direction in debug move"))
            return nil
        end
        if to_move == nil then to_move = 1 end

        for i = 1, to_move, 1 do
            os.sleep(0.1)
            if keyboard.isKeyDown(keyboard.keys.q) then break end
            local result, err = nav.debug_move(dir, 1)
            if err == "impossible" then
                print(comms.robot_send("error", "impossible move reached"))
                break
            elseif err == "solid" then
                local s_result
                if use_tool ~= nil then s_result = inv.smart_swing(use_tool, "front", 0)
                else s_result = inv.blind_swing_front() end

                if not s_result then
                    print(comms.robot_send("error", "it was unbreakable desu"))
                    break
                end

                nav.debug_move(dir, 1)
            elseif err ~= nil then
                print(comms.robot_send("error", string.format("err: %s move reached", err)))
                break
            end
        end
    elseif arguments[1] == "move" then
        local move = arguments[2]
        local how_much = tonumber(arguments[3])
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
    elseif arguments[1] == "surface_chunk_move" then
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

    elseif arguments[1] == "place" then
        local dir = tostring(arguments[2])
        local lable = tostring(arguments[3])
        local name = tostring(arguments[4])

        if dir == nil or lable == nil or name == nil then
            print(comms.robot_send("error", "Try again"))
            return nil
        end

        inv.place_block(dir, {lable = lable, name = name}, "table")
    elseif arguments[1] == "swing" then
        local dir = arguments[2]
        if dir == nil then dir = "front" end

        local be_blind = arguments[3]
        if be_blind == nil then be_blind = false
        elseif  (type(be_blind) == "string" and be_blind == "true")
                or (type(be_blind) == "number" and be_blind == 1)
        then
            be_blind = true
        else be_blind = false end


        if be_blind then
            if dir == "front" then inv.blind_swing_front()
            elseif dir == "down" then inv.blind_swing_down()
            elseif dir == "up" then inv.blind_swing_up()
            else
                print(comms.robot_send("error", string.format("dir is invalid: \"%s\"", dir)))
                return nil
            end
        else
            if dir == "front" then robot.swing()
            elseif dir == "down" then robot.swingDown()
            elseif dir == "up" then robot.swingUp()
            else
                print(comms.robot_send("error", string.format("dir is invalid: \"%s\"", dir)))
                return nil
            end
            inv.maybe_something_added_to_inv()
        end

    elseif arguments[1] == "equip" then
        local tool_type = arguments[2]
        local tool_level = tonumber(arguments[3])

        if tool_type == nil then
            print(comms.robot_send("error", "tool_type is nil"))
            return nil
        end

        if tool_level == nil then
            --[[print(comms.robot_send("error", "tool_level is nil, or invalid"))
            return nil--]]
            tool_level = 0
        end

        local result = inv.equip_tool(tool_type, tool_level)
        if not result then
            print(comms.robot_send("error", "failed to equip tool"))
        end

    elseif arguments[1] == "print" then
        if arguments[2] == "nav" then
            nav.print_nav_obj()
        elseif arguments[2] == "inv" then
        elseif arguments[2] == "map" then
        elseif arguments[2] == "reason" then
        else
            print(comms.robot_send("error", "invalid object provided"))
        end
    elseif arguments[1] == "inv" or arguments[1] == "inventory" then

        if arguments[2] == "list" then
            if arguments[3] == "external" or arguments[3] == nil then
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
                comms.send_command("ppObj", "printPage", castrated_object, false)
            elseif arguments[3] == "external" then
                local name = arguments[5]; local index = tonumber(arguments[6]);
                if name == "nil" then name = nil end
                if index == nil or index <= 0 then index = nil end

                local uncompressed = arguments[4]
                if uncompressed == "full" or uncompressed == "uncompressed" or uncompressed == "-u"  then
                    uncompressed = true
                else uncompressed = false end

                inv.print_external_inv(name, index, uncompressed)
                return nil
            end
        elseif arguments[2] == "drop_into_slot" then -- doesn't update internal/external inventory :P, remember to force update
            local internal_slot = tonumber(arguments[3])
            local external_slot = tonumber(arguments[4])
            local count = tonumber(arguments[5])

            if internal_slot == nil or external_slot == nil then
                print(comms.robot_send("error", "Bad internal/external slot"))
                return nil
            end

            robot.select(internal_slot)
            inv_controller.drop_into_slot(sides_api.front, external_slot, count)
            robot.select(1)

        elseif arguments[2] == "suck_from_slot" then
            local internal_slot = tonumber(arguments[3])
            local external_slot = tonumber(arguments[4])
            local count = tonumber(arguments[5])

            if internal_slot == nil or external_slot == nil then
                print(comms.robot_send("error", "Bad internal/external slot"))
                return nil
            end

            robot.select(internal_slot)
            inv_controller.suck_from_slot(sides_api.front, external_slot, count)
            robot.select(1)

        elseif arguments[2] == "force" then
            if arguments[3] == "add_all" then
                if arguments[4] == "internal" or arguments[4] == nil then
                    inv.force_update_vinv()
                else
                    print(comms.robot_send("error", "invalid arguments for inv force add_all"))
                    return nil
                end
            elseif arguments[3] == "add_to" or arguments[3] == "at" then
                local table_name = arguments[4]
                local index = tonumber(arguments[5])
                local lable = arguments[6]
                local name = arguments[7]
                local to_add = tonumber(arguments[8])

                inv.add_item_to_external(table_name, index, lable, name, to_add)
            elseif arguments[3] == "set" then
                local slot = tonumber(arguments[4])
                if slot == nil then
                    print(comms.robot_send("error", "invalid slot for inv force set"))
                    return nil
                end

                local lable = tostring(arguments[5])
                if lable == nil then
                    print(comms.robot_send("error", "invalid lable for inv force set"))
                    return nil
                end
                lable = string.gsub(lable, "_", " ")

                local name = tostring(arguments[6])
                if name == "nil" then name = nil end

                local quantity = tonumber(arguments[7])

                inv.force_set_slot_as(slot, lable, name, quantity)
            elseif arguments[3] == "remove_from" or arguments[3] == "rf" then
                local table_name = arguments[4]
                local index = tonumber(arguments[5])
                local slot = tonumber(arguments[6])
                local to_remove = tonumber(arguments[7])

                inv.remove_stack_from_external(table_name, index, slot, to_remove)
            elseif arguments[3] == "reload_loadout" or arguments[3] == "rl" then
                local priority = tonumber(arguments[4])
                if priority == nil then
                    print(comms.robot_send("error", "priority is invalid"))
                    return nil
                end

                local name, command_table = loadouts.do_loadout(priority) -- forces robot to try and handle it's loadout
                return command_table
            else
                print(comms.robot_send("error", "invalid arguments for inv force"))
            end
        else
            print(comms.robot_send("error", "invalid arguments"))
        end

    elseif arguments[1] == "reas" or arguments[1] == "reasoning" then

        if arguments[2] == "print_dud" then
            reason.print_dud()
        elseif arguments[2] == "print_script" then
            print(comms.robot_send("info", "Not ready yet!"))
        elseif arguments[2] == "reset_one" or arguments[2] == "r1" then
            reason.reset_one_locks()  -- Don't run with commands in the queue DANGEROUS
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
    elseif arguments[1] == "load_preset" then
        local symbol_name = arguments[2]
        if symbol_name == nil then
            print(comms.robot_send("error", "load_preset, name needed as argument"))
            return nil
        end

        local t_symbol = known_symbols[symbol_name]
        if t_symbol == nil then
            print(comms.robot_send("error", "load_preset, name is invalid"))
            return nil
        end

        local has_func = t_symbol.load_preset
        if has_func == nil then
            print(comms.robot_send("error", "load_preset, name exists but has no load_preset func"))
            return nil
        end

        t_symbol.load_preset()
    elseif arguments[1] == "print_build_inventory" or arguments[1] == "pbi" then
        local name = arguments[2]
        local index = tonumber(arguments[3])

        if name == nil or index == nil then
            print(comms.robot_send("error", "print_build_inventory name/index are nil/invalid"))
            return nil
        end
        local uncompressed = arguments[4]
        if uncompressed == nil or uncompressed == "false" or uncompressed == '0' then uncompressed = false
        elseif uncompressed == "true" or uncompressed == '1' then uncompressed = true
        else uncompressed = false end

        inv.print_build_inventory(map, uncompressed, name, index)
        return nil
    elseif arguments[1] == "add_to_inventory" or arguments[1] == "ati" then
        local build_name = arguments[2]
        local index = tonumber(arguments[3])
        local lable = arguments[4]
        local name = arguments[5]
        local quantity = tonumber(arguments[6])
        local slot_num = tonumber(arguments[7])

        if build_name == nil or index == nil or lable == nil or name == nil or quantity == nil or slot_num == nil then
            print(comms.robot_send("error", "add_to_inventory something is nil/invalid"))
            return nil
        end

        inv.add_to_inventory(map, build_name, index, lable, name, quantity, slot_num)
    elseif arguments[1] == "force_set_build" or arguments[1] == "fsb" then
        local x = tonumber(arguments[2])
        local z = tonumber(arguments[3])
        if x == nil or z == nil then
            print(comms.robot_send("error", "force_set_building error: one of the chunk coords is nil/invalid"))
            return nil
        end

        local what_chunk = {x, z}

        local what_quad = tonumber(arguments[4])
        if what_quad == nil then
            print(comms.robot_send("error", "force_set_building error: what_quad is nil/invalid"))
            return nil
        end

        if not map.force_set_build(nav, what_chunk, what_quad) then
            print(comms.robot_send("error", "force_set_building error in function"))
            return nil
        end
    elseif arguments[1] == "get_inv_pos" or arguments[1] == "gip" then
        local bd_name = arguments[2]
        local bd_index = tonumber(arguments[3])
        local state_index = tonumber(arguments[4])
        local inv_index = tonumber(arguments[5])

        if bd_name == nil or bd_index == nil or state_index == nil then
            print(comms.robot_send("error", "get_inv_pos, something is invalid or nil or whatever"))
            return nil
        end

        inv.get_inv_pos(map, bd_name, bd_index, state_index, inv_index)
        return nil
    elseif arguments[1] == "ore_manager" or arguments[1] == "om" then
        local state_list = ore.state_list
        if arguments[2] == "list_chunks" or arguments[2] == "ls" then
            local buffer = {"\n"}
            for index, state in ipairs(state_list) do
                local chunk = state.chunk
                table.insert(buffer, string.format("[%03d] (%05d, %05d)\n", index, chunk[1], chunk[2]))
            end
            print(comms.robot_send("info", table.concat(buffer)))
        elseif arguments[2] == "set_chunk_as_explorable" or arguments[2] == "exp" then
            -- good for forcing a robot to revisit an "unmineable" chunk
            local x = tonumber(arguments[3])
            local z = tonumber(arguments[4])
            if x == nil or z == nil then
                print(comms.robot_send("error", "bad coordinates @ 'exp'"))
                return nil
            end
            local wanted_chunk = {x, z}

            local found_state = nil
            for _, state in ipairs(state_list) do
                if state.chunk[1] == wanted_chunk[1] and state.chunk[2] == wanted_chunk[2] then
                    found_state = state
                    break
                end
            end
            if found_state == nil then
                print(comms.robot_send("error", "such a state with such chunk coordinates does not exist"))
                return nil
            end

            found_state.chunk_ore = "explorable"
        elseif arguments[2] == "halt" or arguments[2] == "stop" or arguments[2] == "force_interrupt_ore" then
            FORCE_INTERRUPT_ORE = true
        elseif arguments[2] == "unhalt" or arguments[2] == "resume" then
            FORCE_INTERRUPT_ORE = false
        else
            print(comms.robot_send("error", "non-recogized arguments for ore_manager"))
        end
    else
        print(comms.robot_send("error", "non-recogized arguments for debug"))
    end

    return nil
end

return module
