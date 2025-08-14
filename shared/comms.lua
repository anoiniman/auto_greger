-- luacheck: globals DO_DEBUG_PRINT

local module = {}
-- Robot message handling is poll based rather than call-back based
-- because this is not a server :P
-- Correction -- Is this an hybrid approach now?

local term = require("term")
local serialize = require("serialization")
local component = require("component")
local event = require("event")

local filesystem = require("filesystem")


local tunnel = component.tunnel
--local tunnel_addr = tunnel.getChannel()
local tunnel_card_addr = tunnel.address

-- Global message tbl
local glb_msg_tbl = {}
local listener = nil

-- luacheck: no unused args
local function listener_function(name, local_addr, foreign_addr, port, dist, ...)
    -- It is expected only one serialized table string to be sent over
    --local arg = {...}
    --local vari = arg
    local vari = {...}
    local msg_string = vari[1]
    --print("Msg_string: " .. msg_string)
    local msg_table = serialize.unserialize(msg_string)
    --print("Msg_table: " .. msg_table)

    local new_table = nil -- luacheck: ignore
    if local_addr == tunnel_card_addr then
        new_table = {true, "self", msg_table}
    else
        new_table = {true, local_addr, msg_table}
    end

    table.insert(glb_msg_tbl, new_table)
end

function module.recieve()
    -- return format = {bool, string, table}
    if listener == nil or listener == false then
        print("Comms Listener not registered!")
        return {false, nil, nil}
    end

    if glb_msg_tbl == nil or #glb_msg_tbl == 0 then
        --print("glb is NIL!")
        return {false, nil, nil}
    end

    local to_return = table.remove(glb_msg_tbl, 1)
    --print("Serial: " .. serial)

    return to_return
end


function module.setup_listener()
    if listener == nil then
        print("Setting up listener")
        listener = event.listen("modem_message", listener_function)
        local serial_listener = serialize.serialize(listener, true)
        print(serial_listener)
    end
end

-- Same format
function module.controller_send(any)
    local message_table = serialize.serialize(any, false)
    tunnel.send(message_table)
    return message_table
end

local post_exit = nil
function module.inject_post_exit(obj)
    post_exit = obj
end

-- luacheck: globals ALREADY_SAVED
ALREADY_SAVED = false
function module.robot_send(part1, part2) -- part1 & 2 must be strings
    if part1 == "fatal" and filesystem.exists("/home/robot") then -- le emergency save
        ALREADY_SAVED = true
        post_exit.exit()
        return part2
    end

    if (part1 == "debug" or part1 == "eval") and DO_DEBUG_PRINT ~= nil and not DO_DEBUG_PRINT then
        return part1, part2
    end

    --local final_string = "<| " .. part1 .. " |> " .. part2
    local final_table = {part1, part2}
    --local final_string = table.concat(final_table)
    local hello = serialize.serialize(final_table)

    tunnel.send(hello)

    table.insert(final_table, 2, " |>")
    table.insert(final_table, 1, "<| ")
    local final_string = table.concat(final_table)
    return final_string
end

function module.send_unexpected(fatal)
    if fatal == nil then fatal = false end

    local str = "warning"
    if fatal then str = "fatal" end

    return module.robot_send(
        str,
        "Hey brosky, this is code-path should not be being threaded, watch yo back!\n"
        .. debug.traceback()
    )
end

function module.cls_nself()
    term.clear()
    tunnel.send(serialize.serialize({"command", "term", "clear"}))
end

function module.send_command(...)
    local args = {...}
    table.insert(args, 1, "command")
    local serial = serialize.serialize(args)
    tunnel.send(serial)
end

-- prints a buffer expanded to a full screen (because computer monitor and robot monitor have different resolutions)
function module.screen_print()

end

return module
