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
    "log",
    "duplicate" -- aka things such as: Coke Oven Brick (block) and Coke Oven Brick (item)
    -- sword?
}

local function duplicate_identify(lable)
    if lable == "Coke Oven Brick" then
        return true
    elseif lable == "CokeOvenBrick" then
        print(comms.robot_send("error", "Mangling happened!"))
        return true
    end
    return false
end

function module.identify(name, lable)
    if name == nil then name = "nil" end

    local dupe = duplicate_identify(lable)
    if dupe then
        return "duplicate"
    end

    if string.find(name, "log") then    -- this could have awful results if something that isn't a log is caught,
                                        -- check NEI and improve the regex if needed
        return "log"

    elseif string.find(name, "^minecraft:") then
        return "minecraft:"
    elseif string.find(name, "^gregtech:") then
        if string.find(lable, "^Raw") and string.find(lable, "Ore$") then
            return "gregtech:raw_ore"
        end
    elseif string.find(lable, "Ingot$") then
        return "ingot"
    elseif string.find(lable, "Sword") or string.find(lable, "sword") then
        return "sword", true
    end

    return "generic", nil
end

return {module, buckets}
