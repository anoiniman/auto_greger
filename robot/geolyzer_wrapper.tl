local record module end

local component = require("component")
local geo = component.getPrimary("geolyzer") as Geolyzer
local comms = require("comms")
local serialize = require("serialization")
local sides_api = require("sides")

global enum MethodEnum
    "simple"
    "naive_contains"
    "direct"
end

function module.can_see_sky(): boolean
    return geo.canSeeSky()
end

-- geo translation table
local geo_table: {string : string} = {
    ["gravel"] = "minecraft:gravel",
    ["dirt"] = "minecraft:dirt",
    ["grass"] = "minecraft:grass",
    ["water"] = "minecraft:water",
}

function module.sub_compare(match_string: string, method: MethodEnum, analysis: AnalyzeResult): boolean
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

-- it seems to me that sides_api here recognizes front as relative front, and not as south
function module.compare(match_string: string, method: MethodEnum, side: integer | string | nil): boolean
    if side == nil or side == -1 then side = sides_api.front end
    if match_string == nil then return false end
    if method == nil then return false end

    local analysis = geo.analyze(sides_api[side as integer])
    module.sub_compare(match_string, method, analysis)
end

function module.debug_print(side?: integer | string)
    if side == nil or side == -1 then side = sides_api.front end
    local analysis = geo.analyze(sides_api[side as integer])
    print(comms.robot_send("info", "debug_analysing on side: \"" .. sides_api[side] .. "\""))
    print(comms.robot_send("info", serialize.serialize(analysis, true)))
end

function module.simple_return(side?: integer | string): AnalyzeResult
    if side == nil or side == -1 then side = sides_api.front end
    local analysis = geo.analyze(sides_api[side as integer])
    return analysis
end

return module
