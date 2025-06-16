local module = {}

function module.one(tbl, particle)
    for _, element in ipairs(tbl) do
        if particle == element then return true end
    end
    return false
end


return module
