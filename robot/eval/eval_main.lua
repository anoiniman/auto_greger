local module = {}

-- import of globals
local serialize = require("serialization")

-- local imports
local comms = require("comms")

local debug = require("eval.debug")
local navigate = require("eval.navigate")
local build = require("eval.build")
local interactive = require("eval.interactive")


-- I have created a sort of "abomination" command that in the command field it is a
-- function pointer, and the arguments are unpacked inside the function, this allows for
-- less "cluttering" in the if-else tree, and allows us to skip some verification steps
-- because we can be sure that the pointer and its arguments are generated
-- programatically, this is, maybe, a bit "ugly" (design-wise), but it is a cute solution
-- (programming-wise) and makes things easier and less boiler-platy for me
function module.eval_command(command_arguments)
    local _ = table.remove(command_arguments, 1) -- prio
    local command = table.remove(command_arguments, 1)
    local arguments = command_arguments

    if type(command) == "function" then
        print(comms.robot_send("eval", "Attempting to Eval Internal Command...."))
        return command(arguments)
    end

    --- IF not a function pointer

    local serial_arguments = serialize.serialize(arguments, true)
    print(comms.robot_send("eval", "Attempting to Eval -- \"" .. command .. "\":\n" .. serial_arguments))
    if command == "echo" then
        return debug.echo(arguments)
    elseif command == "debug" then
        return debug.debug(arguments)
    elseif command == "stop_reason" then
        DO_REASONING = false
    elseif command == "reason_once" then
        REASON_ONCE = true
    ---------------
    elseif command == "navigate_chunk" then
        return navigate.navigate_chunk(arguments)
    elseif command == "navigate_rel" then
        return navigate.navigate_rel(arguments)

    ---------------
    elseif command == "generate_chunks" then
        return navigate.generate_chunks(arguments)
    elseif command == "create_named_area" then
        return build.create_named_area(arguments)
    elseif command == "chunk_set_parent" then
        return build.chunk_set_parent(arguments)

    ---------------
    elseif command == "build_add_quad" then
        return build.add_quad(arguments)
    elseif command == "build_setup" then
        return build.setup_build(arguments)
    elseif command == "build_do_build" then
        return build.do_build(arguments)
    elseif command == "start_auto_build" then
        return build.start_auto_build(arguments)

    ---------------
    elseif command == "interactive_list" or command == "ils" then
        return interactive.print_list()
    elseif command == "interactive_force_set" or command == "ifs" then
        return interactive.force_set_data_table(arguments)
    end
    return nil
end

return module
