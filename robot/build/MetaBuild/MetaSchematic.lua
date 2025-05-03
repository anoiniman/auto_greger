local math = require("math")

local deep_copy = require("deep_copy")
local comms = require("comms")

-- Chunks are 16 by 16, roads includes they become 14 by 14, this is then sub devided into 4 - 7 by 7 sub-chunks
-- Builds (tm) will occupy marked sub-chunks inside a chunk instead of arbitrary rectangles, for ease of navi    gation
-- and they'll always be accessed through the "outside", this is to say, through the "road-blocks/lines"
-- if we want to get fancy, we can mark-down door locations and shit, so that we can have walls and enclosed     buildigs etc

-- Meta schematic chunk
local MSChunk = {dist = 0, symbol = "0"}
function MSChunk:zeroed()
    return deep_copy.copy(self, pairs)
end
function MSChunk:new(dist, symbol)
    local obj = self:zeroed()
    obj.dist = dist
    obj.symbol = symbol
    return obj
end

local SpecialBlockEnum = {
   Inventory = {} 
}

-- lines into squares into square_cuboids (the meta_schematic itself)
-- acts as a sort of multi-dimensional queue
local MetaSchematic = {} -- Cuboid (top-level)
MetaSchematic[1] = {} -- 1st square
MetaSchematic[1][1] = {} -- 1st line
-- MetaSchematic[1][1][1] -- 1st chunk of 1st line

function MetaSchematic:new()
    return deep_copy.copy(self, pairs)
end -- I hope I don't have to do forward declarations, that would be cringe

-- this is very important, because it means that the tables have no "gaps" where they might contain
-- a "nil" object, the array is sparse logically but "nil" objects are in reality just empty arrays
-- which != nil
local function return_or_init_table_table(tbl, index) -- for maybe nils
    if tbl[index] ~= nil then
        return tbl[index]
    end

    tbl[index] = {}
    return tbl[index] -- returns ref to inner table
end

local function record_special(ms_chunk, tbl) -- because a table is ref/pointer it's fine
    local obj_detected = true
    if ms_chunk.symbol == '*' then
        table.insert(tbl, ms_chunk)
    else
        obj_detected = false
    end

    if obj_detected and tbl == nil then tbl = {} end
end

-- I hope no return needed, we're modifying self (a ref) anyhow
-- 2d slice of height 1, where 1 string is 1 line (x,z)
function MetaSchematic:parseStringArr(string_array, square_index) 
    local square = return_or_init_table_table(self, square_index)
    local special_table = nil

    --local line = nil
    local max_line = 0

    for _, str in ipairs(string_array) do
        local dist = 0
        local line_index = 1

        local print_table = {}
        for char in string.gmatch(str, ".") do
            max_line = math.max(max_line, line_index)
            local line = return_or_init_table_table(square, line_index)

            if char ~= '-' then
                local new_obj = MSChunk:new(dist, char)
                record_special(new_obj, special_table)
                table.insert(line, new_obj)
                print(comms.robot_send("debug", char .. "-" .. dist))
            end -- if
            table.insert(print_table, char)

            line_index = line_index + 1
            dist = dist + 1
        end -- for char
        print(comms.robot_send("debug", table.concat(print_table)))
        square_index = square_index + 1
    end -- for str
    return special_table
end

-->>--------------------------------------<<--

--[[function MetaSchematic:lookUp(height, z, x) -- returns MsChunk
    return MetaSchematic[height][z][x]
end--]]

return MetaSchematic, SpecialBlockEnum
