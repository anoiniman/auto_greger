local module = {}

local buckets = {
"minecraft",
"gt_raw_ore",
"ingot",
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
    end
end

return {module, buckets}
