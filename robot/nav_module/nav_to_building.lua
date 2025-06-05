local module = {}

local comms = require("comms")
local nav = require("nav_module.nav_obj")

-- false == continue, true == over
function module.do_move(what_chunk, door_info)
    --------- CHUNK MOVE -----------
    local cur_chunk = nav.get_chunk()
    --print(comms.robot_send("debug", "cur_coords: " .. cur_chunk[1] .. ", " .. cur_chunk[2]))
    if cur_chunk[1] ~= what_chunk[1] or cur_chunk[2] ~= what_chunk[2] then
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(what_chunk)
        end
        nav.navigate_chunk("surface") -- for now surface move only

        return false
    end

    -------- SANITY CHECK ---------
    if nav.is_setup_navigate_chunk() then
        error(comms.robot_send("fatal", "eval, nav_and_build, did navigation not terminate gracefully?"))
    end
    -------- DO MOVE DOOR ----------
    if door_info ~= nil and #door_info ~= 0 then
        if not nav.is_setup_door_move() then nav.setup_door_move(door_info) end
        local result, err = nav.door_move()

        if result == 1 then
            if err == nil then err = "nil" end
            if err ~= "swong" then error(comms.robot_send("fatal", "nav_to_build: this is unexpected!")) end
            return false
        elseif result == -1 then
            return true
            --instructions:delete("door_info") -- necessary for code to advance to rel_move section
        elseif result == 0 then return false
        else error(comms.robot_send("fatal", "nav_to_build: unexpected2!")) end
    end

    return false
end

return module
