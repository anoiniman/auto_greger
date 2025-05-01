local comms = require("comms")

local module = {}

function module.copy(obj, iter_func) -- I'm dumb, I've had to create this function
    if type(obj) == "table" then
        return module.copy_table(obj, iter_func)
    else
        print(comms.robot_send("error", "What are you doing fr fr, module_copy etc"))
    end
end

function module.copy_table(old_table, iter_func) -- pair or ipair
    local new_table = {}

    local old_meta = getmetatable(old_table)
    if old_meta ~= nil then
        setmetatable(new_table, old_meta)
    end

    for k, v in iter_func(old_table) do
        if type(v) == "table" then 
            v = module.copy_table(v, iter_func)
        end

        new_table[k] = v    
    end

    return new_table
end

return module
