-- luacheck: globals DO_DEBUG_PRINT

local comms = {}
-- Robot message handling is poll based rather than call-back based
-- because this is not a server :P
-- Correction -- Is this an hybrid approach now?

local term = require("term")
local serialize = require("serialization")
local component = require("component")
local event = require("event")

local filesystem = require("filesystem")


local tunnel = component.getPrimary("tunnel")
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

function comms.recieve()
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


function comms.setup_listener()
    if listener == nil then
        print("Setting up listener")
        listener = event.listen("modem_message", listener_function)
        local serial_listener = serialize.serialize(listener, true)
        print(serial_listener)
    end
end

-- Same format
function comms.controller_send(any)
    local message_table = serialize.serialize(any, false)
    tunnel.send(message_table)
    return message_table
end

-- post_exit is a module :P
local post_exit = nil
function comms.inject_post_exit(obj)
    post_exit = obj
end

-- luacheck: globals ALREADY_SAVED
ALREADY_SAVED = false
function comms.robot_send(part1, part2) -- part1 & 2 must be strings
    if part1 == "fatal" and filesystem.exists("/home/robot") then -- le emergency save
        ALREADY_SAVED = true
        if post_exit ~= nil then post_exit.exit() end
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

function comms.send_unexpected(fatal)
    if fatal == nil then fatal = false end

    local str = "warning"
    if fatal then str = "fatal" end

    return comms.robot_send(
        str,
        "Hey brosky, this is code-path should not be being threaded, watch yo back!\n"
        .. debug.traceback()
    )
end

function comms.cls_nself()
    term.clear()
    tunnel.send(serialize.serialize({"command", "term", "clear"}))
end

function comms.send_command(...)
    local args = {...}
    table.insert(args, 1, "command")
    local serial = serialize.serialize(args)
    tunnel.send(serial)
end

-- prints a buffer expanded to a full screen (because computer monitor and robot monitor have different resolutions)
function comms.screen_print()

end

function comms.log(level, content)
    if level == nil then level = 0 end
    if type(level) == "string" then
        local s_level = string.lower(level)
        if s_level == "info" then level = 0
        elseif s_level == "warning" then level = 1
        elseif s_level == "error" then level = 2
        elseif s_level == "fatal" then level = 3
        else level = 4 end
    end

    local time_str = os.date("<%X>")
    local fmt_str = string.format("[%%s] %s %s\n", time_str, content)
    local log_msg = string.format(fmt_str, "LOG")

    local store_msg

    if level == 0 then
        print(log_msg)
        store_msg = string.format(fmt_str, "INFO")
    elseif level == 1 then
        print(comms.robot_send("warning", log_msg))
        store_msg = string.format(fmt_str, "WARNING")
    elseif level == 2 then
        print(comms.robot_send("error", log_msg))
        store_msg = string.format(fmt_str, "ERROR")
    elseif level == 3 then
        print(comms.robot_send("fatal", log_msg))
        store_msg = string.format(fmt_str, "FATAL")
    else
        print(comms.robot_send("log_error", log_msg))
        store_msg = string.format(fmt_str, "LOG ERROR")
    end

    if V_ENV ~= nil then -- We are in a virtual environment
        -- write to /tmp (sucks to be winblows)
        -- Not sure if I should have the file perma-open or not
        local log_file = io.open("/tmp/autogregger.log", "a")
        log_file:write(store_msg)
        log_file:flush()
        log_file:close()
    end
end
LOG = comms.log
NLOG = function (a, b) print(comms.robot_send(a, b)) end

return comms
