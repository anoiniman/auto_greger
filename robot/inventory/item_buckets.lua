local module = {}
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
    if flabl ("Ingot$")             then return     "any:ingot"         end
    if flabl ("Sword")              then return     "any:equipment"     end

    if fname ("log")                then return     "any:log"           end
    if fname ("sapling")            then return     "any:sapling"       end
    if fname ("^any:building$")     then return     "any:building"      end


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


local function concat(tlb1, tbl2)
    for index, element in ipairs(tbl2) do
        local offset = #tbl1 + index 
        tbl1[offset] = element
    end
    
    return tbl1
end

local function capitalise(str)
    return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

-- tool materials and tool types
local req_tbl = require("inventory.tool_definition")
local tm_table, tt_table = table.unpack(req_tbl)
local max_tool_level = 3
-- returns {lable} table, organized from most preferential to least preferential
function module.id_equipment(tool_type, tool_level)
    if tool_level <= 0 then
        print(comms.robot_send("error", "Unexpected tool_level: " .. tool_level))
        return nil
    end

    if not search_table.ione(tool_types, tool_type) then
        print(comms.robot_send("error", "Unidentified tool_type: " .. tool_type))
        return nil
    end

    local possible_lables = {}
    for level, inner_tbl in ipairs(tm_table) do
        if level < tool_level then goto continue end
        for _, material in ipairs(inner_tbl) do
            local material = capitalise(material)
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

return module
