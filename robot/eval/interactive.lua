-- luacheck: globals INTERACTED
local module = {}
local interactive = require("interactive")
local comms = require("comms")

function module.print_list()
    return interactive.print_list()
end

function module.force_set_data_table(arguments)
    if arguments == nil or #arguments < 2 then return nil end

    local id = tonumber(table.remove(arguments, 1))
    if id == nil then return nil end
    local bool = interactive.set_data_table(arguments, id)
    if bool then
        INTERACTED = true
        print(comms.robot_send("debug", "succeseful force setting interaction data table for id: " .. id))
    else
        print(comms.robot_send("warning", "Failed force setting interaction data table for id: " .. id))
    end
    return nil
end

return module
