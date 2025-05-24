local module = {}

-- takes some data as input, and returns other data as output :D
-- Names == Tinkers, durability == GT
local material_dictionary = {
    Bronze = 3, -- Level == Max_level, rather than min. exp level
    Iron = 3,

    Copper = 2,

    Flint = 1,
}


function module.material_identify(lable) -- Lable won't work for GT pickaxe
    for material, level in pairs(material_dictionary) do
        if string.find(lable, material) then
            return material, level
        end
    end
    return nil
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
