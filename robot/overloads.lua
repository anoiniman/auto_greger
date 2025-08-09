-- luacheck: globals OLD_PRINT DO_DEBUG_PRINT EMPTY_TABLE DO_LOAD
EMPTY_TABLE = {}

-- TODO adding a save file to save this sort of global variables or a way to autocheck them idk
DO_AUTO_FILL = false
DO_FUEL_GRIND = false
FUEL_TYPE = "wood"

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
