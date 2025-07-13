local module = {}

-- it's le recursive! totally not a cludge! (this means this can't compare tables together :P)
function module.ione(tbl, particle)
    if tbl == nil or type(tbl) ~= "table" then return false end

    for _, element in ipairs(tbl) do
        if type(element) == "table" then 
            if module.ione(element, particle) then return true end
        end
        if particle == element then return true end
    end
    return false
end


return module
