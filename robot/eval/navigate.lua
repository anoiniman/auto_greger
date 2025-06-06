local module = {}

-- import of globals
local serialize = require("serialization") -- luacheck: ignore

-- local imports
local comms = require("comms")

local nav = require("nav_module.nav_obj")
local map = require("nav_module.map_obj")
local nb = require("complex_algorithms.nav_build")
local rb = require("complex_algorithms.road_build")


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
        return nb.nav_and_build(instructions, return_table)
    elseif flag == "road_build" then
        return rb.step(instructions, return_table)
    elseif flag == "and_gather" then
        -- Here instructions are no longer a build instruction, but rather the gathering algorithm to employ
        -- Here return_table takes the shape of simply being the arguments fed into the thingy-mabob
        return instructions(return_table)
    elseif flag == "and_clear" then
        print(comms.robot_send("error", "\"and_clear\" is not implemented"))
    else
        print(comms.robot_send("error", "eval_navigate: flag is incorrect?"))
    end

    --return post_run
    return nil
end

return module
