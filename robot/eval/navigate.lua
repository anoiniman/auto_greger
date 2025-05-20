local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local inv = require("inventory.inv_obj")

local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local rel = require("nav_module.rel_move")
local nb = require("eval.nav_build")


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

function module.navigate_rel(arguments)
    -- {"and_build", rel_coords, what_chunk, door_info, block_name, self_table}
    local flag = arguments[1]
    local instructions = arguments[2]
    local return_table = arguments[3]

    if flag == nil then
        print(comms.robot_send("error", "eval_navigate: flag is nil"))
    elseif flag == "and_build" then
        return nb.nav_and_build(rel_coords, what_chunk, door_info, fifth, sixth)
    elseif flag == "and_clear" then

    elseif flag == "smart_clear" then
    elseif flag == "no_build" then
    else
        print(comms.robot_send("error", "eval_navigate: flag is incorrect?"))
    end

    --return post_run
    return nil
end

return module
