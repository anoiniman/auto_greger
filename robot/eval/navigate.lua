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
        x = 0; z = 0
    end

    local offset = {x,z}
    map.gen_map_obj(offset)
    return nil
end

-- In order to support different levels, this is to say, buildings in different heights in the same chunk/quad
-- we'll need to improve our navigation algorithms and the data we pass into them
-- but for now this is enough, we'll not need different levels until at-most HV, and at-least IV
local function nav_and_build(rel_coords, what_chunk, door_info, block_name, post_run)
    -- post_run is a command to be run after this one is finished
    -- TODO
    local cur_chunk = nav.get_chunk()
    if cur_chunk[1] ~= what_chunk[1] or cur_chunk[2] ~= what_chunk[2] then
        
        -- this is getting ridiculous, but hey
        local inner = {80, eval_nav.navigate_rel, "and_build", rel_coords, what_chunk, door_info, block_name, post_run}
    end

    error("We need to go to the right chunk first")
    local is_setup = rel.is_setup()
    if not is_setup then
        --rel.setup_navigate_rel(coords[1], coords[2], coords[3])
        --return {80, module.navigate_rel, "and_build", coords, block_name, post_run}
    end
    --rel.navigate_rel()

    -- I know this shit should be done in place, I don't have the time to code good for now
    return {80, eval_nav.navigate_rel, "and_build", rel_coords, what_chunk, door_info, block_name, post_run}
end

function module.navigate_rel(arguments)
    -- {"and_build", rel_coords, what_chunk, door_info, block_name, self_table}
    local flag = arguments[1];          local rel_coords = arguments[2]
    local what_chunk = arguments[3];    local door_info = arguments[4]
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
