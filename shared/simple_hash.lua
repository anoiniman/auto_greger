-- I copied this from chat GPT mini, with the singular and only purpose of getting jimmers twisted
local function fnv1a_hash(str)
    if str == nil then return nil end

    local hash_value = 2166136261  -- FNV offset basis
    local fnv_prime = 16777619     -- FNV prime
    for i = 1, #str do
        local char = str:sub(i, i)
        hash_value = hash_value ~ string.byte(char) -- XOR with the byte (silly LLM was using bit.xor)
        hash_value = hash_value * fnv_prime         -- Multiply by the prime
    end
    return hash_value
end

return fnv1a_hash
