-- luacheck: globals OLD_PRINT DO_DEBUG_PRINT EMPTY_TABLE DO_LOAD
EMPTY_TABLE = {}

DO_DEBUG_PRINT = false
DO_LOAD = true

OLD_PRINT = print
function print (...) -- luacheck: ignore
    local args = {...}
    if (args[1] == "debug" or args[1] == "eval") and DO_DEBUG_PRINT ~= nil and not DO_DEBUG_PRINT then
        return
    end
    OLD_PRINT(table.unpack(args));
end
