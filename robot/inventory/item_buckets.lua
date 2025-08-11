local module = {}
local search_table = require("search_table")
local comms = require("comms")

-- make sure that you write conversions that are self-stable [aka the identify of "any:log" is "any:log"
-- returns a name
function module.identify(name, lable)
    if name == nil then name = "nil" end
    if lable == nil then lable = "nil" end

    local function fname(hole) return string.find(name , hole) end
    local function flabl(hole) return string.find(lable, hole) end

    if lable == "Dirt" or lable == "Grass" or name == "any:grass" then
        return "any:grass"
    end

    if flabl ("Planks")             then return     "any:plank"         end
    if fname ("any:plank")          then return     "any:plank"         end

    if flabl ("Ingot$")             then return     "any:ingot"         end
    if flabl ("Sword")              then return     "any:equipment"     end

    -- prob will catch the blocks as well
    if flabl ("Coal")               then return     "any:fuel"          end
    if flabl ("Coke")               then return     "any:fuel"          end
    if flabl ("Charcoal")           then return     "any:fuel"          end
    if fname ("^any:fuel$")         then return     "any:fuel"          end


    if fname ("log")                then return     "any:log"           end
    if fname ("sapling")            then return     "any:sapling"       end
    if fname ("^any:building$")     then return     "any:building"      end


    if fname("^minecraft:") then
        if flabl("^Dirt$") or flabl("^Cobblestone$") then return "any:building" end
        return "minecraft:generic"
    end

    if fname("^gregtech:") then
        if flabl("^Raw") and flabl("Ore$") then return "gregtech:raw_ore" end -- excludes dusts and shit
        return "gregtech:generic"
    end

    return "generic"
end

--[[local function concat(tbl1, tbl2)
    for index, element in ipairs(tbl2) do
        local offset = #tbl1 + index
        tbl1[offset] = element
    end

    return tbl1
end--]]

local function capitalise(str)
    return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

-- tool materials and tool types
local req_tbl = require("inventory.tool_definition")
local tm_table, tt_table = table.unpack(req_tbl)
local max_tool_level = 3
-- returns {lable} table, organized from most preferential to least preferential
function module.id_equipment(tool_type, tool_level)
    if tool_level == 0 then
        return nil
    elseif tool_level < 0 then
        print(comms.robot_send("error", "Unexpected tool_level: " .. tool_level))
        return nil
    end

    if not search_table.ione(tt_table, tool_type) then
        print(comms.robot_send("error", "Unidentified tool_type: " .. tool_type))
        return nil
    end

    local possible_lables = {}
    for level, inner_tbl in ipairs(tm_table) do
        if level < tool_level then goto continue end
        for _, material in ipairs(inner_tbl) do
            local material = capitalise(material) -- luacheck: ignore material
            local tool_name = capitalise(tool_type)
            local hopefully_good_name = table.concat({material, " ", tool_name})
            table.insert(possible_lables, hopefully_good_name)
        end
        ::continue::
    end
    if #possible_lables == 0 then
        print(comms.robot_send("error", "Found Nothing in id_equipment?" .. tool_type .. tool_level))
        return nil
    end

    return possible_lables
end

-- There is a teeny-tiny possibility that we'll find iron that is from a magnetite vein rather than a copper
-- one, but magnetite veins are so rare that it is a sacrifice I'm willing to make, overall, managing ore
-- gathering routines this way is somewhat stupid, but hey, if it'll work it'll work
function module.normalise_ore(lable)
    lable = tostring(lable)
    if lable == nil then lable = "Nil Lable" end
    local function flabl(hole) return string.find(lable, hole) end

    if flabl("Copper") or flabl("Chalcopyrite") or flabl("Raw Iron") or flabl("Pyrite") then
        return "Raw Copper Ore", 1
    end
    if flabl("Gold") or flabl("Magnetite") or flabl("Raw Iron") then
        return "Raw Gold Ore", 2
    end
    if flabl("Cassiterite Sand") or flabl("Garnerite Sand") or flabl("Dolomite") or flabl("Asbestos") then
        return "Raw Tin Sand Ore", 1
    end

    if flabl("Cassiterite Ore") or flabl("Tin Ore") then
        return "Raw Tin Ore", 3
    end

    if flabl("Mica") or flabl("Kyanite") or flabl("Pollucite") then
        return "Raw Mica Ore", 3
    end

    -- Some of these checks are more reliable than the others theheehe
    if flabl("Graphite") then
        return "Raw Graphite Ore", 3
    end

    if flabl("Coal") then
        return "Raw Coal Ore", 1
    end

    if flabl("Lignite") then
        return "Raw Lignite Ore", 1
    end

    if flabl("Redstone") or flabl("Ruby") or flabl("Cinnabar") then
        return "Raw Redstone Ore", 2
    end

    if flabl("Lazurite") or flabl("Lapis") or flabl("Sodalite") or flabl("Calcite") then
        return "Raw Lapis Ore", 2
    end

    if flabl("Soapstone") or flabl("Talc") or flabl("Galuconite") or flabl("Pentlandite") then
        return "Raw Soapstone Ore", 2
    end

    if flabl("Basaltic Mineral") or flabl("Granitic Mineral") or flabl("Gypsum") or flabl("Fullers Earth") then
        return "Raw Basaltic Sand Ore", 2
    end

    if flabl("Salt") or flabl("Lepidolite") or flabl("Spodumene") then
        return "Raw Salt Ore", 2
    end

    if flabl("Oil Sand") then
        return "Raw Oil Sand Ore", 2
    end

    print(comms.robot_send("error", string.format("Woops, I don't know this ore: \"%s\"", lable)))
    return "Unrecognised Ore"
end

return module
