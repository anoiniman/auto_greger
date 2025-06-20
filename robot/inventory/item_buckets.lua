local module = {}
local comms = require("comms")

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
    "minecraft:",
    "gregtech:raw_ore",
    "ingot",
    "generic",
    "any:log",
    "any:sapling"
    -- sword?
}


-- make sure that you write conversions that are self-stable [aka the identify of "any:log" is "any:log"
function module.identify(name, lable)
    if name == nil then name = "nil" end

    if string.find(name, "log") then    -- this could have awful results if something that isn't a log is caught,
                                        -- check NEI and improve the regex if needed
        return "any:log"

    elseif string.find(name, "sapling") then
        return "any:sapling"
    elseif string.find(name, "^minecraft:") then
        return "minecraft:generic"
    elseif string.find(name, "^gregtech:") then
        if string.find(lable, "^Raw") and string.find(lable, "Ore$") then
            return "gregtech:raw_ore"
        end
        return "gregtech:generic"
    elseif string.find(lable, "Ingot$") then
        return "any:ingot"
    elseif string.find(lable, "Sword") or string.find(lable, "sword") then
        return "any:sword", true
    end

    return "generic", nil
end

return {module, buckets}
