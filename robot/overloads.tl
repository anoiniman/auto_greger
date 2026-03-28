global EMPTY_TABLE: {any} = {}

global FORCE_INTERRUPT_ORE: boolean = false

-- TODO adding a save file to save this sort of global variables or a way to autocheck them idk
global HAS_WOOD_FARM: integer = 0
global HAS_MORTAR: boolean = false


-- TODO define this someplace better:
local type ChunkCoordinate = {integer, integer}
local enum RobotLoadout
    "NONE"
    "ONE"
    "TWO"
end
local enum EFuelType
    "WOOD"
    "LOOSE_COAL"
end

global HOME_CHUNK: ChunkCoordinate = {0, 0}
global DO_AUTO_FILL: boolean = false
global WHAT_LOADOUT: RobotLoadout = "NONE"

global FUEL_TYPE: EFuelType = "LOOSE_COAL"
global IGNORE_ORE_FUEL_CHECK: boolean  = false

global AUTOMATIC_EXPAND_ORE: integer = 4        -- how many chunk radius from home can we search in.
-- unlike ore these kinds of deposits aren't "regular" so we better.... do it manual like
global AUTOMATIC_EXPAND_G_GATHER: integer = 0

global DO_DEBUG_PRINT: boolean = false
global DO_LOAD: boolean = true

global OLD_PRINT: function(any...) = print
local print = print
print = function (...: any)
    local args = {...}
    if (args[1] == "debug" or args[1] == "eval") and DO_DEBUG_PRINT ~= nil and not DO_DEBUG_PRINT then
        return
    end

    OLD_PRINT(...)
end
_G.print = print

global function REQUIRE_UNPACK(nor_tbl: string | {any}): any...
    if nor_tbl is string then 
        local a = require(nor_tbl) as {any}
        return table.unpack(a)
    elseif nor_tbl is {any} then
        return table.unpack(nor_tbl)
    end
end
