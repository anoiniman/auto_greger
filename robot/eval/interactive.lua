local module = {}
local interactive = require("interactive")

function module.print_list()
    return interactive.print_list()
end

function module.force_set_data_table(arguments)
    if arguments == nil or #arguments < 2 then return nil end

    local id = table.remove(arguments, 1)
    return interactive.set_data_table(arguments, id)
end

return module
