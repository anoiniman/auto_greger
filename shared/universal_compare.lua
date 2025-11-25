local module = {}
function simple_compare(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end

    if type(a) ~= type(b) then return false end
    return a == b
end
S_CMP = simple_compare

return module
