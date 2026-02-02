local module = {}

local comms = require("comms")
local map = require("nav_module.map_obj")

local nav = require("nav_module.nav_obj")
local chunk_move = require("nav_module.chunk_move")
local door_move = require("nav_module.door_move")

function module.need_move(what_chunk, door_info)
    local target_build = map.find_build(what_chunk, door_info) -- should be fine?
    local cur_build = nav.get_cur_building()
    if cur_build ~= nil and target_build == cur_build then
        print(comms.robot_send("debug", "we're in building"))
        return false
    end

    print(comms.robot_send("debug", "we're not in building"))
    return true
end


-- state is introduced here
local chunk_moved = false

-- false == continue, true == over
function module.do_move(what_chunk, door_info)
    local nav_obj = nav.get_obj()
    --------- CHUNK MOVE -----------
    if not chunk_moved then
        -- print("debug", "move_chunk")
        if not chunk_move.is_setup() then
            chunk_move.setup_navigate_chunk(what_chunk, nav_obj)
        end
        chunk_moved = chunk_move.navigate_chunk("surface", nav_obj) -- for now surface move only
        return false
    end

    -------- SANITY CHECK ---------
    if chunk_move.is_setup() then
        -- nav.force_reset_navigate_chunk()
        error(comms.robot_send("fatal", "eval, nav_and_build, did navigation not terminate gracefully?"))
    end
    -------- DO MOVE DOOR ----------
    if door_info ~= nil and #door_info ~= 0 then
        -- print("debug", "move_door")
        if not door_move.is_setup() then door_move.setup_move(door_info, nav.get_rel()) end
        local result, err = door_move.do_move()

        if result == 1 then
            if err == nil then err = "nil" end
            if err ~= "swong" then print(comms.robot_send("error", "nav_to_build: this is unexpected!: " .. err)); os.sleep(2) end
            return false
        elseif result == -1 then
            --instructions:delete("door_info") -- necessary for code to advance to rel_move section
        elseif result == 0 then return false
        else error(comms.robot_send("fatal", "nav_to_build: unexpected2!")) end
    end

    -- print(comms.robot_send("debug", "nav_to_build done"))
    chunk_moved = false
    nav.set_cur_building(map.find_build(what_chunk, door_info)) -- should be fine?
    return true
end

return module
