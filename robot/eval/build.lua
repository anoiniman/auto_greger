local module = {}

local comms = require("comms")

local map_obj = require("nav_module.map_obj")

function module.setup_build(arguments)
    local x = tonumber(arguments[1])
    local z = tonumber(arguments[2])
    if tonumber(x) == nil or tonumber(z) == nil then
        print(comms.robot_send("error", "setup_build, malformed command, x or z not number or nil"))
        return nil
    end
    
    local what_chunk = {x, z}
    local what_quad = arguments[3]
    if tonumber(what_quad) == nil then
        print(comms.robot_send("error", "setup_build, malformed command, what_quad not number or nil"))
        return nil
    end

    if map_obj.setup_build(what_chunk, what_quad) then -- if we succeded
        -- TODO construct new auto_comand? IDK what happens after we succeed in setting up lol, prob we should auto start building
        error("TODO 1010")
        -- return something in the end
    else 
        print(comms.robot_send("error", "setup_build -- failed somewhere"))
        return nil
    end
end

function module.do_build(arguments)

end

return module
