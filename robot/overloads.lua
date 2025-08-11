-- luacheck: globals EMPTY_TABLE
EMPTY_TABLE = {}

-- TODO adding a save file to save this sort of global variables or a way to autocheck them idk

-- luacheck: globals HOME_CHUNK DO_AUTO_FILL
HOME_CHUNK = {0, 0}     -- coords
DO_AUTO_FILL = false

-- luacheck: globals FUEL_TARGET DO_FUEL_GRIND FUEL_TYPE
FUEL_TARGET = 192 -- sU, corresponds to 2 stacks of planks
DO_FUEL_GRIND = false
FUEL_TYPE = "wood"

-- luacheck: globals AUTOMATIC_EXPAND_ORE AUTOMATIC_EXPAND_G_GATHER
AUTOMATIC_EXPAND_ORE = 4        -- how many chunk radius from home can we search in.
AUTOMATIC_EXPAND_G_GATHER = 0   -- unlike ore these kinds of deposits aren't "regular" so we better.... do it manual like

-- luacheck: globals DO_DEBUG_PRINT DO_LOAD OLD_PRINT
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
