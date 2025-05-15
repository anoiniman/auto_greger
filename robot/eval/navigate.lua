local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local rel = require("nav_module.rel_move")

function module.navigate_chunk(arguments)
    local what_kind = arguments[1]
    if what_kind == nil then
        print(comms.robot_send("error", "navigate chunk, non-recognized \"what kind\""))
        return nil
    end
    local finished = nav.navigate_chunk(what_kind)
    if not finished then
        return {50, "navigate_chunk", what_kind}
    end
    return nil
end

function module.generate_chunks(arguments)
    local x = arguments[1]; local z = arguments[2]
    if x == nil or z == nil then
        print(comms.robot_send("debug", "generate chunks, no x, or z provided for offset, assuming {1,1}"))
        x = 1; z = 1
    end

    local offset = {x,z}
    map.gen_map_obj(offset)
    return nil
end

-- In order to support different levels, this is to say, buildings in different heights in the same chunk/quad
-- we'll need to improve our navigation algorithms and the data we pass into them
-- but for now this is enough, we'll not need different levels until at-most HV, and at-least IV
local function nav_and_build(rel_coords, what_chunk, door_info, block_name, post_run)
    -- I know this shit should be done in place, I don't have the time to code good for now
    local self_return = {80, eval_nav.navigate_rel, "and_build", rel_coords, what_chunk, door_info, block_name, post_run}

    -- post_run is a command to be run after this one is finished
    local cur_chunk = nav.get_chunk()
    if cur_chunk[1] ~= what_chunk[1] or cur_chunk[2] ~= what_chunk[2] then
        -- this is getting ridiculous, we won't do a inner command again this time
        if not nav.is_setup_navigate_chunk() then
            nav.setup_navigate_chunk(what_chunk)
        end
        nav.navigate_chunk("surface") -- for now surface move only

        return self_return
    end
    -- Sanity Check:
    if nav.is_setup_navigate_chunk() then
        error(comms.robot_send("fatal", "eval, nav_and_build, did navigation not terminate gracefully?")) 
    end

    if not rel.is_setup() then
        nav.setup_navigate_rel(rel_coords)
        --return {80, module.navigate_rel, "and_build", coords, block_name, post_run}
    end
    local result, err = nav.navigate_rel()
    if result == -1 then -- movement completed (place block, and go back to build_function)
        nav.debug_move("up", 1, false)
        if not inv.place("down", block_name, "lable") then
            -- Real error handling will come som eother time
            error(comms.robot_send("fatal", "how is this possible? :sob:"))
        end

        return post_run
    elseif result == 1 then
        if err == "swong" then print("noop") -- not a big error we keep going
        else error(comms.robot_send("fatal", "eval, navigate, I never thought of this x0")) end
    elseif result ~= 0 then -- elseif 0 then no problem
        error(comms.robot_send("fatal", "impossible error code returned eval navigate"))
    end

    return self_return
end

function module.navigate_rel(arguments)
    -- {"and_build", rel_coords, what_chunk, door_info, block_name, self_table}
    local flag = arguments[1];          local rel_coords = arguments[2]
    local what_chunk = arguments[3];    local door_info = arguments[4]
    -- Block Name                         Post Run
    local fifth = arguments[5];         local sixth = arguments[6]
    
    if flag == nil then
        print(comms.robot_send("error", "eval_navigate: flag is nil"))
    elseif flag == "and_build" then
        return nav_and_build(rel_coords, what_chunk, door_info, fifth, sixth)
    elseif flag == "no_build" then
    else
        print(comms.robot_send("error", "eval_navigate: flag is incorrect?"))
    end

    return post_run
end

return module
