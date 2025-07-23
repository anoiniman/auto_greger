local module = {}

local comms = require("comms")
local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")

function module.need_move(what_chunk, door_info)
    local target_build = map.find_build(what_chunk, door_info) -- should be fine?
    local cur_build = nav.get_cur_building()
    if cur_build ~= nil and target_build == cur_build then return false end
    return true
end


-- state is introduced here
local chunk_moved = false

-- false == continue, true == over
function module.do_move(what_chunk, door_info)
    --------- CHUNK MOVE -----------
    if not chunk_moved and not nav.is_in_chunk(what_chunk) then
        -- print("debug", "move_chunk")
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(what_chunk)
        end
        chunk_moved = nav.navigate_chunk("surface") -- for now surface move only
        return false
    end

    -------- SANITY CHECK ---------
    if nav.is_setup_navigate_chunk() then
        error(comms.robot_send("fatal", "eval, nav_and_build, did navigation not terminate gracefully?"))
    end
    -------- DO MOVE DOOR ----------
    if door_info ~= nil and #door_info ~= 0 then
        -- print("debug", "move_door")
        if not nav.is_setup_door_move() then nav.setup_door_move(door_info) end
        local result, err = nav.door_move()

        if result == 1 then
            if err == nil then err = "nil" end
            if err ~= "swong" then error(comms.robot_send("fatal", "nav_to_build: this is unexpected!")) end
            return false
        elseif result == -1 then
            --instructions:delete("door_info") -- necessary for code to advance to rel_move section
        elseif result == 0 then return false
        else error(comms.robot_send("fatal", "nav_to_build: unexpected2!")) end
    end

    -- print("debug", "done_move")
    chunk_moved = false
    nav.set_cur_building(map.find_build(what_chunk, door_info)) -- should be fine?
    return true
end

return module
