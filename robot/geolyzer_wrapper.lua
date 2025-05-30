local module = {}

local geo = require("component").getPrimary("geolyzer")
local comms = require("comms")
local serialize = require("serialization")
local sides_api = require("sides")


function module.can_see_sky()
    return geo.canSeeSky()
end

-- geo translation table
local geo_table = {
    ["gravel"] = "minecraft:gravel",
    ["dirt"] = "minecraft:dirt",
    ["grass"] = "minecraft:grass",
    ["water"] = "minecraft:water",
}

-- it seems to me that sides_api here recognizes front as relative front, and not as south
function module.compare(match_string, method, side) -- returns bool
    if side == nil or side == -1 then side = sides_api.front end
    if match_string == nil then return false end
    if method == nil then return false end

    local analysis = geo.analyze(side)
    module.sub_compare(match_string, method, analysis)
end

function module.sub_compare(match_string, method, analysis)
    local string_id = analysis["name"]

    if method == "simple" then
        local table_id = geo_table[match_string]
        if table_id == nil then return false end -- which means not found

        return string_id == table_id
    elseif method == "naive_contains" then
        return string.find(string_id, match_string) ~= nil
    elseif method == "direct" then
        return string_id == match_string
    else
        print(comms.robot_send("error", "Geo Compare, unrecognized method"))
        return false
    end
end

function module.debug_print(side)
    local analysis = geo.analyze(side)
    print(comms.robot_send("info", "debug_analysing on side: \"" .. sides_api[side] .. "\""))
    print(comms.robot_send("info", serialize.serialize(analysis, true)))
end

function module.simple_return(side)
    if side == nil then side = sides_api.front end
    local analysis = geo.analyze(side)
    return analysis
end

return module
