-- local comms = require("comms")
local record module end

local type iter_func_type = function(any): (function, any, any)
function module.copy(obj: {any:any}, iter_func: function(any): (function, any, any) ): {any:any} -- pair or ipair
    if obj == nil then return nil end
    if iter_func == nil then iter_func = pairs end
    if type(obj) ~= "table" then return obj end

    local new_table = {}

    local old_meta = getmetatable(obj)
    if old_meta ~= nil then
        setmetatable(new_table, old_meta)
    end

    for k, v in iter_func(obj) do
        if type(v) == "table" then
            v = module.copy(v as {any}, iter_func)
        end

        new_table[k] = v
    end

    return new_table
end
global COPY: function({any:any}, iter_func_type): {any} = module.copy
global CLONE: function({any:any}, iter_func_type): {any} = module.copy

function module.copy_no_functions(old_table: {any:any}): {any:any}
    if old_table == nil then return nil end
    local new_table = {}

    local old_meta = getmetatable(old_table)
    if old_meta ~= nil then
        setmetatable(new_table, old_meta)
    end

    for k, v in pairs(old_table) do
        if type(v) == "table" then
            v = module.copy_no_functions(v as {any:any})
        end

        if type(v) ~= "function" then
            new_table[k] = v
        end
    end

    return new_table
end

return module
