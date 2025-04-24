local module = {}

-- import of globals
local term = require("term")
local text = require("text")
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local geolyzer = require("geolyzer_wrapper")

local debug = require("eval.debug")
local navigate_chunk = require("eval.navigate_chunk")

function module.eval_command(command_arguments)
    local prio = table.remove(command_arguments, 1)
    local command = table.remove(command_arguments, 1)
    local arguments = command_arguments

    local serial_arguments = serialize.serialize(arguments, true)
    print(comms.robot_send("debug", "Debug -- Attempting to Eval: \"" .. command .. ", " .. serial_arguments))
    if command == "echo" then
        return debug.echo(arguments)
    elseif command == "debug" then
        return debug.debug(arguments)
    elseif command == "navigate_chunk" then
        return navigate_chunk.navigate(arguments)
    end
    return nil
end

return module
