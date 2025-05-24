local module = {}

-- takes some data as input, and returns other data as output :D
local special_dictionary = {
    --TODO
}


local function special_identify(full_lable, tool_type)
    --TODO
end


local buckets = {
    "minecraft",
    "gt_raw_ore",
    "ingot",
    "generic",
    -- sword?
}

function module.identify(name, lable)
    if string.find(name, "^minecraft:") then
        return "minecraft"
    elseif string.find(name, "^gregtech:") then
        if string.find(lable, "^Raw") and string.find(lable, "Ore$") then
            return "gt_raw_ore"
        end
    elseif string.find(lable, "Ingot$") then
        return "ingot"
    elseif string.find(lable, "Sword") or string.find(lable, "sword") then
        return "sword", true
    end

    return "generic", nil
end

return {module, buckets}
