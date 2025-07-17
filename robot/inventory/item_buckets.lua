local module = {}
local comms = require("comms")

local buckets = {
    "minecraft:",
    "gregtech:raw_ore",
    "ingot",
    "generic",
    "any:log",
    "any:sapling",
    "any:grass",
    -- sword?
}

-- make sure that you write conversions that are self-stable [aka the identify of "any:log" is "any:log"
function module.identify(name, lable)
    if name == nil then name = "nil" end
    if lable == nil then lable = "nil" end

    local function fname(hole) return string.find(name , hole) end
    local function flabl(hole) return string.find(lable, hole) end

    if lable == "Dirt" or lable == "Grass" or name == "any:grass" then
        return "any:grass"
    end

    if flabl ("Planks")             then return     "any:plank"     end
    if flabl ("Ingot$")             then return     "any:ingot"     end
    if flabl ("Sword")              then return     "any:sword"     end

    if fname ("log")                then return     "any:log"       end
    if fname ("sapling")            then return     "any:sapling"   end
    if fname ("^any:building$")     then return     "any:building"  end


    if fname("^minecraft:") then
        if flabl("^Dirt$") or flabl("^Cobblestone$") then return "any:building" end
        return "minecraft:generic"
    end

    if fname("^gregtech:") then
        if flabl("^Raw") and flabl("Ore$") then return "gregtech:raw_ore" end
        return "gregtech:generic"
    end

    return "generic"
end

return {module, buckets}
