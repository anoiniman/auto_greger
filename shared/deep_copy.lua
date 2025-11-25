local comms = require("comms")

local module = {}

function module.copy_table(old_table, iter_func)
    LOG(1, "Used Old copy_table function in:\n" .. debug.traceback()) 
    return module.copy(old_table, iter_func)
end

function module.copy(obj, iter_func) -- pair or ipair
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
            v = module.copy_table(v, iter_func)
        end

        new_table[k] = v
    end

    return new_table
end
COPY = module.copy

function module.copy_no_functions(old_table)
    if old_table == nil then return nil end
    local new_table = {}

    local old_meta = getmetatable(old_table)
    if old_meta ~= nil then
        setmetatable(new_table, old_meta)
    end

    for k, v in pairs(old_table) do
        if type(v) == "table" then
            v = module.copy_no_functions(v)
        end

        if type(v) ~= "function" then
            new_table[k] = v
        end
    end

    return new_table
end

return module
