local geo = require("geolyzer")
local comms = require("comms")
local serialize = require("serialization")
local sides_api = require("sides")

-- geo translation table
local geo_table = {
    "gravel" = "minecraft:gravel",
    "dirt" = "minecraft:dirt",
    "grass" = "minecraft:grass",
    "water" = "minecraft:water",
}

function compare(match_string, method, side) -- returns bool
    local table_id = geo_table[match_string]

    if method == "simple" then
        if table_id == nil then return false end -- which means not found
        local string_id = geo.analyze(side)[1]

        return string_id == table_id
    elseif method == "naive_contains" then
        local string_id = geo.analyze(side)[1]
        return string.find(string_id, match_string) ~= nil
    else
        print(comms.robot_send("error", "Geo Compare, unrecognized method"))
        return nil -- which means error
    end
end

function debug_print(side)
    local analysis = geo.analyze(side)
    print(comms.robot_send("info", "debug_analysing on side: \"" .. sides_api[side] .. "\""))
    print(comms.robot_send("info", serialize.serialize(analysis, true)))
end
