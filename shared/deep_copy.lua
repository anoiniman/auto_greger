local module = {}

function module.copy_table(old_table, iter_func) -- pair or ipair
    local new_table = {}
    setmetatable(new_table, getmetatable(old_table))

    for k, v in iter_func(old_table) do
        if type(v) == "table" then 
            v = module.clone_table(v, iter_func)
        end

        new_table[k] = v    
    end

    return new_table
end

return module
