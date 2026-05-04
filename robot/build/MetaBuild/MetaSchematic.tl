--local math = require("math")

--local comms = require("comms")
require("inventory.__h_Item")
local record module end

global enum SpecialSymbol
    "0"
    "*"
    "+"
    "?"
end

-- Chunks are 16 by 16, roads included they become 14 by 14, this is then sub devided into 4 - 7 by 7 sub-chunks
-- Builds (tm) will occupy marked sub-chunks inside a chunk instead of arbitrary rectangles, for ease of navigation
-- and they'll always be accessed through the "outside", this is to say, through the "road-blocks/lines"
-- if we want to get fancy, we can mark-down door locations and shit, so that we can have walls and enclosed buildigs etc

-- Meta schematic chunk
global interface MSChunk
    x: integer
    symbol: string
end

global enum TSymbolExtra

end

global interface TransSymbol
    item: ItemDefinition
    extra: {TSymbolExtra}
end

global type SpecialSchematicChunk = {SpecialSymbol, integer, integer, integer}

local function ms_chunk_new(x: integer, symbol: string): MSChunk
    return {x = x, symbol = symbol}
end

-- lines into squares into square_cuboids (the meta_schematic itself)
global type MetaSchematic = {{{MSChunk}}}
function module.new(): MetaSchematic
    return { { {} } }
end

-- this is very important, because it means that the tables have no "gaps" where they might contain
-- a "nil" object, the array is sparse logically but "nil" objects are in reality just empty arrays
-- which != nil
local function return_or_init_table_table<T>(tbl: {{T}}, index: integer): {T}
    if tbl[index] ~= nil then
        return tbl[index]
    end

    tbl[index] = {}
    return tbl[index] -- returns ref to inner table
end

local function record_special(symbol: string, x: integer, z: integer, y: integer, tbl: {SpecialSchematicChunk})
    if symbol is SpecialSymbol then
        local full_obj = {symbol, x, z, y}
        table.insert(tbl, full_obj)
    end
end


-- I hope no return needed, we're modifying self (a ref) anyhow
-- 2d slice of height 1, where 1 string is 1 line (x,z)
function module.parse_string_arr(ms: MetaSchematic, string_array: {string}, y_coord: integer): {SpecialSchematicChunk}
    local square: {{MSChunk}} = return_or_init_table_table(ms, y_coord)
    local special_table: {SpecialSchematicChunk} = {}

    local z_coord = 0
    for _, str in ipairs(string_array) do
        local x_coord = 0

        for char in string.gmatch(str, ".") do
            --max_line = math.max(max_line, z_coord)
            local line = return_or_init_table_table(square, z_coord + 1)

            if char ~= '-' then
                local new_obj = ms_chunk_new(x_coord, char)
                record_special(char, x_coord, z_coord, y_coord, special_table)
                table.insert(line, new_obj)
                --print(comms.robot_send("debug", char .. "-" .. dist))
            end -- if
            --table.insert(print_table, char)

            x_coord = x_coord + 1
        end -- for char

        z_coord = z_coord + 1
    end -- for str
    return special_table
end

return module
