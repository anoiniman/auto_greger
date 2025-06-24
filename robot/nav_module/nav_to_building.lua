local module = {}

local comms = require("comms")
local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")

local function find_build(what_chunk, door_info)
    local quads = map.get_chunk(what_chunk).chunk.meta_quads
    local cur_quad = nil
    for _, quad in ipairs(quads) do
        local doors = quad:getDoors()
        for _, door in ipairs(doors) do
            if door == door_info then -- checks if references match
                cur_quad = quad
                break
            end
        end
    end

    return cur_quad:getBuild()
end

function module.need_move(what_chunk, door_info)
    local target_build = find_build(what_chunk, door_info) -- should be fine?
    local cur_build = nav.nav_obj.cur_building
    if target_build == cur_build then return false end
    return true
end


-- false == continue, true == over
function module.do_move(what_chunk, door_info)
    --------- CHUNK MOVE -----------
    if not nav.is_in_chunk() then
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

    nav.nav_obj.cur_building = find_build(what_chunk, door_info) -- should be fine?
    return true
end

return module
