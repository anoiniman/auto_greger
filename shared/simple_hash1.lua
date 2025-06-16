-- etc
function djb2_hash(str)
    if str == nil then return nil end

    local hash_value = 5381
    for i = 1, #str, 1 do
        local char = str:sub(i, i)
        hash_value = ((hash_value * 33) + string.byte(char))
    end
    return hash_value
end

return sdbm_hash
