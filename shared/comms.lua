local module = {}
-- Robot message handling is poll based rather than call-back based
-- because this is not a server :P
local serialize = require("serialization")
local component = require("component")
local event = require("event")

local tunnel = component.tunnel
local tunnel_address = tunnel.getChannel()

function module.recieve()
    local message_table = nil
    local address = nil

    -- for robot
    -- message_table should be a (num, string, any) tuple, 
    -- where num is priority, where string is a recognizeable keyword,
    -- where any is an argument pairable with keyword string

    -- for controller
    -- message_table should be a string

    _, address, _, _, _, message_table = event.pull(0, "modem_message")
    if message_table ~= nil then
        message_table = serialize.unserialize(message_table)
    else
        return false, nil, nil
    end

    if address == nil then
        return false, nil, nil
    elseif address == tunnel_address then
        return true, "self", message_table
    else
        return true, address, message_table
    end
end

-- Same format
function module.controller_send(any)
    local message_table = serialize.serialize(any, false)
    tunnel.send(message_table)
    return message_table
end

function module.robot_send(part1, part2) -- part1 & 2 must be strings
    local final_string = "<| " .. part1 .. " |> " .. part2 
    tunnel.send(final_string)
    return final_string
end

return module
