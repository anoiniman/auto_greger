-- luacheck: globals OLD_PRINT DO_DEBUG_PRINT
DO_DEBUG_PRINT = false
OLD_PRINT = print
function print (...) -- luacheck: ignore
    local args = {...}
    if (args[1] == "debug" or args[1] == "eval") and DO_DEBUG_PRINT ~= nil and not DO_DEBUG_PRINT then
        return
    end
    OLD_PRINT(table.unpack(args));
end
